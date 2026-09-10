#!/usr/bin/env python3
"""Generate the credits from the pack manifests and the vendored licence files.

Attribution is never written by hand. It is derived from the manifests under
`data/packs/`, the same files the licence gate reads and tools/fetch-media writes,
so a photo that is exchanged changes its credit line with it. Fonts and icons are
not in any manifest; they come from the static lists below, whose licence files
must exist in the repository.

Two outputs, both committed:

  CREDITS.md
      For humans — readers of the repository and of the App Store listing.
  packages/ZilpZalpData/Sources/ZilpZalpData/Resources/credits.json
      For the in-app credits screen (#37), decoded by `Credits.bundled()`.

Both are written deterministically: packs sorted by id, birds in manifest order,
every photo in the order the manifest lists them and the call after them, no
timestamps. Running the tool twice yields identical bytes.

Locally it heals both files and says so. In CI it is the drift check: whenever it
had to change anything, it exits 1, because the committed credits did not match the
assets they name.

Speech clips are credited through their voice rather than one by one: a manifest
declares one voice for all the sentences it carries, so the credits name a voice
once per pack plus once for the fixed sentences under `data/speech/`. Two hundred
clips spoken by one person would otherwise be two hundred identical lines.

Usage: python3 tools/generate_credits.py [packs_dir] [--speech-dir DIR]
       (defaults: data/packs, data/speech)
Exit code 0 if both outputs were already current, 1 if one was not or a manifest
or licence file is unusable.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# Anchored on the repository, not on the working directory, so the tool finds the
# manifests no matter where it is called from.
REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PACKS_DIR = REPO_ROOT / "data" / "packs"
DEFAULT_SPEECH_DIR = REPO_ROOT / "data" / "speech"
CREDITS_MD = REPO_ROOT / "CREDITS.md"
CREDITS_JSON = REPO_ROOT / "packages" / "ZilpZalpData" / "Sources" / "ZilpZalpData" / "Resources" / "credits.json"

# Human label and deed for the licences the gate permits. The gate stays the
# authority on what is allowed; an id missing here is rendered as itself and
# fails moments later in `mise run check`, which is where that error belongs.
LICENCES = {
    "CC0-1.0": ("CC0 1.0", "https://creativecommons.org/publicdomain/zero/1.0/"),
    "CC-BY-4.0": ("CC BY 4.0", "https://creativecommons.org/licenses/by/4.0/"),
    "CC-BY-SA-4.0": ("CC BY-SA 4.0", "https://creativecommons.org/licenses/by-sa/4.0/"),
}

# The keys of a font or icon entry that reach credits.json. `label` and
# `licenseFile` are for CREDITS.md and for the existence check.
STATIC_JSON_KEYS = ("name", "authors", "license", "licenseURL")

# The name of the manifest holding the sentences that belong to no pack.
SPEECH_MANIFEST_NAME = "manifest.json"

FONTS = (
    {
        "name": "Baloo 2",
        "authors": ["Ek Type"],
        "license": "OFL-1.1",
        "label": "SIL Open Font License 1.1",
        "licenseURL": "https://openfontlicense.org/",
        "licenseFile": "apps/ZilpZalp/Resources/Fonts/Baloo2/OFL.txt",
    },
    {
        "name": "Nunito",
        "authors": ["Vernon Adams", "Cyreal", "Jacques Le Bailly"],
        "license": "OFL-1.1",
        "label": "SIL Open Font License 1.1",
        "licenseURL": "https://openfontlicense.org/",
        "licenseFile": "apps/ZilpZalp/Resources/Fonts/Nunito/OFL.txt",
    },
)

# Lucide is ISC, but part of it descends from Feather under MIT — and icons from
# that list do ship here (check, chevron-left, clock, feather, lock, music, type
# among them), so the MIT notice is required, not decorative. Both entries point
# at the one vendored file, which carries both licence texts.
ICONS = (
    {
        "name": "Lucide",
        "authors": ["Lucide Icons and Contributors"],
        "license": "ISC",
        "label": "ISC",
        "licenseURL": "https://opensource.org/license/isc-license-txt",
        "licenseFile": "packages/ZilpZalpUI/Sources/ZilpZalpUI/Resources/Licenses/LICENSE-lucide.txt",
    },
    {
        "name": "Feather",
        "authors": ["Cole Bemis"],
        "license": "MIT",
        "label": "MIT",
        "licenseURL": "https://opensource.org/license/mit",
        "licenseFile": "packages/ZilpZalpUI/Sources/ZilpZalpUI/Resources/Licenses/LICENSE-lucide.txt",
    },
)


def escape_data(message: str) -> str:
    """Escape data for a GitHub workflow command — % first, then the line breaks."""
    return message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def cell(text: str) -> str:
    """Escape a value for a Markdown table cell.

    Bird names and attributions are data — a photographer called `A|B` must not
    be able to shear the table apart.
    """
    return text.replace("\\", "\\\\").replace("|", "\\|").replace("\n", " ")


def link(label: str, url: str) -> str:
    """A Markdown link. Only ever called with the fixed URLs of the lists above."""
    return f"[{label}]({url})"


def licence_cell(identifier: str) -> str:
    """A licence as a table cell: its public name, linked to its deed.

    An id the list above does not know is rendered as itself — the gate stays
    the authority on what is allowed, and it says so on the next line of
    `mise run check`.
    """
    label, deed = LICENCES.get(identifier, (identifier, ""))
    return link(label, deed) if deed else cell(label)


def field(media: dict, name: str, label: str) -> str:
    """Return the non-empty string value of `name`, or raise naming the field."""
    value = media.get(name)
    if not isinstance(value, str) or not value.strip():
        raise ValueError(f"{label}: field '{name}' is missing or empty")
    return value.strip()


def pack_media(document: dict, pack_id: str, pack_title: str) -> list[dict]:
    """Return the credit entries of one manifest, photo before call per bird.

    Raises `ValueError` naming what is wrong. The licence gate checks the same
    manifests far more thoroughly, but it runs after this tool, so a broken
    manifest has to fail here as a sentence rather than as a traceback.
    """
    birds = document.get("birds")
    if not isinstance(birds, list):
        raise ValueError(f"{pack_id}: no birds found (expected an object whose 'birds' key holds a list)")

    entries = []
    for index, bird in enumerate(birds, start=1):
        if not isinstance(bird, dict):
            raise ValueError(f"{pack_id} / bird #{index}: is not an object")

        bird_id = field(bird, "id", f"{pack_id} / bird #{index}")
        label = f"{pack_id} / {bird_id}"
        bird_name = field(bird, "name", label)

        # A bird without a photo is not creditable. The gate says the same, in
        # its own words, on the next line of `mise run check`.
        photos = bird.get("photos")
        if not isinstance(photos, list) or not photos:
            raise ValueError(f"{label}: field 'photos' is missing or empty")

        # Every photo is credited, and the call after them. Two photos from the
        # same observation would produce the same line twice — same
        # photographer, same licence, same source — so an entry that is already
        # there is dropped: a second identical line credits nobody a second
        # time, and the credits screen keys its rows by their content.
        for kind, media in [("photo", photo) for photo in photos] + [("call", bird.get("call"))]:
            # The call is optional and stays null until a freely licensed
            # recording exists for the bird.
            if media is None:
                continue
            if not isinstance(media, dict):
                raise ValueError(f"{label} / {kind}: is not an object")

            entry = {
                "packID": pack_id,
                # The pack's own product title on every entry: the credits
                # screen groups by pack and heads each group with it, and
                # an id like `deutschland` is a directory name, not something to
                # put in front of a parent.
                "packTitle": pack_title,
                "birdID": bird_id,
                "birdName": bird_name,
                "kind": kind,
                "attribution": field(media, "attribution", f"{label} / {kind}"),
                "license": field(media, "license", f"{label} / {kind}"),
                "sourceURL": field(media, "sourceURL", f"{label} / {kind}"),
            }
            if entry not in entries:
                entries.append(entry)

    return entries


def pack_clips(document: dict) -> int:
    """How many speech clips a pack's birds declare — one sentence key per clip."""
    return sum(
        len(bird["speech"])
        for bird in document.get("birds") or []
        if isinstance(bird, dict) and isinstance(bird.get("speech"), dict)
    )


