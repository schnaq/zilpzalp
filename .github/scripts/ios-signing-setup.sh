#!/usr/bin/env bash
#
# Set up manual iOS code signing for a release build: create a dedicated
# keychain, import the Apple Distribution certificate, install the App Store
# provisioning profile and write the ExportOptions.plist the export step needs.
# Deterministic — nothing is created in the cloud, so an ephemeral keychain is
# enough and no certificate is ever churned.
#
# Ported from schnaq/unlock's .github/scripts/ios-signing-setup.sh. The two
# expensive lessons it encodes (the search list must keep System.keychain, and
# the identity is checked with `find-identity -v` before anything is built) are
# kept verbatim in spirit; see the comments at each of them.
#
# Reads from the environment (Infisical prod, /ios — see docs/secrets.md):
#   IOS_DIST_CERT_P12_BASE64        base64 of the distribution .p12 (cert + key)
#   IOS_DIST_CERT_PASSWORD          password for the .p12
#   IOS_PROVISIONING_PROFILE_BASE64 base64 of the App Store .mobileprovision
#   IOS_DIST_CERT_CHAIN_BASE64      optional: base64 of the Apple WWDR
#                                   intermediate (PEM/DER). Only needed when the
#                                   .p12 does not already carry the chain and
#                                   the runner has no copy either.
#
# Writes into $RUNNER_TEMP, for the export step and for the teardown script:
#   orig-default-keychain, profile_uuid, ExportOptions.plist
set -euo pipefail

: "${RUNNER_TEMP:?not set — run this through 'mise run upload', which defaults it}"
: "${IOS_DIST_CERT_P12_BASE64:?missing (Infisical prod /ios)}"
: "${IOS_DIST_CERT_PASSWORD:?missing (Infisical prod /ios)}"
: "${IOS_PROVISIONING_PROFILE_BASE64:?missing (Infisical prod /ios)}"
echo "::add-mask::$IOS_DIST_CERT_PASSWORD"

# schnaq GmbH, the same team project.yml pins for DEVELOPMENT_TEAM.
team_id="L99L6DPKC7"

# The team holds two *valid* Apple Distribution certificates, so a name match
# ("Apple Distribution") is ambiguous and could pick the one the provisioning
# profile does not list. Only this one is bound to the profile (issue #38).
# It expires 2027-08-01, as does the certificate behind the profile — when
# signing suddenly fails around then, this constant is where to look.
identity_sha1="D3353344A0D59E89752A47A9CA3983F398E1D18B"

kc="$RUNNER_TEMP/release-signing.keychain-db"
kc_pw="$(openssl rand -base64 24)"

# A dedicated, unlocked keychain as the build's default. The runner's login
# keychain is locked in a service session, and signing against a locked keychain
# fails with "User interaction is not allowed".
security create-keychain -p "$kc_pw" "$kc"
security set-keychain-settings -lut 21600 "$kc" # do not auto-lock mid-build
security unlock-keychain -p "$kc_pw" "$kc"
security default-keychain -d user | tr -d ' "' >"$RUNNER_TEMP/orig-default-keychain"

# Rebuild the search list with the release keychain first, every previous entry
# after it, and /Library/Keychains/System.keychain always present.
#
# `list-keychains -d user` reads back ONLY the user-domain entries, so rebuilding
# the list from it DROPS System.keychain — which is where a CI Mac keeps the
# Apple WWDR intermediate (the runner's login keychain never got it; a
# developer's did, via Xcode). Without it codesign cannot build
# leaf -> WWDR -> Apple Root and fails with "unable to build chain to
# self-signed root" plus errSecInternalComponent. Read the effective list (no
# -d) instead. Stale entries from previous runs are pruned, and System.keychain
# is re-appended once so it cannot end up in there twice.
prev="$(security list-keychains | tr -d '"' |
  grep -v 'release-signing\.keychain-db$' |
  grep -v '^[[:space:]]*/Library/Keychains/System\.keychain$' || true)"
# shellcheck disable=SC2086  # deliberate word splitting: one argument per keychain
security list-keychains -d user -s "$kc" $prev /Library/Keychains/System.keychain
security default-keychain -s "$kc"

# Import the Apple Distribution certificate and its private key, and authorise
# codesign/xcodebuild to use the key without a prompt.
p12="$RUNNER_TEMP/dist.p12"
printf '%s' "$IOS_DIST_CERT_P12_BASE64" | base64 --decode >"$p12"
security import "$p12" -k "$kc" -P "$IOS_DIST_CERT_PASSWORD" \
  -T /usr/bin/codesign -T /usr/bin/xcodebuild

# This keychain is first in the search list, so codesign builds the signer's
# chain from what lives HERE: leaf -> Apple WWDR intermediate -> Apple Root. A
# .p12 that carries only the leaf and the key therefore signs fine on a
# developer Mac (whose login keychain has the intermediate from Xcode) and fails
# on the runner. Put the intermediate into THIS keychain: from an explicit
# secret when one is set, otherwise harvested from the runner's own keychains
# (macOS and Xcode ship it). Both paths are local — nothing is downloaded during
# the job. The validity check below is the backstop.
chain="$RUNNER_TEMP/chain.pem"
if [ -n "${IOS_DIST_CERT_CHAIN_BASE64:-}" ]; then
  printf '%s' "$IOS_DIST_CERT_CHAIN_BASE64" | base64 --decode >"$chain"
