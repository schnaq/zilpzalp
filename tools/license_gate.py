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
"photo" and an optional "call" — null or absent while no recording exists —
both of the same shape:

    {"file": "photos/amsel.jpg", "sha256": "…", "license": "CC-BY-4.0",
     "attribution": "…", "sourceURL": "https://…"}

Speech clips are the third medium and carry three fields, because the licence
of a recorded sentence belongs to the voice that spoke it rather than to the
single clip. A bird's "speech" maps a sentence key to one clip:

    "speech": {"quiz.prompt.whereIs": {"file": "speech/…/amsel.m4a",
                                       "sha256": "…", "text": "Wo ist die Amsel?"}}

A manifest that declares at least one clip must carry a "voice" block, which
is checked exactly as a medium is, minus the file:

    "voice": {"license": "CC-BY-4.0", "attribution": "Stimme: …",
              "sourceURL": "https://…", "retrieved": "2026-09-12"}

The sentences that belong to no species live outside data/packs — they have no
birds, and the pack shape above would reject them for it. Their manifest,
data/speech/manifest.json, holds a "lines" object of the same clips and is
checked by the same rules.

Usage: python3 tools/license_gate.py [packs_dir] [--speech-dir DIR]
       (defaults: data/packs, data/speech)
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
DEFAULT_SPEECH_DIR = REPO_ROOT / "data" / "speech"

# The manifest of the sentences that belong to no pack.
SPEECH_MANIFEST_NAME = "manifest.json"


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


def check_licence(media: dict, label: str) -> list[str]:
    """Return the licence problems of one object.

    The three fields every licensed thing carries — a photo, a recording, and
    the voice a manifest's speech clips were spoken by.
    """
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

    return problems


def check_file(media: dict, label: str, base_dir: Path) -> list[str]:
    """Return the problems of the file half of a medium: path, hash, bytes."""
    relative = text_field(media, "file")
    if not relative:
        return [f"{label}: field 'file' is missing or empty"]

    # Mandatory for every asset, present locally or not: the Pack model
    # declares sha256 non-optional and the downloader verifies it.
    expected = text_field(media, "sha256").lower()
    if not expected:
        return [f"{label}: field 'sha256' is missing or empty"]

    asset = base_dir / relative
    if not asset.is_file():
        # Only in S3 — fetch-media verified the hash when it uploaded the file.
        return []

    actual = file_sha256(asset)
    if actual != expected:
        return [f"{label}: sha256 does not match {relative} (manifest {expected}, file {actual})"]

    return []


def check_media(media: object, label: str, base_dir: Path) -> list[str]:
    """Return the problems found in one media object."""
    if not isinstance(media, dict):
        return [f"{label}: is not an object"]

    return check_licence(media, label) + check_file(media, label, base_dir)


def check_clip(clip: object, label: str, base_dir: Path) -> list[str]:
    """Return the problems found in one speech clip.

    Three fields and no licence of its own: what a recorded sentence may be
    used for is a property of the voice that spoke it, and that sits once at
    the top of the manifest. `text` records what was actually said, so a
    sentence reworded in the String Catalog cannot ship with a stale clip.
    """
    if not isinstance(clip, dict):
        return [f"{label}: is not an object"]

    problems = check_file(clip, label, base_dir)
    if not text_field(clip, "text"):
        problems.append(f"{label}: field 'text' is missing or empty")
    return problems


def check_clips(clips: object, label: str, base_dir: Path) -> tuple[list[str], int]:
    """Check a sentence key → clip mapping. Returns its problems and its count."""
    if not isinstance(clips, dict):
        return ([f"{label}: is not an object"], 0)

    problems = []
    count = 0
    for sentence, clip in clips.items():
        if isinstance(clip, dict):
            count += 1
        problems.extend(check_clip(clip, f"{label} / {sentence}", base_dir))

    return problems, count


def check_voice(document: dict, clips: int) -> list[str]:
    """Check the manifest's voice against the clips it is supposed to license.

    The clips demand the voice, not the key: a manifest that declares no clip
    has nobody to credit, which is what lets `data/speech/manifest.json` exist
    before a single sentence has been recorded. A voice that is declared is
    checked either way — a half-filled block should not rot unnoticed.
    """
    voice = document.get("voice")
    if voice is None:
        return ["speech clips are declared but the manifest carries no 'voice'"] if clips else []
    if not isinstance(voice, dict):
        return ["voice: is not an object"]

    return check_licence(voice, "voice")


