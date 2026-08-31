#!/usr/bin/env python3
"""Check every media asset declared in the pack manifests against the licence rules.

Only CC0, CC BY and CC BY-SA are permitted (see docs/medien-und-lizenzen.md).
Every NonCommercial and NoDerivatives variant fails the gate, as does a
missing attribution or a missing source URL. Licence compliance is thereby a
property of the build rather than a matter of care.

Every asset must declare its SHA-256; it is verified where the file is
present next to the manifest. Assets that only live in the S3 bucket — the
Germany pack, for instance — are hashed by tools/fetch-media at upload time;
CI does not download media on every run. Licence, attribution and source URL
are checked for those assets all the same.

Manifest shape: the one the Pack model in the spec defines — a JSON object
whose "birds" key holds the list of birds. Each bird carries a mandatory
"photo" and an optional "call", both of the same shape:

    {"file": "photos/amsel.jpg", "sha256": "…", "license": "CC-BY-4.0",
     "attribution": "…", "sourceURL": "https://…"}

Usage: python3 tools/license_gate.py [packs_dir]  (default: data/packs)
Exit code 0 if every asset passes, 1 if any violation is found — the gate
reports all problems before it exits.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import sys
from pathlib import Path

ALLOWED_LICENCES = ("CC0-1.0", "CC-BY-4.0", "CC-BY-SA-4.0")

# Anchored on the repository, not on the working directory, so the gate finds
# the manifests no matter where it is called from.
REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PACKS_DIR = REPO_ROOT / "data" / "packs"


def file_sha256(path: Path) -> str:
    """Return the lowercase hex SHA-256 of the file at `path`."""
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def escape_data(message: str) -> str:
    """Escape data for a GitHub workflow command — % first, then the line breaks."""
    return message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def text_field(media: dict, name: str) -> str:
    """Return the stripped string value of `name`, empty if absent or not a string."""
    value = media.get(name)
    return value.strip() if isinstance(value, str) else ""


def check_media(media: object, label: str, base_dir: Path) -> list[str]:
    """Return the problems found in one media object."""
    if not isinstance(media, dict):
        return [f"{label}: is not an object"]

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
        return problems

    # Mandatory for every asset, present locally or not: the Pack model
    # declares sha256 non-optional and the downloader verifies it.
    expected = text_field(media, "sha256").lower()
    if not expected:
        problems.append(f"{label}: field 'sha256' is missing or empty")
        return problems

    asset = base_dir / relative
    if not asset.is_file():
        # Only in S3 — fetch-media verified the hash when it uploaded the file.
        return problems

    actual = file_sha256(asset)
    if actual != expected:
        problems.append(f"{label}: sha256 does not match {relative} (manifest {expected}, file {actual})")

    return problems


def check_manifest(path: Path) -> tuple[list[str], int]:
    """Check one manifest. Returns its problems and its media asset count."""
    try:
        document = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        return ([f"cannot be read: {error}"], 0)

    birds = document.get("birds") if isinstance(document, dict) else None
    if not isinstance(birds, list):
        return (["no birds found (expected an object whose 'birds' key holds a list)"], 0)

    problems = []
    media_count = 0

    for index, entry in enumerate(birds, start=1):
        if not isinstance(entry, dict):
            problems.append(f"bird #{index}: is not an object")
            continue

        identifier = entry.get("id")
        label = identifier if isinstance(identifier, str) and identifier else f"bird #{index}"

        if "photo" not in entry:
            problems.append(f"{label}: field 'photo' is missing")

        # The call is optional — it is absent as long as no freely licensed
        # recording exists for the bird.
        for field in ("photo", "call"):
            if field not in entry:
                continue
            if isinstance(entry[field], dict):
                media_count += 1
            problems.extend(check_media(entry[field], f"{label} / {field}", path.parent))

    return problems, media_count


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
        print(f"::error::{escape_data(f'Pack directory not found: {args.packs_dir}')}")
        return 1

    # rglob, not glob: a pack may grow its own directory
    # (data/packs/deutschland/birds.json) and must not escape the gate by it.
    manifests = sorted(args.packs_dir.rglob("*.json"))
    if not manifests:
        print(f"::notice::No pack manifests in {args.packs_dir} — the licence gate has nothing to check")
        return 0

    total_problems = 0
    total_media = 0

    for manifest in manifests:
        problems, media_count = check_manifest(manifest)
        # Workspace-relative, or GitHub cannot anchor the annotation on the
        # file in the pull request view; absolute paths only show in the log.
        try:
            location = manifest.relative_to(Path.cwd())
        except ValueError:
            location = manifest
        for problem in problems:
            print(f"::error file={location}::{escape_data(problem)}")
        total_problems += len(problems)
        total_media += media_count
        print(f"{location}: media assets checked: {media_count}")

    if total_problems:
        print(f"Licence gate failed: {total_problems} problem(s) in {len(manifests)} manifest(s)")
        return 1

    print(f"Licence gate passed: {total_media} media asset(s) in {len(manifests)} manifest(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
