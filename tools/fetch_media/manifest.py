"""Read and write the pack manifests under `data/packs/`.

The manifest is the source of truth for a pack: the licence gate reads it, the
credits are generated from it, the Swift `Pack` model decodes it. This module
is the only thing that writes it, and it writes it exactly the way it found
it — same key order, two-space indent, non-ASCII names as themselves. A
round-trip of an unchanged manifest is byte-identical, so a diff never shows
anything but the medium that actually changed.
"""

from __future__ import annotations

import hashlib
import json
from pathlib import Path

# Anchored on the repository, not on the working directory, exactly as the
# sibling tools are: tools/fetch_media/manifest.py → tools → repository.
REPO_ROOT = Path(__file__).resolve().parent.parent.parent
PACKS_DIR = REPO_ROOT / "data" / "packs"

# The key order of a media object, as docs/medien-und-lizenzen.md spells it out
# and as data/packs/basis/manifest.json already carries it.
MEDIA_KEYS = ("file", "sha256", "license", "attribution", "sourceURL", "retrieved")


def pack_dir(pack_id: str) -> Path:
    """The directory of one pack — manifest and media sit together."""
    return PACKS_DIR / pack_id


def manifest_path(pack_id: str) -> Path:
    """The manifest of one pack."""
    return pack_dir(pack_id) / "manifest.json"


def sha256_of(path: Path) -> str:
    """The lowercase hex SHA-256 of a file, as the manifest records it."""
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def load(path: Path) -> dict:
    """Read a manifest. Object key order is preserved by `json`."""
    document = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(document, dict):
        raise ValueError(f"{path}: is not an object")
    return document


def dump(document: dict) -> str:
    """Render a manifest the way the repository stores it.

    `ensure_ascii=False`, or a photographer called Вячеслав Юсупов would turn
    into escape sequences the moment the tool touches their entry.
    """
    return json.dumps(document, indent=2, ensure_ascii=False) + "\n"


def save(path: Path, document: dict) -> None:
    """Write a JSON document — a manifest, or the candidate list beside it."""
    path.write_text(dump(document), encoding="utf-8")


def bird(document: dict, bird_id: str) -> dict:
    """The bird with that id, or a `LookupError` naming what the pack holds."""
    for entry in document.get("birds") or []:
        if isinstance(entry, dict) and entry.get("id") == bird_id:
            return entry

    known = ", ".join(str(entry.get("id")) for entry in document.get("birds") or [])
    raise LookupError(f"no bird '{bird_id}' in pack '{document.get('id')}' (has: {known})")


def media_block(
    file: str,
    sha256: str,
    licence: str,
    attribution: str,
    source_url: str,
    retrieved: str,
) -> dict:
    """A media object with its keys in the manifest's order, `MEDIA_KEYS`.

    The manifest spells the field `license`; the parameter is `licence` only
    because `license` is a builtin name in an interactive interpreter.
    """
    return {
        "file": file,
        "sha256": sha256,
        "license": licence,
        "attribution": attribution,
        "sourceURL": source_url,
        "retrieved": retrieved,
    }


def set_photo(document: dict, bird_id: str, block: dict) -> str | None:
    """Replace a bird's photo. Returns the file the entry pointed at before.

    The caller uses that to delete the previous file: the manifest is the truth
    about the pack directory, and a photo nothing references any more would
    still be copied into the app bundle by tools/sync_bundled_packs.py.
    """
    entry = bird(document, bird_id)
    previous = entry.get("photo") or {}
    entry["photo"] = block
    return previous.get("file")


def media_files(document: dict) -> list[tuple[str, str]]:
    """Every medium the manifest declares, as (relative path, SHA-256).

    Photo and call of every bird, in manifest order. What is not declared here
    is not uploaded — the bucket holds what the manifest promises, nothing that
    was left behind by an earlier curation round.
    """
    files = []
    for entry in document.get("birds") or []:
        for kind in ("photo", "call"):
            media = entry.get(kind)
            if isinstance(media, dict) and media.get("file"):
                files.append((media["file"], str(media.get("sha256", ""))))
    return files