def manifest_voice(document: dict, source: str, used_in: str, clips: int) -> dict | None:
    """The credit entry for one manifest's voice, `None` when there is nothing to credit.

    A voice that has spoken no clip is not credited: a name in the app that
    belongs to no asset is as wrong as an asset nobody names. One entry per
    manifest, so a voice heard in two packs is named for each of them —
    grouping is the credits screen's business, not this file's.

    `clips` is passed in rather than counted here: a pack keeps its clips under
    the birds and the fixed set under `lines`, and each caller already knows
    which document it is reading. Deciding that from the document's own keys
    would let a stray `lines` in a pack silently change the answer — the same
    reason `tools/license_gate.py` picks its entry point by location.
    """
    voice = document.get("voice")
    if not clips:
        return None
    # Clips with nobody behind them are a licence violation, not an empty
    # section: CC BY recordings would ship with no attribution. The gate says
    # the same, in its own words, on the next line of `mise run check`.
    if voice is None:
        raise ValueError(f"{source}: speech clips are declared but the manifest carries no 'voice'")
    if not isinstance(voice, dict):
        raise ValueError(f"{source} / voice: is not an object")

    label = f"{source} / voice"
    return {
        "attribution": field(voice, "attribution", label),
        "license": field(voice, "license", label),
        "sourceURL": field(voice, "sourceURL", label),
        # The pack's product title, or the fixed set's — what a parent reads
        # in the credits, never a directory name.
        "usedIn": used_in,
    }


