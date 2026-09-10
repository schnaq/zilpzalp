#!/usr/bin/env python3
"""Keep the bundled resources inside ZilpZalpData in step with data/.

`data/packs/<id>/` is the single source of truth for a pack — the licence gate
reads it, tools/fetch-media writes it. The base pack additionally ships inside
the app, as a SwiftPM resource of ZilpZalpData, so that PackCatalog can load it
through Bundle.module and `swift test` can exercise it without a simulator.

`data/speech/` is the same arrangement for the sentences that belong to no
pack: SpeechCatalog reads them from Bundle.module, so the copy under
Resources/Speech has to be kept honest by the same check.

A symlink would have been cheaper and was tried first: SwiftPM copies a `.copy`
resource with the link intact, so the relative target dangles inside .build and
the bundle holds nothing. Hence a tracked copy, kept honest by this script.

Locally it heals the copy and says so. In CI it is the drift check: whenever it
had to change anything, it exits 1, because the copy in the repository was
stale and the commit would have shipped a pack that differs from data/packs.

Usage: python3 tools/sync_bundled_packs.py
Exit code 0 if every bundled copy was already current, 1 if one was not.
"""

from __future__ import annotations

import filecmp
import shutil
import sys
from pathlib import Path

# Anchored on the repository, not on the working directory, so the script
# finds the packs no matter where it is called from.
REPO_ROOT = Path(__file__).resolve().parent.parent
SOURCE_DIR = REPO_ROOT / "data" / "packs"
RESOURCES_DIR = REPO_ROOT / "packages" / "ZilpZalpData" / "Sources" / "ZilpZalpData" / "Resources"
BUNDLE_DIR = RESOURCES_DIR / "Packs"

# Only the base pack ships with the app. Every other pack is downloaded (#33)
# and has no business inflating the binary. Read by tools/fetch_media/index.py,
# which keeps the bundled packs out of the downloadable index.
BUNDLED_PACKS = ("deutschland",)

# What ships inside the app, as (label, source, destination): the bundled packs,
# plus the sentences that belong to no pack. The app says those on every screen,
# so they are bundled rather than downloaded.
#
# Built once, at import, so this tuple — not SOURCE_DIR — is what main() reads
# and what a test patches to sync somewhere else.
BUNDLED_COPIES = (
    *((pack, SOURCE_DIR / pack, BUNDLE_DIR / pack) for pack in BUNDLED_PACKS),
    ("speech", REPO_ROOT / "data" / "speech", RESOURCES_DIR / "Speech"),
)


def escape_data(message: str) -> str:
    """Escape data for a GitHub workflow command — % first, then the line breaks."""
    return message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def pack_files(directory: Path) -> set[Path]:
    """Return the pack's files, relative to `directory`, hidden ones excluded.

    A pack is a manifest and its media; nothing in it starts with a dot. The
    exclusion is about `.DS_Store`, which Finder drops into any directory
    somebody opens. It is git-ignored, so it would be invisible in `git
    status` while making the next `mise run check` report drift that is not
    there — and it would end up inside the app bundle.
    """
    files = set()
    for path in directory.rglob("*"):
        relative = path.relative_to(directory)
        if path.is_file() and not any(part.startswith(".") for part in relative.parts):
            files.add(relative)
    return files


def differences(source: Path, destination: Path) -> list[str]:
    """Return the paths, relative to `source`, where the two trees differ.

    Compares file contents rather than timestamps: a checkout gives every file
    the same fresh mtime, which would make a shallow comparison see drift that
    is not there.
    """
    source_files = pack_files(source)
    destination_files = pack_files(destination)

    changed = source_files ^ destination_files
    for relative in source_files & destination_files:
        if not filecmp.cmp(source / relative, destination / relative, shallow=False):
            changed.add(relative)

    return sorted(str(relative) for relative in changed)


def sync(source: Path, destination: Path) -> list[str]:
    """Make `destination` identical to `source`. Returns what differed."""
    if not source.is_dir():
        raise FileNotFoundError(f"nothing to sync at {source}")

    changed = differences(source, destination) if destination.is_dir() else ["(the whole directory)"]
    if changed:
        shutil.rmtree(destination, ignore_errors=True)
        # Same exclusion as pack_files, or a hidden file would be copied and
        # then never be reported as drift again.
        shutil.copytree(source, destination, ignore=shutil.ignore_patterns(".*"))

    return changed


def main() -> int:
    stale = 0

    for label, source, destination in BUNDLED_COPIES:
        try:
            changed = sync(source, destination)
        except OSError as error:
            print(f"::error::{escape_data(f'{label}: cannot be synced: {error}')}")
            return 1

        if not changed:
            print(f"{label}: bundled copy is current")
            continue

        stale += 1
        listing = ", ".join(changed)
        # Named as the repository names it — `data/speech` rather than an
        # absolute path. Only a test's temporary directory lies outside.
        origin = source.relative_to(REPO_ROOT) if source.is_relative_to(REPO_ROOT) else source
        message = (
            f"{label}: the bundled copy was stale and has been refreshed from "
            f"{origin} ({listing}). Commit the result."
        )
        print(f"::error::{escape_data(message)}")

    if stale:
        print(f"Bundled copies out of date: {stale} of {len(BUNDLED_COPIES)}")
        return 1

    print(f"Bundled copies in sync: {len(BUNDLED_COPIES)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
