#!/usr/bin/env bash
#
# Remove everything a release build left on the machine: the installed
# provisioning profile, the dedicated keychain (and the default-keychain setting
# it changed), the App Store Connect key and the archive.
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

orig="$(cat "$RUNNER_TEMP/orig-default-keychain" 2>/dev/null || true)"
security default-keychain -s "${orig:-$HOME/Library/Keychains/login.keychain-db}" 2>/dev/null || true
security delete-keychain "$RUNNER_TEMP/release-signing.keychain-db" 2>/dev/null || true

rm -rf "$RUNNER_TEMP/ZilpZalp.xcarchive" "$RUNNER_TEMP/export" \
  "$RUNNER_TEMP/ExportOptions.plist" "$RUNNER_TEMP/asc-key.p8" \
  "$RUNNER_TEMP/profile_uuid" "$RUNNER_TEMP/orig-default-keychain"