def load_document(path: Path) -> tuple[object, list[str]]:
    """Read one manifest, or the reason it is unusable."""
    try:
        return json.loads(path.read_text(encoding="utf-8")), []
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        return None, [f"cannot be read: {error}"]


def check_manifest(path: Path) -> tuple[list[str], int]:
    """Check one pack manifest. Returns its problems and its media asset count."""
    document, problems = load_document(path)
    if problems:
        return problems, 0

    birds = document.get("birds") if isinstance(document, dict) else None
    if not isinstance(birds, list):
        return (["no birds found (expected an object whose 'birds' key holds a list)"], 0)

    media_count = 0
    speech_count = 0

    for index, entry in enumerate(birds, start=1):
        if not isinstance(entry, dict):
            problems.append(f"bird #{index}: is not an object")
            continue

        identifier = entry.get("id")
        label = identifier if isinstance(identifier, str) and identifier else f"bird #{index}"

        if entry.get("photo") is None:
            problems.append(f"{label}: field 'photo' is missing")

        # The call is optional — it is null, or absent, as long as no freely
        # licensed recording exists for the bird. The manifest schema spells
        # it out as `"call": null`, which decodes to nil in the Pack model.
        for field in ("photo", "call"):
            if entry.get(field) is None:
                continue
            if isinstance(entry[field], dict):
                media_count += 1
            problems.extend(check_media(entry[field], f"{label} / {field}", path.parent))

        # Speech is optional the same way and one level deeper: a sentence key
        # per clip, so a pack may carry the question for one species and not
        # for the next.
        if entry.get("speech") is not None:
            clip_problems, clips = check_clips(entry["speech"], f"{label} / speech", path.parent)
            problems.extend(clip_problems)
            speech_count += clips

    problems.extend(check_voice(document, speech_count))

    return problems, media_count + speech_count


def check_speech_manifest(path: Path) -> tuple[list[str], int]:
    """Check the manifest of the sentences that belong to no pack.

    The same clips and the same voice as a pack's, without the birds: `lines`
    maps a sentence key to one clip.
    """
    document, problems = load_document(path)
    if problems:
        return problems, 0

    lines = document.get("lines") if isinstance(document, dict) else None
    if not isinstance(lines, dict):
        return (["no lines found (expected an object whose 'lines' key holds an object)"], 0)

    problems, count = check_clips(lines, "lines", path.parent)
    problems.extend(check_voice(document, count))

    return problems, count


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "packs_dir",
        nargs="?",
        default=DEFAULT_PACKS_DIR,
        type=Path,
        help=f"directory holding the pack manifests (default: {DEFAULT_PACKS_DIR})",
    )
    parser.add_argument(
        "--speech-dir",
        default=DEFAULT_SPEECH_DIR,
        type=Path,
        help=f"directory holding the fixed sentences (default: {DEFAULT_SPEECH_DIR})",
    )
    args = parser.parse_args(argv)

    if not args.packs_dir.is_dir():
        print(f"::error::{escape_data(f'Pack directory not found: {args.packs_dir}')}")
        return 1

    # rglob, not glob: a pack may grow its own directory
    # (data/packs/deutschland/birds.json) and must not escape the gate by it.
    manifests = [(path, check_manifest) for path in sorted(args.packs_dir.rglob("*.json"))]
    if not manifests:
        print(f"::notice::No pack manifests in {args.packs_dir} — the licence gate has nothing to check")

    # The fixed sentences are checked by their own entry point rather than by
    # the shape of the document: a `lines` manifest dropped into data/packs is
    # a pack without birds, and has to fail as one.
    fixed = args.speech_dir / SPEECH_MANIFEST_NAME
    if fixed.is_file():
        manifests.append((fixed, check_speech_manifest))

    total_problems = 0
    total_media = 0

    for manifest, check in manifests:
        problems, media_count = check(manifest)
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
