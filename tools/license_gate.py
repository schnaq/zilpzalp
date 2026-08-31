#!/usr/bin/env python3
"""Check every media asset declared in the pack manifests against the licence rules.

Only CC0, CC BY and CC BY-SA are permitted (see docs/medien-und-lizenzen.md).
Every NonCommercial and NoDerivatives variant fails the gate, as does a
missing attribution or a missing source URL. Licence compliance is thereby a
property of the build rather than a matter of care.

The SHA-256 of an asset is verified only where the file is present next to
the manifest. Assets that only live in the S3 bucket — the Germany pack, for
instance — are hashed by tools/fetch-media at upload time; CI does not
download media on every run. Licence, attribution and source URL are checked
for those assets all the same.

Manifest shape: a pack object whose species live under "species" (or "birds",
as the Pack model in the spec names them); a bare array of species is
accepted too. Each species carries a mandatory "photo" and an optional
"call", both of the same shape:

    {"file": "photos/amsel.jpg", "sha256": "…", "license": "CC-BY-4.0",
     "attribution": "…", "sourceURL": "https://…"}

Usage: python3 tools/license_gate.py [packs_dir]  (default: data/packs)
Exit code 0 if every asset passes, 1 on the first violation found.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

ALLOWED_LICENCES = ("CC0-1.0", "CC-BY-4.0", "CC-BY-SA-4.0")

# Keys under which a pack object may carry its species. "birds" is what the
# Pack model in the spec uses, "species" what the manifests are written with.
SPECIES_KEYS = ("species", "birds")

DEFAULT_PACKS_DIR = "data/packs"

# Read large audio files in pieces rather than into one buffer.
CHUNK_SIZE = 1 << 20


def file_sha256(path: Path) -> str:
    """Return the lowercase hex SHA-256 of the file at `path`."""
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(CHUNK_SIZE), b""):
            digest.update(chunk)
    return digest.hexdigest()


def text_field(media: dict, name: str) -> str:
    """Return the stripped string value of `name`, empty if absent or not a string."""
    value = media.get(name)
    return value.strip() if isinstance(value, str) else ""


def check_media(media: object, label: str, base_dir: Path) -> tuple[list[str], bool]:
    """Check one media object.

    Returns the problems found and whether its hash was verified — an asset
    that is not present locally is not a problem, it is simply not hashed.
    """
    if not isinstance(media, dict):
        return ([f"{label}: is not an object"], False)

    problems = []

    licence = media.get("license")
    if not licence:
        problems.append(f"{label}: field 'license' is missing or empty")
    elif licence not in ALLOWED_LICENCES:
        allowed = ", ".join(ALLOWED_LICENCES)
        problems.append(f"{label}: licence '{licence}' is not permitted (allowed: {allowed})")

    if not text_field(media, "attribution"):
        problems.append(f"{label}: field 'attribution' is missing or empty")

    if not text_field(media, "sourceURL"):
        problems.append(f"{label}: field 'sourceURL' is missing or empty")

    relative = text_field(media, "file")
    if not relative:
        problems.append(f"{label}: field 'file' is missing or empty")
        return problems, False

    asset = base_dir / relative
    if not asset.is_file():
        # Only in S3 — fetch-media verified the hash when it uploaded the file.
        return problems, False

    expected = text_field(media, "sha256").lower()
    if not expected:
        problems.append(f"{label}: field 'sha256' is missing or empty, but {relative} is present locally")
        return problems, False

    actual = file_sha256(asset)
    if actual != expected:
        problems.append(f"{label}: sha256 does not match {relative} (manifest {expected}, file {actual})")

    return problems, True


def species_list(document: object) -> list | None:
    """Return the species of a manifest, or None if the shape is unrecognised."""
    if isinstance(document, list):
        return document
    if isinstance(document, dict):
        for key in SPECIES_KEYS:
            value = document.get(key)
            if isinstance(value, list):
                return value
    return None


def check_manifest(path: Path) -> tuple[list[str], int, int]:
    """Check one manifest. Returns its problems, media asset count and hashed count."""
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except OSError as error:
        return ([f"cannot be read: {error.strerror or error}"], 0, 0)
    except (UnicodeDecodeError, json.JSONDecodeError) as error:
        return ([f"is not valid JSON: {error}"], 0, 0)

    species = species_list(document)
    if species is None:
        keys = " or ".join(f"'{key}'" for key in SPECIES_KEYS)
        return ([f"no species found (expected an object with {keys}, or a bare array)"], 0, 0)

    problems = []
    media_count = 0
    hashed_count = 0

    for index, entry in enumerate(species, start=1):
        if not isinstance(entry, dict):
            problems.append(f"species #{index}: is not an object")
            continue

        identifier = entry.get("id")
        label = identifier if isinstance(identifier, str) and identifier else f"species #{index}"

        if "photo" not in entry:
            problems.append(f"{label}: field 'photo' is missing")

        # The call is optional — it is absent as long as no freely licensed
        # recording exists for the species.
        for field in ("photo", "call"):
            if field not in entry:
                continue
            media_count += 1
            found, hashed = check_media(entry[field], f"{label} / {field}", path.parent)
            problems.extend(found)
            hashed_count += int(hashed)

    return problems, media_count, hashed_count


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "packs_dir",
        nargs="?",
        default=DEFAULT_PACKS_DIR,
        type=Path,
        help=f"directory holding the pack manifests (default: {DEFAULT_PACKS_DIR})",
    )
    args = parser.parse_args(argv)

    if not args.packs_dir.is_dir():
        print(f"::error::Pack directory not found: {args.packs_dir}")
        return 1

    manifests = sorted(args.packs_dir.glob("*.json"))
    if not manifests:
        print(f"::notice::No pack manifests in {args.packs_dir} — the licence gate has nothing to check")
        return 0

    total_problems = 0
    total_media = 0

    for manifest in manifests:
        problems, media_count, hashed_count = check_manifest(manifest)
        for problem in problems:
            print(f"::error file={manifest}::{problem}")
        total_problems += len(problems)
        total_media += media_count
        skipped = media_count - hashed_count
        print(
            f"{manifest}: media assets: {media_count}"
            f" (hashes verified: {hashed_count}, not present locally: {skipped})"
        )

    manifest_count = f"{len(manifests)} manifest" + ("" if len(manifests) == 1 else "s")
    if total_problems:
        print(f"Licence gate failed: {total_problems} problems in {manifest_count}")
        return 1

    print(f"Licence gate passed: {total_media} media assets in {manifest_count}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
