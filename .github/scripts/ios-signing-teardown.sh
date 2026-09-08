#!/usr/bin/env bash
#
# Remove everything a release build left on the machine: the installed
# provisioning profile, the dedicated keychain (and the default-keychain setting
# it changed), every decoded secret, the App Store Connect key and the archive.
#
# The runner is persistent, so signing material must not survive a run — not
# even a failed one. Called twice on purpose: `mise run upload` runs it from a
# trap, and the workflow runs it again with `if: always()`, which is the net for
# a cancelled or timed-out job where the trap never fires. Every step is
# therefore idempotent and never fails the job it is cleaning up after.
set -uo pipefail

: "${RUNNER_TEMP:?not set — run this through 'mise run upload', which defaults it}"

uuid="$(cat "$RUNNER_TEMP/profile_uuid" 2>/dev/null || true)"
if [ -n "$uuid" ]; then
  rm -f "$HOME/Library/MobileDevice/Provisioning Profiles/$uuid.mobileprovision"
fi

# Only when the marker is there, which is exactly when the setup script got far
# enough to change the default keychain. A guess would be worse than doing
# nothing: the second run of this script finds the marker already deleted by the
# first, and would then overwrite a correctly restored default with a hardcoded
# one.
orig="$(cat "$RUNNER_TEMP/orig-default-keychain" 2>/dev/null || true)"
if [ -n "$orig" ]; then
  security default-keychain -s "$orig" 2>/dev/null || true
fi
security delete-keychain "$RUNNER_TEMP/release-signing.keychain-db" 2>/dev/null || true

# The first four are the decoded secrets. The setup script deletes them again
# as soon as it has imported them, but it runs under `set -e`: a failing
# `security import` — the wrong password, a chain that will not build — would
# otherwise leave the private key lying on the runner.
rm -rf "$RUNNER_TEMP/dist.p12" "$RUNNER_TEMP/chain.pem" \
  "$RUNNER_TEMP/profile.mobileprovision" "$RUNNER_TEMP/profile.plist" \
  "$RUNNER_TEMP/asc-key.p8" \
  "$RUNNER_TEMP/ZilpZalp.xcarchive" "$RUNNER_TEMP/export" \
  "$RUNNER_TEMP/ExportOptions.plist" \
  "$RUNNER_TEMP/profile_uuid" "$RUNNER_TEMP/orig-default-keychain"
