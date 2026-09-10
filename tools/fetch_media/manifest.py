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

# The sentences that belong to no species live outside `data/packs/`, because
# the licence gate reads every *.json below that directory as a pack and would
# fail a document without birds. Same manifest, `lines` where the birds would
# be — tools/license_gate.py says the rest.
SPEECH_DIR = REPO_ROOT / "data" / "speech"

# The key order of a media object, as docs/medien-und-lizenzen.md spells it out
# and as data/packs/deutschland/manifest.json already carries it.
MEDIA_KEYS = ("file", "sha256", "license", "attribution", "sourceURL", "retrieved")

# The one medium a bird carries as a single object. `call` stays null until a
# freely licensed recording exists — the licence gate and the Swift `Bird`
# model both allow it.
#
# Neither photos nor speech are among them. A bird's `photos` is a list of at
# least one (#194) and `add_photo` appends to it; its `speech` is a sentence key
# per clip, and its licence sits once on the manifest's `voice`. `set_media`
# therefore refuses both, and `media_files` reads them apart.
MEDIA_KINDS = ("call",)

# Where a bird keeps its photos: a list, the curated portrait first. A quiz tile
# shows one of them at a time, the sticker and the album always the first.
PHOTOS_KIND = "photos"

# Where a bird keeps its recorded sentences, and where the fixed set keeps its
# own. One sentence key per clip in both.
SPEECH_KIND = "speech"
LINES_KIND = "lines"

# A clip carries three fields and no more: what was said belongs to the
# sentence, who said it under which licence belongs to the manifest's `voice`.
SPEECH_KEYS = ("file", "sha256", "text")

# The voice, once per manifest. `retrieved` joins them when it is written, the
# way a medium carries it — see `voice_block`.
VOICE_KEYS = ("license", "attribution", "sourceURL", "retrieved")

# What makes one voice another: two clips may be produced weeks apart, so the
# date is not part of the identity.
VOICE_IDENTITY = ("license", "attribution", "sourceURL")


def pack_dir(pack_id: str) -> Path:
    """The directory of one pack — manifest and media sit together."""
    return PACKS_DIR / pack_id


def manifest_path(pack_id: str) -> Path:
    """The manifest of one pack."""
    return pack_dir(pack_id) / "manifest.json"


def speech_manifest_path() -> Path:
    """The manifest of the sentences that belong to no pack."""
    return SPEECH_DIR / "manifest.json"


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


def photos(entry: dict) -> list:
    """A bird's photos, the empty list while it has none.

    `or []` rather than `get(..., [])`: a manifest may carry `"photos": null`
    the way a bird carries `"call": null`, and a null would reach the caller as
    something it cannot iterate.
    """
    return entry.get(PHOTOS_KIND) or []


def next_photo_file(entry: dict, species: str, suffix: str) -> str:
    """The file name the species' next photo gets.

    `photos/<species>.<suffix>` for the first, then `-2`, `-3`, … — **one past
    the highest number in use**, never the lowest free one. A name that was
    dropped stays dropped: it is in the bucket and possibly on a device, and a
    second, different photo under it would be the one file whose content depends
    on when it was fetched.
    """
    used = [0]
    for photo in photos(entry):
        stem = Path(str(photo.get("file", ""))).stem
        if stem == species:
            used.append(1)
        elif stem.startswith(f"{species}-") and stem[len(species) + 1 :].isdigit():
            used.append(int(stem[len(species) + 1 :]))

    number = max(used) + 1
    name = species if number == 1 else f"{species}-{number}"
    return f"photos/{name}.{suffix}"


def add_photo(document: dict, bird_id: str, block: dict) -> None:
    """Append one photo to a bird's set.

    Appended rather than set: every photo of a species is a photo the quiz may
    show, and the first one stays the curated portrait the sticker and the album
    use. Replacing one is dropping it and adding another.
    """
    entry = bird(document, bird_id)
    entry[PHOTOS_KIND] = [*photos(entry), block]


def drop_photo(document: dict, bird_id: str, file: str) -> dict:
    """Remove one photo from a bird's set and return the block that went.

    Raises `LookupError` when the bird does not name that file, and `ValueError`
    when it is the only photo left: a species without a photo has nothing to
    show in a quiz tile, on a sticker or in the album, and both the licence gate
    and the Swift model refuse it.
    """
    entry = bird(document, bird_id)
    remaining, gone = [], []
    for photo in photos(entry):
        (gone if photo.get("file") == file else remaining).append(photo)

    if not gone:
        named = ", ".join(str(photo.get("file")) for photo in photos(entry))
        raise LookupError(f"'{bird_id}' has no photo '{file}' (has: {named})")
    if not remaining:
        raise ValueError(
            f"'{file}' is the only photo of '{bird_id}' — a species without one cannot be "
            "shown. Add the replacement first, then drop this one"
        )

    entry[PHOTOS_KIND] = remaining
    return gone[0]