def read_fixed_sentences(path: Path) -> dict | None:
    """The voice of the sentences that belong to no pack, `None` when there is none.

    `data/speech/manifest.json` lies outside `data/packs` because it carries no
    birds, so `read_packs` never sees it. Its clips are credited exactly like a
    pack's: through the one voice that spoke them.
    """
    if not path.is_file():
        return None

    document = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(document, dict):
        raise ValueError(f"{path.name}: is not an object")

    lines = document.get("lines")
    if not isinstance(lines, dict):
        raise ValueError(f"{path.name}: no lines found (expected an object whose 'lines' key holds an object)")

    # Nothing recorded, nothing to credit — and no title to demand for a
    # section that is not rendered. `field` would be evaluated eagerly below.
    if not lines:
        return None

    return manifest_voice(document, path.name, field(document, "title", path.name), len(lines))


def read_packs(packs_dir: Path) -> list[dict]:
    """Read every pack under `packs_dir`, sorted by pack id.

    `rglob("*.json")`, exactly as `tools/license_gate.py` finds its manifests.
    Deliberately the same rule and not the narrower `*/manifest.json`: whatever
    the gate lets through as a pack must be credited, and a manifest that
    escaped this tool while passing the gate would ship assets nobody names.
    """
    packs = []

    # Sorted twice on purpose: by path so that a broken manifest is always the
    # same one reported first, and by id below so that two packs sharing an id
    # cannot swap sections depending on how the filesystem lists them.
    for manifest in sorted(packs_dir.rglob("*.json")):
        source = str(manifest.relative_to(packs_dir))
        document = json.loads(manifest.read_text(encoding="utf-8"))
        if not isinstance(document, dict):
            raise ValueError(f"{source}: is not an object")

        pack_id = field(document, "id", source)
        pack_title = field(document, "title", source)
        packs.append(
            {
                "id": pack_id,
                "title": pack_title,
                "media": pack_media(document, pack_id, pack_title),
                "voice": manifest_voice(document, source, pack_title, pack_clips(document)),
            }
        )

    packs.sort(key=lambda pack: pack["id"])
    return packs


def render_markdown(packs: list[dict], voices: list[dict]) -> str:
    """Render CREDITS.md."""
    lines = [
        "# Credits",
        "",
        "Generated by `tools/generate_credits.py` from the pack manifests under",
        "`data/packs/` and the licence files vendored in this repository. Do not edit by",
        "hand — `mise run check` regenerates the file and fails when it had drifted.",
        "",
        "Every photo and every recording is used under a licence that permits commercial",
        "use and derivative works: CC0, CC BY or CC BY-SA. The names below are the ones",
        "the source declared.",
        "",
        "## Photos and calls",
    ]

    for pack in packs:
        lines += [
            "",
            f"### {cell(pack['title'])} (`{pack['id']}`)",
            "",
            "| Bird | Kind | Author | Licence | Source |",
            "| --- | --- | --- | --- | --- |",
        ]
        for entry in pack["media"]:
            lines.append(
                f"| {cell(entry['birdName'])} "
                f"| {entry['kind'].capitalize()} "
                f"| {cell(entry['attribution'])} "
                f"| {licence_cell(entry['license'])} "
                # An autolink, so the URL itself stays readable: proof of origin
                # is worth more here than a tidy column.
                f"| <{entry['sourceURL']}> |"
            )

    # Only when somebody has spoken: an empty table would say that the app has
    # recorded speech, which until Task 4 of the plan it has not.
    if voices:
        lines += [
            "",
            "## Voices",
            "",
            "| Voice | Licence | Spoken for | Source |",
            "| --- | --- | --- | --- |",
        ]
        for entry in voices:
            lines.append(
                f"| {cell(entry['attribution'])} "
                f"| {licence_cell(entry['license'])} "
                f"| {cell(entry['usedIn'])} "
                f"| <{entry['sourceURL']}> |"
            )

    for heading, group, first_column in (("Fonts", FONTS, "Font"), ("Icons", ICONS, "Set")):
        lines += [
            "",
            f"## {heading}",
            "",
            f"| {first_column} | Authors | Licence | Licence text |",
            "| --- | --- | --- | --- |",
        ]
        for entry in group:
            lines.append(
                f"| {cell(entry['name'])} "
                f"| {cell(', '.join(entry['authors']))} "
                f"| {link(entry['label'], entry['licenseURL'])} "
                f"| `{entry['licenseFile']}` |"
            )

    lines += [
        "",
        "Some Lucide icons descend from the Feather project and carry the MIT licence",
        "instead of ISC. The vendored `LICENSE-lucide.txt` names them and holds both",
        "licence texts.",
        "",
    ]

    return "\n".join(lines)


