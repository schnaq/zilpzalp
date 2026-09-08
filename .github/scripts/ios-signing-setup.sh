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
#                                   intermediate (PEM/DER). An override for a
#                                   generation .github/certs does not carry yet;
#                                   the committed intermediates cover the normal
#                                   case, so this is normally unset.
#
# Writes into $RUNNER_TEMP, for the export step and for the teardown script:
#   orig-default-keychain, profile_uuid, ExportOptions.plist
set -euo pipefail

# Everything below writes into $RUNNER_TEMP on a shared, persistent machine, and
# some of it is a private key. One umask covers every file this script creates
# instead of wrapping each decode.
umask 077

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
# developer Mac and failed on the runner: the intermediates arrive with Xcode in
# an interactive login keychain, and the runner's CI user has none of that. The
# first TestFlight run died exactly there — the machine offered two
# intermediates and neither was the generation that issued our certificate.
#
# The intermediates therefore come from the repository, not from the machine.
# Three sources, in this order, all local — nothing is downloaded during a job:
#   1. .github/certs/*.cer, committed and always imported (README there)
#   2. the runner's own keychains, kept as a second source
#   3. IOS_DIST_CERT_CHAIN_BASE64, an override for a generation we do not carry
# The validity check further down is the backstop for all three.
certs_dir="$(dirname "${BASH_SOURCE[0]}")/../certs"
shopt -s nullglob
vendored=("$certs_dir"/*.cer)
shopt -u nullglob
if [ "${#vendored[@]}" -eq 0 ]; then
  echo "::error::No certificates in $certs_dir. The Apple WWDR intermediates are committed to"
  echo "::error::this repository on purpose — see .github/certs/README.md. Restore them."
  exit 1
fi
for cer in "${vendored[@]}"; do
  # No `|| true` here, unlike the harvest below: this keychain was created
  # seconds ago, so nothing can be a duplicate yet and a failure means the file
  # is unreadable or not a certificate. That must stop the release.
  security import "$cer" -k "$kc" -T /usr/bin/codesign -T /usr/bin/xcodebuild >/dev/null
done
echo "WWDR intermediates imported from .github/certs: ${#vendored[@]}"

chain="$RUNNER_TEMP/chain.pem"
if [ -n "${IOS_DIST_CERT_CHAIN_BASE64:-}" ]; then
  printf '%s' "$IOS_DIST_CERT_CHAIN_BASE64" | base64 --decode >"$chain"
  chain_source="IOS_DIST_CERT_CHAIN_BASE64"
else
  # The runner's own keychains are named explicitly — the same list the search
  # list was rebuilt from. Searching the whole search list would find the
  # release keychain first and count the certificates just imported from
  # .github/certs, which would make the number below meaningless exactly when
  # it is needed.
  # shellcheck disable=SC2086  # deliberate word splitting: one argument per keychain
  security find-certificate -a -c "Apple Worldwide Developer Relations" -p \
    $prev /Library/Keychains/System.keychain >"$chain" 2>/dev/null || true
  chain_source="this runner's own keychains"
fi
chain_certs=0
if [ -s "$chain" ]; then
  chain_certs="$(grep -c 'BEGIN CERTIFICATE' "$chain" || true)"
  # Duplicates against the vendored set are the normal case now, and
  # re-importing a certificate that is already there is not worth failing a
  # release over.
  security import "$chain" -k "$kc" -T /usr/bin/codesign -T /usr/bin/xcodebuild \
    >/dev/null 2>&1 || true
fi
rm -f "$chain"
echo "WWDR intermediates additionally offered by $chain_source: $chain_certs"

security set-key-partition-list -S apple-tool:,apple:,codesign: -s -k "$kc_pw" "$kc" >/dev/null
rm -f "$p12"

# Printed on every run, so a chain problem is diagnosable from the log alone
# instead of needing a second run with extra echoes. All of it is public
# certificate metadata: subject, issuer, SHA-1 fingerprint. Nothing else from
# the .p12 is ever shown — not the password, not the private key.
leaf="$RUNNER_TEMP/leaf.pem"
security find-certificate -c "Apple Distribution" -p "$kc" >"$leaf" 2>/dev/null || true
echo "Signing certificate in the release keychain:"
if [ -s "$leaf" ]; then
  openssl x509 -in "$leaf" -noout -subject -issuer -fingerprint -sha1 |
    sed 's/^/  /' || echo "  (present, but could not be parsed)"
else
  echo "  none — no certificate named 'Apple Distribution' is in this keychain"
fi
intermediates="$(security find-certificate -a -c "Apple Worldwide Developer Relations" -p "$kc" 2>/dev/null || true)"
echo "WWDR intermediates now in the release keychain:"
if [ -n "$intermediates" ]; then
  # crl2pkcs7 wraps the whole PEM bundle so that `pkcs7 -print_certs` walks
  # every certificate in it; `openssl x509` would only ever read the first.
  printf '%s\n' "$intermediates" |
    openssl crl2pkcs7 -nocrl -certfile /dev/stdin |
    openssl pkcs7 -print_certs -noout |
    sed '/^[[:space:]]*$/d; s/^/  /' || echo "  (present, but could not be parsed)"
else
  echo "  none"
fi

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
  echo "::error::The Apple Distribution certificate imported, but its chain to a trusted Apple root"
  echo "::error::cannot be built, so codesign would fail with errSecInternalComponent."
  # -L keeps this strictly local: no CA certificate is fetched from the net, so
  # the verdict describes this machine and matches the rest of the pipeline.
  echo "What Security says about the chain:"
  if [ -s "$leaf" ]; then
    security verify-cert -k "$kc" -c "$leaf" -p codeSign -L 2>&1 | sed 's/^/  /' || true
  else
    echo "  no leaf certificate to verify — see the empty listing above"
  fi
  echo "Identities considered valid in this keychain:"
  security find-identity -v -p codesigning "$kc" || true
  echo "::error::Compare the certificate's issuer printed above against the intermediates listed"
  echo "::error::next to it, then take the matching repair:"
  echo "::error::  (a) the issuer's OU is NOT among them — that generation is missing from"
  echo "::error::      .github/certs. Download it from https://www.apple.com/certificateauthority/"
  echo "::error::      and commit it, exactly as .github/certs/README.md describes;"
  echo "::error::  (b) the issuer's OU IS among them — then the missing link is the root the"
  echo "::error::      issuer line names. Check it with:"
  echo "::error::        security find-certificate -c 'Apple Root CA - G3' \\"
  echo "::error::          /System/Library/Keychains/SystemRootCertificates.keychain"
  echo "::error::      (a root has to be trusted, so committing one would not help — the runner's"
  echo "::error::      system trust store has to carry it);"
  echo "::error::  (c) neither fits — re-export the .p12 WITH its chain and update"
  echo "::error::      IOS_DIST_CERT_P12_BASE64, or set IOS_DIST_CERT_CHAIN_BASE64 in Infisical"
  echo "::error::      prod /ios ($chain_certs certificate(s) came from that second source here)."
  exit 1
fi
rm -f "$leaf"
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