def set_media(document: dict, bird_id: str, kind: str, block: dict) -> str | None:
    """Replace a bird's `call`. Returns the file it pointed at before.

    The caller uses that to delete the previous file: the manifest is the truth
    about the pack directory, and a photo nothing references any more would
    still be copied into the app bundle by tools/sync_bundled_packs.py.
    """
    if kind not in MEDIA_KINDS:
        raise ValueError(f"'{kind}' is not a medium (expected one of {', '.join(MEDIA_KINDS)})")

    entry = bird(document, bird_id)
    previous = entry.get(kind) or {}
    entry[kind] = block
    return previous.get("file")


def speech_block(file: str, sha256: str, text: str) -> dict:
    """A recorded sentence with its keys in the manifest's order, `SPEECH_KEYS`.

    `text` is what was actually said. It is what a re-render reads instead of
    making a human retype the sentence, and what a later test compares against
    the String Catalog so that a sentence edited in Xcode without a new
    recording fails the check rather than shipping a clip that says something
    else than the screen shows.
    """
    return {"file": file, "sha256": sha256, "text": text}


def voice_block(licence: str, attribution: str, source_url: str, retrieved: str) -> dict:
    """The voice of a manifest's clips, with its keys in `VOICE_KEYS` order."""
    return {
        "license": licence,
        "attribution": attribution,
        "sourceURL": source_url,
        "retrieved": retrieved,
    }


def set_speech(document: dict, bird_id: str | None, sentence: str, block: dict) -> str | None:
    """Replace one recorded sentence. Returns the file it pointed at before.

    `bird_id` names a bird's `speech`; `None` is the fixed set's `lines`, which
    is the same map one level higher up and without a species. The caller uses
    the returned name to delete the previous recording, exactly as `set_media`
    does — a clip nothing references any more would still be copied into the
    app bundle by tools/sync_bundled_packs.py.
    """
    # `or {}` rather than `setdefault`, and written back: a manifest may carry
    # `"speech": null` the way a bird carries `"call": null` — declared and
    # empty — and `setdefault` would hand that null straight on.
    holder = document if bird_id is None else bird(document, bird_id)
    kind = LINES_KIND if bird_id is None else SPEECH_KIND
    clips = holder.get(kind) or {}
    holder[kind] = clips

    previous = clips.get(sentence) or {}
    clips[sentence] = block
    return previous.get("file")


def set_voice(document: dict, block: dict) -> dict:
    """Record the voice this manifest's clips are spoken by. Returns the voice.

    One voice per manifest, so a second one that differs is a mistake rather
    than something to merge: thirty clips would otherwise carry the licence of
    the thirty-first. What counts as another voice is `VOICE_IDENTITY` — the
    date is not part of it, and is left as it was found so that re-rendering
    one sentence does not put a line in the diff that nobody made.

    Written after `title`, where the plan and the schema show it, rather than
    appended after the birds.
    """
    present = document.get("voice")
    if isinstance(present, dict):
        differing = [key for key in VOICE_IDENTITY if present.get(key) != block.get(key)]
        if differing:
            raise ValueError(
                f"'{document.get('id')}' is spoken by {present.get('attribution')!r} "
                f"({present.get('license')}), not by {block.get('attribution')!r} "
                f"({block.get('license')}): {', '.join(differing)} differ(s). One manifest "
                "carries one voice — re-produce every clip in it, or use the voice it has."
            )
        return present

    ordered: dict = {}
    for key, value in document.items():
        # A `voice` that is not an object is replaced rather than kept in
        # place; the licence gate would refuse it either way.
        if key == "voice":
            continue
        ordered[key] = value
        if key == "title":
            ordered["voice"] = block
    ordered.setdefault("voice", block)

    document.clear()
    document.update(ordered)
    return block


def media_files(document: dict) -> list[tuple[str, str]]:
    """Every medium the manifest declares, as (relative path, SHA-256).

    Photos, call and recorded sentences of every bird, in manifest order. What
    is not declared here is not uploaded — the bucket holds what the manifest
    promises, nothing that was left behind by an earlier curation round.

    Each file once: two sentence keys may name the same recording — a species
    whose name is a sentence of its own — and `Pack.declaredFiles` in
    `ZilpZalpData` fetches every file once, so uploading or counting it twice
    would make the download's size and its progress disagree. That twin drops
    the later mention of a shared file in sentence-key order rather than in
    this one, so a file named twice has to carry the same digest both times —
    `license_gate.py` checks every mention against the file on disk and is
    what makes sure of it.
    """
    files = []
    seen = set()

    def declare(media: object) -> None:
        if isinstance(media, dict) and media.get("file") and media["file"] not in seen:
            seen.add(media["file"])
            files.append((media["file"], str(media.get("sha256", ""))))

    for entry in document.get("birds") or []:
        for photo in photos(entry):
            declare(photo)
        for kind in MEDIA_KINDS:
            declare(entry.get(kind))

        # One level deeper, and through the same list: a downloaded pack whose
        # clips never reached the bucket is a pack that says nothing.
        speech = entry.get(SPEECH_KIND)
        if isinstance(speech, dict):
            for clip in speech.values():
                declare(clip)

    return files
