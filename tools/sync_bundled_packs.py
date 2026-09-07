#!/usr/bin/env python3
"""Keep the bundled packs inside ZilpZalpData in step with data/packs.

`data/packs/<id>/` is the single source of truth for a pack — the licence gate
reads it, tools/fetch-media writes it. The base pack additionally ships inside
the app, as a SwiftPM resource of ZilpZalpData, so that PackCatalog can load it
through Bundle.module and `swift test` can exercise it without a simulator.

A symlink would have been cheaper and was tried first: SwiftPM copies a `.copy`
resource with the link intact, so the relative target dangles inside .build and
the bundle holds nothing. Hence a tracked copy, kept honest by this script.

Locally it heals the copy and says so. In CI it is the drift check: whenever it
had to change anything, it exits 1, because the copy in the repository was
stale and the commit would have shipped a pack that differs from data/packs.

Usage: python3 tools/sync_bundled_packs.py
Exit code 0 if every bundled pack was already current, 1 if one was not.
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
BUNDLE_DIR = REPO_ROOT / "packages" / "ZilpZalpData" / "Sources" / "ZilpZalpData" / "Resources" / "Packs"

# Only the base pack ships with the app. Every other pack is downloaded (#33)
# and has no business inflating the binary.
BUNDLED_PACKS = ("basis",)


def escape_data(message: str) -> str:
    """Escape data for a GitHub workflow command — % first, then the line breaks."""
    return message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def differences(source: Path, destination: Path) -> list[str]:
    """Return the paths, relative to `source`, where the two trees differ.

    Compares file contents rather than timestamps: a checkout gives every file
    the same fresh mtime, which would make a shallow comparison see drift that
    is not there.
    """
    source_files = {path.relative_to(source) for path in source.rglob("*") if path.is_file()}
    destination_files = {
        path.relative_to(destination) for path in destination.rglob("*") if path.is_file()
    }

    changed = source_files ^ destination_files
    for relative in source_files & destination_files:
        if not filecmp.cmp(source / relative, destination / relative, shallow=False):
            changed.add(relative)

    return sorted(str(relative) for relative in changed)


def sync(source: Path, destination: Path) -> list[str]:
    """Make `destination` identical to `source`. Returns what differed."""
    if not source.is_dir():
        raise FileNotFoundError(f"no pack at {source}")

    changed = differences(source, destination) if destination.is_dir() else ["(the whole pack)"]
    if changed:
        shutil.rmtree(destination, ignore_errors=True)
        shutil.copytree(source, destination)

    return changed


def main() -> int:
    stale = 0

    for pack in BUNDLED_PACKS:
        try:
            changed = sync(SOURCE_DIR / pack, BUNDLE_DIR / pack)
        except (OSError, shutil.Error) as error:
            print(f"::error::{escape_data(f'{pack}: cannot be synced: {error}')}")
            return 1

        if not changed:
            print(f"{pack}: bundled copy is current")
            continue

        stale += 1
        listing = ", ".join(changed)
        message = (
            f"{pack}: the bundled copy was stale and has been refreshed from "
            f"data/packs/{pack} ({listing}). Commit the result."
        )
        print(f"::error::{escape_data(message)}")

    if stale:
        print(f"Bundled packs out of date: {stale} of {len(BUNDLED_PACKS)}")
        return 1

    print(f"Bundled packs in sync: {len(BUNDLED_PACKS)} pack(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