else
  # No keychain argument: searches the whole search list (login and System),
  # which is where macOS and Xcode keep the WWDR intermediates.
  security find-certificate -a -c "Apple Worldwide Developer Relations" -p \
    >"$chain" 2>/dev/null || true
fi
chain_certs=0
if [ -s "$chain" ]; then
  chain_certs="$(grep -c 'BEGIN CERTIFICATE' "$chain" || true)"
  # Duplicates across keychains are expected; re-importing a certificate that is
  # already there is not worth failing a release over.
  security import "$chain" -k "$kc" -T /usr/bin/codesign -T /usr/bin/xcodebuild \
    >/dev/null 2>&1 || true
fi
rm -f "$chain"
# Reported so a chain failure below is immediately attributable: 0 means this
# runner has no WWDR intermediate to offer and the secret path is required.
echo "WWDR intermediate certificates imported into the release keychain: $chain_certs"

security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$kc_pw" "$kc" >/dev/null
rm -f "$p12"

# Assert the pinned identity is present AND *valid for codesigning*.
# `find-identity -v` lists only identities whose chain reaches a trusted anchor,
# so a missing intermediate fails here, in a two-second step with a fix to
# follow, instead of surfacing eight minutes later as errSecInternalComponent
# after the archive. The two branches below are two different repairs, so they
# say different things.
if ! security find-identity -p codesigning "$kc" | grep -qi "$identity_sha1"; then
  echo "::error::The certificate in Infisical prod /ios is not the one bound to the provisioning profile."
  echo "::error::Expected SHA-1 $identity_sha1 (issue #38). Update IOS_DIST_CERT_P12_BASE64"
  echo "::error::with an export of that certificate, or repoint this script if the profile now uses another one."
  echo "Identities present in the keychain:"
  security find-identity -p codesigning "$kc" || true
  exit 1
fi
if ! security find-identity -v -p codesigning "$kc" | grep -qi "$identity_sha1"; then
  echo "::error::The Apple Distribution certificate imported, but its chain to the Apple root cannot be built,"
  echo "::error::so codesign would fail with errSecInternalComponent."
  echo "::error::WWDR intermediates found on this runner: $chain_certs (0 = none available locally,"
  echo "::error::so the chain has to come from Infisical). Fix either one:"
  echo "::error::  (a) re-export the .p12 WITH the chain (Keychain Access: select the certificate, its"
  echo "::error::      private key and 'Apple Worldwide Developer Relations Certification Authority'"
  echo "::error::      -> Export) and update IOS_DIST_CERT_P12_BASE64;"
  echo "::error::  (b) set IOS_DIST_CERT_CHAIN_BASE64 in Infisical prod /ios to the base64 of that"
  echo "::error::      intermediate certificate."
  exit 1
fi
# Install the provisioning profile by UUID and read its name and bundle id.
prof="$RUNNER_TEMP/profile.mobileprovision"
plist="$RUNNER_TEMP/profile.plist"
printf '%s' "$IOS_PROVISIONING_PROFILE_BASE64" | base64 --decode >"$prof"
security cms -D -i "$prof" >"$plist"
uuid="$(/usr/libexec/PlistBuddy -c 'Print :UUID' "$plist")"
name="$(/usr/libexec/PlistBuddy -c 'Print :Name' "$plist")"
app_id="$(/usr/libexec/PlistBuddy -c 'Print :Entitlements:application-identifier' "$plist")"
bundle_id="${app_id#*.}" # strip the "TEAMID." prefix
mkdir -p "$HOME/Library/MobileDevice/Provisioning Profiles"
cp "$prof" "$HOME/Library/MobileDevice/Provisioning Profiles/$uuid.mobileprovision"
printf '%s' "$uuid" >"$RUNNER_TEMP/profile_uuid"
rm -f "$prof" "$plist"

# Export options for -exportArchive. `destination: upload` makes that one call
# sign the archive and hand the result to App Store Connect, which is why this
# pipeline needs no fastlane and no Ruby. `manageAppVersionAndBuildNumber:
# false` keeps the build number the archive was built with — otherwise App Store
# Connect renumbers it and the workflow run number stops matching the build.
# `signingCertificate` takes the SHA-1 rather than "Apple Distribution", for the
# same reason the check above does.
cat >"$RUNNER_TEMP/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
  <dict>
    <key>method</key><string>app-store-connect</string>
    <key>destination</key><string>upload</string>
    <key>signingStyle</key><string>manual</string>
    <key>teamID</key><string>${team_id}</string>
    <key>signingCertificate</key><string>${identity_sha1}</string>
    <key>provisioningProfiles</key>
    <dict>
      <key>${bundle_id}</key><string>${name}</string>
    </dict>
    <key>uploadSymbols</key><true/>
    <key>manageAppVersionAndBuildNumber</key><false/>
  </dict>
</plist>
PLIST

echo "Signing ready: profile '$name' ($uuid) for $bundle_id"