def render_json(packs: list[dict], voices: list[dict]) -> str:
    """Render credits.json — the document `Credits.bundled()` decodes."""
    document = {
        "media": [entry for pack in packs for entry in pack["media"]],
        "voices": voices,
        "fonts": [{key: entry[key] for key in STATIC_JSON_KEYS} for entry in FONTS],
        "icons": [{key: entry[key] for key in STATIC_JSON_KEYS} for entry in ICONS],
    }
    # ensure_ascii=False, or "Вячеслав Юсупов" would ship as escape sequences and
    # nobody could read their own name in the credits.
    return json.dumps(document, indent=2, ensure_ascii=False) + "\n"


def write_if_changed(path: Path, text: str) -> bool:
    """Write `text` to `path` unless it is already there. Returns whether it changed."""
    encoded = text.encode("utf-8")
    if path.is_file() and path.read_bytes() == encoded:
        return False

    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(encoded)
    return True


def missing_licence_files() -> list[str]:
    """Return the licence files of the static lists that are not in the repository."""
    return sorted(
        {entry["licenseFile"] for entry in FONTS + ICONS if not (REPO_ROOT / entry["licenseFile"]).is_file()}
    )


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

    # A speech directory whose manifest is not where it is looked for would
    # quietly strip the voices from the credits it then rewrites — attribution
    # gone, exit code the same as a routine drift.
    if args.speech_dir.is_dir() and not (args.speech_dir / SPEECH_MANIFEST_NAME).is_file():
        message = f"No {SPEECH_MANIFEST_NAME} in {args.speech_dir} — its voices cannot be credited"
        print(f"::error::{escape_data(message)}")
        return 1

    # A font that ships without its licence text is the same violation as a photo
    # without attribution, and the credits would name a file that is not there.
    missing = missing_licence_files()
    for relative in missing:
        print(f"::error::{escape_data(f'Licence file missing: {relative}')}")
    if missing:
        return 1

    try:
        packs = read_packs(args.packs_dir)
        # The packs first and the fixed sentences last, so the order of the
        # voices is the order of the credits screen's sections.
        voices = [pack["voice"] for pack in packs if pack["voice"]]
        fixed = read_fixed_sentences(args.speech_dir / SPEECH_MANIFEST_NAME)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as error:
        print(f"::error::{escape_data(f'Credits cannot be generated: {error}')}")
        return 1

    if fixed:
        voices.append(fixed)

    stale = [
        path.name
        for path, text in (
            (CREDITS_MD, render_markdown(packs, voices)),
            (CREDITS_JSON, render_json(packs, voices)),
        )
        if write_if_changed(path, text)
    ]
    assets = sum(len(pack["media"]) for pack in packs)

    if stale:
        message = (
            f"The credits were stale and have been regenerated from {args.packs_dir} "
            f"({', '.join(stale)}). Commit the result."
        )
        print(f"::error::{escape_data(message)}")
        return 1

    print(
        f"Credits current: {assets} media asset(s) in {len(packs)} pack(s), "
        f"{len(voices)} voice(s), {len(FONTS)} font(s), {len(ICONS)} icon set(s)"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
