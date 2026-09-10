"""The command line of the curation tool.

Three kinds of medium, and a human between every step:

    photos candidates --pack deutschland [--species amsel …] [--limit 5]
    photos pick --pack deutschland --species amsel --observation 20490738 --photo 31623386
    photos frame --pack deutschland --species amsel --observation 20490738 --photo 31623386
    photos audit --pack deutschland [--species amsel …] [--add-verdicts -]
    photos drop --pack deutschland --species amsel --file photos/amsel-2.heic
    calls candidates --pack deutschland [--species amsel …] [--limit 5] [--type song]
    calls pick --pack deutschland --species amsel --recording XC965144 [--start 12.5]
    speech voices --provider elevenlabs
    speech render --provider fake --pack deutschland [--species amsel …] [--sentence …]
    speech render --provider elevenlabs --voice … --pack deutschland [--max-chars 30000]
    speech render --provider fake --set fixed --sentence roundEnd.title
    speech import --pack deutschland --species amsel --sentence … --file take3.wav
                  --attribution "Stimme: …"
    upload --pack deutschland [--dry-run]

`candidates` asks the source and lists what may be used; it never chooses.
`pick` fetches the one medium a human named, crops or trims it, writes the
manifest entry and regenerates the derived files — a photo is *added* to the
species' set (#194), and `drop` takes one out again. `frame` is `pick` with the
square computed from where the bird actually is instead of from the middle of
the photo, and `audit` exports the tiles a pack ships so that they can be
judged and takes the verdicts back. `speech` produces the sentences the app
says out loud — `render` asks a provider, `import` takes a recording somebody
made — and records them the same way. `upload` puts the pack in the bucket
and, last, the index of the packs that can be downloaded from there.

Credentials come from the environment, where `infisical run --env=dev --path=/
--` puts them: `upload` needs the bucket keys, and both `calls` steps need
`XENO_CANTO_API_KEY`, because the xeno-canto API refuses every request without
it. The two `photos` steps need nothing and run on any machine, and so do
`speech import` and every provider that speaks offline.
"""

from __future__ import annotations

import argparse
import collections
import dataclasses
import datetime
import json
import subprocess
import sys
import tempfile
from pathlib import Path

import httpx
from botocore.exceptions import BotoCoreError, ClientError

from fetch_media import (
    audio,
    framing,
    images,
    inaturalist,
    index,
    keys,
    manifest,
    s3,
    speech,
    xenocanto,
)
from fetch_media.speech import clips, sentences

# Candidate lists are working material for a human, not a build artefact, and
# `data/packs/` is off limits for them: the licence gate reads every *.json
# below it as a manifest.
DEFAULT_OUT = Path(tempfile.gettempdir()) / "zilpzalp-fetch-media"

# Run in the order `mise run check` runs them, so a manifest change leaves the
# repository exactly as CI expects to find it.
DERIVED_TOOLS = ("sync_bundled_packs.py", "generate_credits.py")

# Where `frame` and `audit` put the previews somebody has to look at. Below
# DerivedData/, which is ignored by the repository: they are working material
# for one curation round, like the candidate lists, and none of them is an
# asset.
DERIVED_DATA = manifest.REPO_ROOT / "DerivedData"
AUDIT_DIR = DERIVED_DATA / "audit"
FRAME_PREVIEW_DIR = DERIVED_DATA / "frame-preview"

# How much one `speech render` may cost at a paid provider's meter, in
# characters. Everything the app says — 130 species names plus the fixed
# sentences — is a few thousand, so this is a cap on a mistake rather than on a
# plan: a `--species` that silently matched a whole pack, or a run started
# twice. `--max-chars` raises it where a bigger run is meant.
MAX_CHARS = 30000

# What the audit writes and reads beside the previews.
TILES_FILE = "tiles.json"
VERDICTS_FILE = "verdicts.json"

# The three questions a tile is judged by, in the order the table shows them.
# `fills_frame` is "the bird covers roughly a third of the frame or more".
VERDICT_FLAGS = ("bird_visible", "fills_frame", "head_inside")

# Below this fraction of the tile's side the bird is a speck. The crop cannot
# fix that — another photo can (#194) — so `frame` says so instead of
# pretending otherwise.
FAR_AWAY = 1 / 3


def escape_data(message: str) -> str:
    """Escape data for a GitHub workflow command — % first, then the line breaks."""
    return message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def regenerate_derived() -> None:
    """Bring the bundled pack copy and the credits back in step.

    Both tools heal what they find stale and report the healing as exit code 1
    with an `::error::` line, which is what makes them drift checks in CI. Here
    the drift is the change that was just made, so a first run that reports
    something is swallowed — its "the credits were stale" would read as a
    failure — and the tool is run again to judge the result it just produced.
    A first run that is already content has nothing to heal and nothing to
    repeat; it simply says so.
    """
    for script in DERIVED_TOOLS:
        command = [sys.executable, str(manifest.REPO_ROOT / "tools" / script)]
        healing = subprocess.run(command, check=False, capture_output=True, text=True)
        if healing.returncode == 0:
            print(healing.stdout, end="")
            continue

        if subprocess.run(command, check=False).returncode != 0:
            raise RuntimeError(f"{script} still reports a problem — see its output above")


def warn_if_limited(label: str, clip: audio.Clip) -> None:
    """Say when the peak ceiling stopped a clip from reaching the target.

    The one case where two clips still sound unequally loud after the
    normalisation (#148), and the only answer is a different recording — so it
    is said out loud rather than hidden in a number nobody compares.
    """
    if not clip.limited:
        return

    message = (
        f"{label}: the peak ceiling held this clip at {clip.loudness:.1f} dBFS instead of "
        f"{audio.TARGET:g}. It will sound quieter than the rest — another recording is the "
        "fix, not another gain."
    )
    print(f"::warning::{escape_data(message)}")


def remove_orphan(directory: Path, label: str, previous: str | None, relative: str = "") -> None:
    """Delete the file the manifest no longer names.

    `relative` is what took its place, so that re-recording a medium under the
    same name deletes nothing. It stays empty where nothing replaced the file —
    `photos drop`, which takes a photo out of a species' set.

    The manifest is the truth about the directory beside it, and a medium
    nothing references any more would still be copied into the app bundle by
    sync_bundled_packs.py. Only inside that directory: a manifest that points
    at `../../something` is a broken manifest, not a licence to unlink.
    """
    if not previous or previous == relative:
        return

    orphan = directory / previous
    if orphan.is_file() and orphan.resolve().is_relative_to(directory.resolve()):
        orphan.unlink()
        print(f"{label}: removed the previous {previous}")


def store(directory: Path, relative: str, data: bytes) -> str:
    """Write one medium beside its manifest, and return the hash it recorded.

    The manifest names the file by that hash, so the two are produced in one
    place: a photo, a call and a recorded sentence are stored identically and
    differ only in what is then written about them.
    """
    destination = directory / relative
    if not destination.resolve().is_relative_to(directory.resolve()):
        raise ValueError(f"'{relative}' would be written outside {directory}")

    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)
    return manifest.sha256_of(destination)


def record_medium(
    pack_id: str,
    document: dict,
    species: str,
    kind: str,
    relative: str,
    data: bytes,
    licence: str,
    attribution: str,
    source_url: str,
) -> None:
    """Store one medium beside the manifest and record it there."""
    pack = manifest.pack_dir(pack_id)
    digest = store(pack, relative, data)
    previous = manifest.set_media(
        document,
        species,
        kind,
        manifest.media_block(
            file=relative,
            sha256=digest,
            licence=licence,
            attribution=attribution,
            source_url=source_url,
            retrieved=datetime.date.today().isoformat(),
        ),
    )
    manifest.save(manifest.manifest_path(pack_id), document)
    remove_orphan(pack, species, previous, relative)

    print(f"{species}: {relative}  {len(data)} bytes  sha256 {digest}")


def voice_block(voice: speech.Voice) -> dict:
    """A provider's or a recordist's voice as the manifest carries it, dated today."""
    return manifest.voice_block(
        licence=voice.license,
        attribution=voice.attribution,
        source_url=voice.source_url,
        retrieved=datetime.date.today().isoformat(),
    )


def record_clip(
    target: clips.Target,
    document: dict,
    sentence: str,
    clip: audio.Clip,
    text: str,
    voice: speech.Voice,
) -> None:
    """Store one recorded sentence beside its manifest and record it there.

    The voice goes in first, and it is the step that can refuse: one manifest
    carries one voice for every clip in it, so a sentence produced by somebody
    else has to be caught before a file is written rather than after thirty
    clips have been labelled with the wrong licence.
    """
    recorded = manifest.set_voice(document, voice_block(voice))

    relative = target.file(sentence)
    digest = store(target.directory, relative, clip.data)
    previous = manifest.set_speech(
        document,
        target.bird_id,
        sentence,
        manifest.speech_block(file=relative, sha256=digest, text=text),
    )
    manifest.save(target.path, document)
    remove_orphan(target.directory, target.label, previous, relative)

    print(f'{target.label}: {sentence}  "{text}"')
    print(
        f"{target.label}: {relative}  {len(clip.data)} bytes  {clip.seconds:.1f} s  "
        f"{clip.loudness:.1f} dBFS  sha256 {digest}"
    )
    print(f"{target.label}: voice {recorded['attribution']} ({recorded['license']})")
    warn_if_limited(f"{target.label} / {sentence}", clip)


def selected_birds(document: dict, species: list[str] | None) -> list[dict]:
    """The birds to work on: the named ones, or the whole pack."""
    if not species:
        return list(document.get("birds") or [])
    return [manifest.bird(document, bird_id) for bird_id in species]


def print_columns(header: list[str], rows: list[list[str]]) -> None:
    """Print a table whose last column is a URL.

    Every column but the last is padded to its widest cell; the last one is
    left alone so the URL stays clickable in a terminal.
    """
    widths = [max(len(row[column]) for row in [header, *rows]) for column in range(len(header) - 1)]

    for row in [header, *rows]:
        cells = [cell.ljust(width) for cell, width in zip(row, widths, strict=False)]
        print("  ".join([*cells, row[-1]]).rstrip())


def by_observation(candidates: list[inaturalist.Candidate]) -> dict[int, list[inaturalist.Candidate]]:
    """Group the candidates by observation, keeping the API's order."""
    grouped: dict[int, list[inaturalist.Candidate]] = {}
    for candidate in candidates:
        grouped.setdefault(candidate.observation_id, []).append(candidate)
    return grouped


def print_table(grouped: dict[int, list[inaturalist.Candidate]]) -> None:
    """Print the candidates as a table a human can read in a terminal.

    One line per observation rather than per photo: a series of a dozen shots
    of the same bird from the same minute is one decision, not twelve, and the
    observation page shows them all anyway. The candidate file keeps every
    photo id, so picking the third shot of a series needs no second query.
    """
    if not grouped:
        print("No usable photo found.")
        return

    rows = []
    for group in grouped.values():
        candidate = group[0]
        side = candidate.square_side
        size = "unknown" if side is None else f"{candidate.width}×{candidate.height}"
        if side is not None and side < images.SIDE:
            size += " !"
        further = f" +{len(group) - 1}" if len(group) > 1 else ""
        rows.append(
            [
                candidate.bird_id,
                str(candidate.observation_id),
                f"{candidate.photo_id}{further}",
                candidate.license,
                size,
                candidate.photographer,
                candidate.observation_url,
            ]
        )

    header = ["Bird", "Observation", "Photo", "Licence", "Original", "Photographer", "URL"]
    print_columns(header, rows)

    print("\n+n  further usable photos of the same observation, listed in the candidate file")
    if any(" !" in row[4] for row in rows):
        print(f"!   smaller than {images.SIDE} px on the short side — 'pick' refuses to upscale it")


def command_candidates(args: argparse.Namespace) -> int:
    """List the freely licensed photos of a pack's species."""
    document = manifest.load(manifest.manifest_path(args.pack))
    birds = selected_birds(document, args.species)

    candidates: list[inaturalist.Candidate] = []
    with inaturalist.Client() as client:
        for bird in birds:
            observations = client.observations(bird["taxonID"], args.limit)
            found = inaturalist.photo_candidates(bird["id"], bird["taxonID"], observations)
            if not found:
                message = f"{bird['id']}: no freely licensed photo found"
                print(f"::warning::{escape_data(message)}")
            candidates += found

    args.out.mkdir(parents=True, exist_ok=True)
    destination = args.out / f"{args.pack}-photo-candidates.json"
    manifest.save(
        destination,
        {
            "pack": args.pack,
            "retrieved": datetime.date.today().isoformat(),
            "candidates": [dataclasses.asdict(candidate) for candidate in candidates],
        },
    )

    grouped = by_observation(candidates)
    print_table(grouped)
    print(
        f"\n{len(candidates)} usable photo(s) in {len(grouped)} observation(s) "
        f"for {len(birds)} species → {destination}"
    )
    print("Look at the photos, then run 'photos pick' with the observation and photo id.")
    return 0


def fetch_photo(
    client: inaturalist.Client, bird: dict, observation_id: int, photo_id: int
) -> tuple[dict, dict, bytes]:
    """The observation, the photo and the original's bytes, both licences checked.

    Shared by `pick` and `frame`: framing has to see the pixels before it can
    name a crop, and asking a server that wants one request per second for the
    same original twice would be rude.
    """
    observation = client.observation(observation_id)
    if not inaturalist.taxon_matches(observation, bird["taxonID"]):
        taxon = observation.get("taxon") or {}
        raise ValueError(
            f"observation {observation_id} shows {taxon.get('name')} "
            f"(taxon {taxon.get('id')}), not {bird['scientificName']} (taxon {bird['taxonID']})"
        )

    photo = inaturalist.find_photo(observation, photo_id)
    original = inaturalist.original_url(photo["url"])
    print(f"{bird['id']}: downloading {original}")
    return observation, photo, client.download(original)


def record_photo(
    pack_id: str,
    document: dict,
    species: str,
    observation: dict,
    photo: dict,
    data: bytes,
    crop: images.Box | None,
) -> None:
    """Crop the original to a tile, add it to the species' set, and regenerate.

    **Added, never overwritten** (#194): the photo lands beside the ones the
    species already has, under the next free name — `photos/amsel.heic`, then
    `photos/amsel-2.heic`. Nothing is orphaned, because nothing was replaced; a
    photo that should go is dropped with `photos drop`, which is the one step
    that unlinks a file.
    """
    pack = manifest.pack_dir(pack_id)
    entry = manifest.bird(document, species)
    relative = manifest.next_photo_file(entry, species, images.SUFFIX)

    tile = images.square_photo(data, crop)
    digest = store(pack, relative, tile)
    manifest.add_photo(
        document,
        species,
        manifest.media_block(
            file=relative,
            sha256=digest,
            licence=inaturalist.licence_id(photo["license_code"]),
            attribution=inaturalist.photographer(observation),
            source_url=inaturalist.OBSERVATION_URL.format(observation["id"]),
            retrieved=datetime.date.today().isoformat(),
        ),
    )
    manifest.save(manifest.manifest_path(pack_id), document)
    print(f"{species}: {relative}  {len(tile)} bytes  sha256 {digest}")
    print(f"{species}: {len(manifest.photos(entry))} photo(s) now")

    regenerate_derived()
    print("\nLook at the photo before you commit it — nothing else has seen it yet.")


def command_drop(args: argparse.Namespace) -> int:
    """Remove one photo of a species from the manifest and from the pack.

    The file goes only when nothing else names it — two species may share a
    photo, and the manifest is what says whether one is still in use.
    """
    document = manifest.load(manifest.manifest_path(args.pack))
    gone = manifest.drop_photo(document, args.species, args.file)
    manifest.save(manifest.manifest_path(args.pack), document)

    if args.file in {file for file, _ in manifest.media_files(document)}:
        print(f"{args.species}: {args.file} is still named elsewhere and stays on disk")
    else:
        remove_orphan(manifest.pack_dir(args.pack), args.species, args.file)

    print(f"{args.species}: dropped {args.file} ({gone.get('attribution')})")
    regenerate_derived()
    print(
        "\nThe pack no longer names the photo. It stays in the bucket until somebody "
        "prunes it, and a device that has it keeps it until the pack is fetched again."
    )
    return 0


def command_pick(args: argparse.Namespace) -> int:
    """Fetch, crop and record the one photo a human chose."""
    document = manifest.load(manifest.manifest_path(args.pack))
    bird = manifest.bird(document, args.species)

    with inaturalist.Client() as client:
        observation, photo, data = fetch_photo(client, bird, args.observation, args.photo)

    record_photo(args.pack, document, args.species, observation, photo, data, args.crop)
    return 0


def command_frame(args: argparse.Namespace) -> int:
    """Find the bird in the original, square the crop around it, and pick it.

    Two previews are written for every run, because a crop nobody looked at is
    a crop nobody checked: the whole photo, which is what a vision model is
    asked about when saliency locks onto the wrong thing, and the tile itself.
    """
    document = manifest.load(manifest.manifest_path(args.pack))
    bird = manifest.bird(document, args.species)

    with inaturalist.Client() as client:
        observation, photo, data = fetch_photo(client, bird, args.observation, args.photo)

    image = images.oriented(data)
    args.preview.mkdir(parents=True, exist_ok=True)
    whole = args.preview / f"{args.pack}-{args.species}-source.png"
    whole.write_bytes(images.preview_png(image))
    print(f"{args.species}: {image.width}×{image.height} px → {whole}")

    # Before Vision rather than after: `square_photo` would refuse this photo
    # at the end of the run, and the answer is another candidate either way.
    if min(image.size) < images.SIDE:
        raise ValueError(
            f"the original is {image.width}×{image.height} px and no {images.SIDE} px square "
            "fits in it — pick a candidate with a larger original"
        )

    rect, found_by = args.box, "--box"
    if rect is None:
        rect, found_by = framing.saliency_rect(image), "Vision saliency"
    if rect is None:
        raise framing.FramingError(
            f"Vision found nothing salient — look at {whole} and pass the box yourself "
            "with --box x0,y0,x1,y1, normalised 0–1 with the origin at the top left"
        )

    crop, fill = framing.square_crop(rect, image.width, image.height, args.margin)
    x, y, side, _ = crop
    print(
        f"{args.species}: {found_by} says the bird is at "
        f"{rect.x0:.3f},{rect.y0:.3f},{rect.x1:.3f},{rect.y1:.3f} → --crop {x},{y},{side},{side}"
    )

    tile = args.preview / f"{args.pack}-{args.species}-tile.png"
    tile.write_bytes(images.preview_png(image.crop((x, y, x + side, y + side))))
    print(f"{args.species}: the bird's longer side covers {fill:.0%} of the tile → {tile}")
    if fill < FAR_AWAY:
        message = (
            f"{args.species}: the bird fills {fill:.0%} of the tile, less than a third. "
            "The crop is right and the photo is too distant — that is a case for another "
            "photo, not another crop."
        )
        print(f"::warning::{escape_data(message)}")

    if args.dry_run:
        print("\nDry run: nothing was written. Pass the crop above to 'photos pick', or "
              "run this again without --dry-run.")
        return 0

    record_photo(args.pack, document, args.species, observation, photo, data, crop)
    return 0


def audit_tiles(pack_id: str, birds: list[dict], directory: Path) -> list[dict]:
    """Export every named tile as a preview PNG and describe it in `tiles.json`.

    The tiles ship as 1024 px HEIC, which is neither small enough to hand to a
    model nor a format every reader opens. The preview is what gets judged, and
    `tiles.json` is what says which species and which photographer a verdict
    belongs to.

    One tile per photo, not per species (#194): a bird with three photos ships
    three tiles, and each of them is right or wrong on its own. The photo's path
    in the manifest is what a verdict names, and the preview is called after it.
    """
    pack = manifest.pack_dir(pack_id)
    directory.mkdir(parents=True, exist_ok=True)

    tiles = []
    for bird in birds:
        photos = [photo for photo in manifest.photos(bird) if photo.get("file")]
        if not photos:
            message = f"{bird['id']}: has no photo to audit"
            print(f"::warning::{escape_data(message)}")
            continue

        for photo in photos:
            preview = f"{Path(photo['file']).stem}.png"
            original = images.oriented((pack / photo["file"]).read_bytes())
            (directory / preview).write_bytes(images.preview_png(original))
            tiles.append(
                {
                    "photo": photo["file"],
                    "species": bird["id"],
                    "name": bird.get("name"),
                    "file": preview,
                    "attribution": photo.get("attribution"),
                    "license": photo.get("license"),
                    "sourceURL": photo.get("sourceURL"),
                }
            )

    manifest.save(
        directory / TILES_FILE,
        {
            "pack": pack_id,
            "generated": datetime.date.today().isoformat(),
            "tiles": tiles,
        },
    )
    return tiles


def checked_verdict(entry: object, known: set[str]) -> dict:
    """One judged tile, or a `ValueError` naming what is wrong with the answer.

    A model writes these, so nothing is trusted: an answer about a photo this
    pack does not ship, or a flag that is not a boolean, is a mistake that
    would otherwise sit in `verdicts.json` and be counted as a verdict.
    """
    if not isinstance(entry, dict):
        raise ValueError(f"a verdict has to be an object, got {entry!r}")

    # `isinstance` first: `known` is a set, and a verdict whose photo is a
    # list would otherwise raise an unhashable TypeError past every handler
    # instead of the sentence that says what is wrong with it.
    photo = entry.get("photo")
    if not isinstance(photo, str) or photo not in known:
        raise ValueError(f"'{photo}' is not a photo this pack ships")

    verdict = {"photo": photo}
    for flag in VERDICT_FLAGS:
        if not isinstance(entry.get(flag), bool):
            raise ValueError(f"{photo}: '{flag}' has to be true or false, got {entry.get(flag)!r}")
        verdict[flag] = entry[flag]

    verdict["reason"] = str(entry.get("reason") or "").strip()
    return verdict


def read_verdicts(directory: Path) -> dict[str, dict]:
    """The verdicts written so far, by photo."""
    path = directory / VERDICTS_FILE
    if not path.is_file():
        return {}

    document = manifest.load(path)
    return {entry["photo"]: entry for entry in document.get("verdicts") or []}


def merge_verdicts(
    directory: Path, pack_id: str, incoming: object, known: set[str]
) -> dict[str, dict]:
    """Add a batch of verdicts to `verdicts.json` and return all of them, by photo.

    The later answer wins.

    Merged rather than appended, and validated before anything is written: the
    judging happens in batches, one batch is one call, and a run that stops
    halfway has to leave the batches before it on disk.
    """
    if not isinstance(incoming, list):
        raise ValueError("the verdicts have to be a JSON array of objects")

    verdicts = read_verdicts(directory)
    for entry in incoming:
        checked = checked_verdict(entry, known)
        verdicts[checked["photo"]] = checked

    directory.mkdir(parents=True, exist_ok=True)
    manifest.save(
        directory / VERDICTS_FILE,
        {
            "pack": pack_id,
            "verdicts": [verdicts[photo] for photo in sorted(verdicts)],
        },
    )
    return verdicts


def print_audit(tiles: list[dict], verdicts: dict[str, dict]) -> None:
    """The judged tiles as a table, and what a curator has to do about them."""
    rows = []
    for tile in tiles:
        verdict = verdicts.get(tile["photo"])
        flags = ["?", "?", "?"] if verdict is None else [
            "yes" if verdict[flag] else "NO" for flag in VERDICT_FLAGS
        ]
        rows.append(
            [tile["species"], tile["photo"], *flags, "" if verdict is None else verdict["reason"]]
        )

    print_columns(["Bird", "Photo", "Bird visible", "Fills frame", "Head inside", "Reason"], rows)

    def failing(flag: str) -> list[str]:
        return [
            tile["photo"]
            for tile in tiles
            if tile["photo"] in verdicts and not verdicts[tile["photo"]][flag]
        ]

    judged = [tile for tile in tiles if tile["photo"] in verdicts]
    print(f"\n{len(tiles)} tile(s), {len(judged)} judged")

    for flag, headline, remedy in (
        ("bird_visible", "no bird visible", "re-frame or re-pick these now"),
        ("head_inside", "head cut off", "re-frame or re-pick these now"),
        ("fills_frame", "too far away", "drop these and pick a closer photo"),
    ):
        birds = failing(flag)
        print(f"{headline}: {len(birds)}" + (f" — {', '.join(birds)} ({remedy})" if birds else ""))


def command_audit(args: argparse.Namespace) -> int:
    """Export a pack's tiles for judging, and merge the verdicts back in.

    The judging itself is not in here. It is a vision model looking at the
    previews — Haiku, in batches of at most ten, two calls at a time — and it
    writes its answers back through `--add-verdicts`, which is why this
    subcommand needs no credential at all. See docs/medien-und-lizenzen.md.
    """
    document = manifest.load(manifest.manifest_path(args.pack))
    birds = selected_birds(document, args.species)
    directory = AUDIT_DIR / args.pack

    tiles = audit_tiles(args.pack, birds, directory)
    print(f"{len(tiles)} tile(s) → {directory}/\n")

    if args.add_verdicts:
        text = sys.stdin.read() if args.add_verdicts == "-" else Path(args.add_verdicts).read_text()
        # Against the whole pack, not against `tiles`: a batch may name a
        # photo this run did not export, and that is not a mistake.
        known = {
            photo["file"]
            for bird in document.get("birds") or []
            for photo in manifest.photos(bird)
            if photo.get("file")
        }
        incoming = json.loads(text)
        verdicts = merge_verdicts(directory, args.pack, incoming, known)
        print(f"{len(incoming)} verdict(s) merged into {directory / VERDICTS_FILE}\n")
    else:
        verdicts = read_verdicts(directory)

    print_audit(tiles, verdicts)
    return 0


def print_call_table(candidates: list[xenocanto.Candidate]) -> None:
    """Print the recordings as a table a human can read in a terminal.

    One line per recording, unlike the photo table: a series of shots from one
    observation is a single decision, but every recording is its own — another
    bird, another distance, another background.
    """
    if not candidates:
        print("No recording found.")
        return

    rows = []
    for entry in candidates:
        licence = xenocanto.licence_label(entry.license_url)
        rows.append(
            [
                entry.bird_id,
                f"XC{entry.recording_id}",
                entry.quality,
                (entry.type or "unlabelled") + (" *" if entry.skipped else ""),
                entry.length,
                licence if entry.usable else f"{licence} !",
                entry.recordist,
                entry.recording_url,
            ]
        )

    print_columns(["Bird", "Recording", "Q", "Type", "Length", "Licence", "Recordist", "URL"], rows)

    if not all(entry.usable for entry in candidates):
        print(f"\n!   licence outside {xenocanto.PERMITTED}")
        print("    — 'calls pick' refuses it, and the recording cannot ship")
    if any(entry.skipped for entry in candidates):
        print("\n*   a sound the game normally hides; --type asked for it by name")


def command_call_candidates(args: argparse.Namespace) -> int:
    """List the freely licensed recordings of a pack's species."""
    document = manifest.load(manifest.manifest_path(args.pack))
    birds = selected_birds(document, args.species)

    every: list[xenocanto.Candidate] = []
    listed: list[xenocanto.Candidate] = []
    summaries: list[str] = []
    held_back = 0

    with xenocanto.Client(keys.api_key(keys.XENO_CANTO)) as client:
        for bird in birds:
            records = client.recordings(bird["scientificName"])
            found = xenocanto.call_candidates(bird["id"], records, args.type)
            usable = [entry for entry in found if entry.usable]
            if not usable:
                message = f"{bird['id']}: no freely licensed recording found"
                print(f"::warning::{escape_data(message)}")

            quality = collections.Counter(entry.quality for entry in usable)
            hidden = len(records) - len(found)
            held_back += hidden
            summaries.append(
                f"{bird['id']:<16}{len(usable):>3} usable "
                f"({quality['A']} in A, {quality['B']} in B), "
                f"{len(found) - len(usable)} unusable"
                + (f", {hidden} of another type" if hidden else "")
            )
            every += found
            listed += found[: args.limit]

        if client.truncated:
            message = (
                f"{len(client.truncated)} search(es) had more than one page of results; "
                "the counts below are a floor, not a total"
            )
            print(f"::warning::{escape_data(message)}")

    args.out.mkdir(parents=True, exist_ok=True)
    destination = args.out / f"{args.pack}-call-candidates.json"
    manifest.save(
        destination,
        {
            "pack": args.pack,
            "retrieved": datetime.date.today().isoformat(),
            "candidates": [dataclasses.asdict(entry) for entry in every],
        },
    )

    print_call_table(listed)
    print()
    for summary in summaries:
        print(summary)
    if held_back:
        print("\nA sound the game cannot use, or not the --type asked for. --type shows it.")
    print(
        f"\n{len(every)} recording(s) for {len(birds)} species, "
        f"{len(listed)} listed → {destination}"
    )
    print("Listen on the pages above, then run 'calls pick' with the XC number.")
    return 0


def command_call_pick(args: argparse.Namespace) -> int:
    """Fetch, trim and record the one call a human chose."""
    document = manifest.load(manifest.manifest_path(args.pack))
    bird = manifest.bird(document, args.species)

    with xenocanto.Client(keys.api_key(keys.XENO_CANTO)) as client:
        record = client.recording(args.recording)

        found = xenocanto.binomial(record)
        if found.casefold() != str(bird["scientificName"]).casefold():
            raise ValueError(
                f"XC{args.recording} is filed under {found}, not {bird['scientificName']}"
            )

        licence = xenocanto.licence_id(record.get("lic"))
        if licence is None:
            raise xenocanto.LicenceError(
                f"XC{args.recording} is under {xenocanto.licence_label(record.get('lic'))}, "
                f"which is not one of {xenocanto.PERMITTED}"
            )

        name = record.get("file-name") or ""
        print(
            f"{args.species}: downloading {name} "
            f"({record.get('length')}, quality {record.get('q')}, {record.get('type')})"
        )
        clip = audio.trim(client.download(record["file"]), name, args.start, args.duration)

    print(f"{args.species}: {clip.seconds:.1f} s at {clip.loudness:.1f} dBFS")
    warn_if_limited(args.species, clip)
    record_medium(
        args.pack,
        document,
        args.species,
        "call",
        f"audio/{args.species}{audio.EXTENSION}",
        clip.data,
        licence=licence,
        attribution=xenocanto.attribution(record),
        source_url=xenocanto.RECORDING_URL.format(args.recording),
    )
    regenerate_derived()
    print("\nListen to the file before you commit it — nothing else has heard it yet.")
    return 0


def speech_work(
    pack: str | None,
    fixed: str | None,
    species: list[str] | None,
    chosen: list[str] | None,
) -> tuple[dict, list[tuple[clips.Target, str, str]]]:
    """The manifest to write, and every (target, sentence, German text) in it.

    Resolved before a single clip is produced, so that a misspelt sentence key
    or a species the pack does not have costs nothing — with a paid provider
    that is the difference between a typo and an invoice.
    """
    if fixed:
        if species:
            raise ValueError("--species belongs to a pack; the fixed sentences have no species")
        if not chosen:
            # No default list on purpose: which sentences the fixed set holds
            # still depends on decisions 4 and 7 of the plan and on #146's key,
            # and rendering "every string in the catalogue" is not a default
            # anybody wants.
            raise ValueError("--set fixed needs --sentence: name the sentences to produce")

        document = manifest.load(manifest.speech_manifest_path())
        target = clips.for_fixed_set()
        return document, [(target, key, sentences.fixed_text(key)) for key in chosen]

    document = manifest.load(manifest.manifest_path(str(pack)))
    keys_to_do = chosen or list(sentences.SPECIES_SENTENCES)
    work = []
    for bird in selected_birds(document, species):
        target = clips.for_species(str(pack), str(bird["id"]))
        work += [(target, key, sentences.species_text(bird, key)) for key in keys_to_do]
    return document, work


def command_speech_voices(args: argparse.Namespace) -> int:
    """List the voices a provider offers, so that `--voice` can name one."""
    provider = speech.provider(args.provider)
    offered = provider.voices()
    if not offered:
        print(f"'{provider.name}' offers no choice of voice")
        return 0

    for option in offered:
        print(f"{option.id}  {option.name}  {option.description}".rstrip())
    print(f"\n{len(offered)} voice(s) — name one with --voice, by id or by name")
    return 0


def within_budget(work: list[tuple[clips.Target, str, str]], most: int) -> None:
    """Say what this run will cost at the meter, and refuse a run that is too big.

    A paid provider bills characters, so the count is the price. It is printed
    on every run and checked before anything is spoken — a `--species` typo
    that dealt a whole pack instead of one bird should cost a message, not an
    invoice.
    """
    characters = sum(len(text) for _, _, text in work)
    print(f"{characters} character(s) to render (limit {most})")
    if characters > most:
        raise ValueError(
            f"{characters} characters is more than --max-chars {most}: "
            "render fewer sentences, or raise the limit deliberately."
        )


def command_speech_render(args: argparse.Namespace) -> int:
    """Ask a provider for every sentence named, and record what comes back."""
    provider = speech.provider(args.provider)
    document, work = speech_work(args.pack, args.set, args.species, args.sentence)
    within_budget(work, args.max_chars)

    # Before the first sentence is spoken, not after: a provider that is not
    # the one this manifest was produced with is refused here, where it has
    # cost nothing. `record_clip` asks again per clip and finds it agreed.
    voice = provider.voice(args.voice)
    manifest.set_voice(document, voice_block(voice))

    print(f"{len(work)} clip(s) through '{provider.name}'")
    for target, sentence, text in work:
        spoken = provider.render(text, args.voice)
        record_clip(
            target,
            document,
            sentence,
            audio.trim(spoken, speech.RENDERED_FILE, duration=None),
            text,
            voice,
        )

    regenerate_derived()
    print("\nListen to every clip before you commit it — nothing else has heard it yet.")
    return 0


def command_speech_import(args: argparse.Namespace) -> int:
    """Record one take somebody made, through the same encoder as a call."""
    if args.pack and not args.species:
        raise ValueError("--species names the bird this take is for")

    document, work = speech_work(
        args.pack, args.set, [args.species] if args.species else None, [args.sentence]
    )
    target, sentence, text = work[0]

    print(f'{target.label}: importing {args.file.name} as "{text}"')
    record_clip(
        target,
        document,
        sentence,
        audio.trim(args.file.read_bytes(), args.file.name, duration=None),
        text,
        speech.imported_voice(args.attribution),
    )

    regenerate_derived()
    print("\nListen to the clip before you commit it — nothing else has heard it yet.")
    return 0


def command_upload(args: argparse.Namespace) -> int:
    """Put the pack's media and its manifest into the bucket, then the index."""
    uploads = s3.plan(args.pack, manifest.pack_dir(args.pack))

    try:
        client, bucket = s3.client_from_env()
    except RuntimeError as error:
        if not args.dry_run:
            raise
        # A dry run has to work on a machine without credentials (#15): it then
        # shows what would be uploaded, only without asking the bucket what it
        # already holds — and the index holds this pack alone, because nothing
        # can be asked about the others either.
        print(f"::notice::{escape_data(f'{error} Listing the plan unchecked.')}")
        client, bucket = None, None

    def present(key: str) -> bool:
        """Whether the bucket holds that object — as this tool would have put it.

        An object without the `sha256` metadata reads as absent, which is the
        safe direction: it would not have come from here.
        """
        return client is not None and s3.remote_sha256(client, bucket, key) is not None

    # Appended, not uploaded separately: the index is the last object of the
    # run and so can never name one that is still missing. It is staged outside
    # the repository, because the licence gate and the credits generator read
    # every *.json below data/packs/ as a manifest.
    with tempfile.TemporaryDirectory() as scratch:
        catalogue = index.build(uploading=args.pack, in_bucket=present)
        uploads.append(index.staged(catalogue, Path(scratch)))

        if client is None:
            for upload in uploads:
                print(s3.report_line("unchecked", upload))
            return 0

        for line in s3.sync(client, bucket, uploads, dry_run=args.dry_run):
            print(line)

    print(f"\n{len(uploads)} object(s) in the media bucket: packs/{args.pack}/ and {index.KEY}")
    return 0


def add_speech_place(parser: argparse.ArgumentParser) -> None:
    """Which manifest a `speech` step works on — a pack, or the fixed set.

    Exclusive and required: a species sentence belongs to a pack, and „Super
    gemacht!" belongs to no pack at all (data/speech/, section 3.1 of the plan).
    """
    place = parser.add_mutually_exclusive_group(required=True)
    place.add_argument("--pack", help="pack id, for instance 'deutschland' — its species sentences")
    place.add_argument(
        "--set",
        choices=("fixed",),
        help="the sentences that belong to no pack, in data/speech/",
    )


def build_parser() -> argparse.ArgumentParser:
    """The whole command line.

    Finding a medium is specific to its source, so `candidates` and `pick` sit
    under `photos` and under `calls`. Uploading is not: `upload` puts the whole
    pack in the bucket, photos and recordings alike, and therefore stays at the
    top level where a second medium needs no second copy of it.
    """
    parser = argparse.ArgumentParser(prog="fetch_media", description=__doc__.splitlines()[0])
    commands = parser.add_subparsers(dest="command", required=True)
    photos = commands.add_parser("photos", help="photos from iNaturalist").add_subparsers(
        dest="step", required=True
    )

    candidates = photos.add_parser("candidates", help="list freely licensed photos for a pack")
    candidates.add_argument("--pack", required=True, help="pack id, for instance 'deutschland'")
    candidates.add_argument("--species", nargs="+", help="bird ids; default: every bird in the pack")
    candidates.add_argument(
        "--limit", type=int, default=5, help="observations to ask for per species (default: 5)"
    )
    candidates.add_argument(
        "--out",
        type=Path,
        default=DEFAULT_OUT,
        help=f"where to write the candidate list (default: {DEFAULT_OUT})",
    )
    candidates.set_defaults(run=command_candidates)

    pick = photos.add_parser("pick", help="fetch and record one photo a human chose")
    pick.add_argument("--pack", required=True)
    pick.add_argument("--species", required=True, help="bird id, for instance 'amsel'")
    pick.add_argument("--observation", required=True, type=int, help="iNaturalist observation id")
    pick.add_argument("--photo", required=True, type=int, help="iNaturalist photo id")
    pick.add_argument(
        "--crop",
        type=images.parse_crop,
        # None is what `center` parses to, so the default needs no second path.
        default=None,
        help="'center' (default) or 'x,y,w,h' in pixels of the original",
    )
    pick.set_defaults(run=command_pick)

    frame = photos.add_parser("frame", help="pick a photo with the square computed around the bird")
    frame.add_argument("--pack", required=True)
    frame.add_argument("--species", required=True, help="bird id, for instance 'amsel'")
    frame.add_argument("--observation", required=True, type=int, help="iNaturalist observation id")
    frame.add_argument("--photo", required=True, type=int, help="iNaturalist photo id")
    frame.add_argument(
        "--box",
        type=framing.parse_box,
        help="the bird as 'x0,y0,x1,y1', normalised 0–1 from the top left; "
        "default: whatever Apple Vision finds salient",
    )
    frame.add_argument(
        "--margin",
        type=float,
        default=framing.MARGIN,
        help=f"air around the bird, as a fraction of its longer side (default {framing.MARGIN})",
    )
    frame.add_argument(
        "--preview",
        type=Path,
        default=FRAME_PREVIEW_DIR,
        help="where the two preview PNGs go (default DerivedData/frame-preview)",
    )
    frame.add_argument(
        "--dry-run",
        action="store_true",
        help="print the crop and write the previews, but record nothing",
    )
    frame.set_defaults(run=command_frame)

    audit = photos.add_parser("audit", help="export a pack's tiles for judging")
    audit.add_argument("--pack", required=True, help="pack id, for instance 'basis'")
    audit.add_argument("--species", nargs="+", help="bird ids; default: every bird in the pack")
    audit.add_argument(
        "--add-verdicts",
        metavar="FILE",
        help="merge a JSON array of verdicts into verdicts.json ('-' reads standard input)",
    )
    audit.set_defaults(run=command_audit)

    drop = photos.add_parser("drop", help="take one photo out of a species' set")
    drop.add_argument("--pack", required=True)
    drop.add_argument("--species", required=True, help="bird id, for instance 'amsel'")
    drop.add_argument(
        "--file",
        required=True,
        help="the photo as the manifest names it, for instance 'photos/amsel-2.heic'",
    )
    drop.set_defaults(run=command_drop)

    calls = commands.add_parser("calls", help="calls from xeno-canto").add_subparsers(
        dest="step", required=True
    )

    listing = calls.add_parser("candidates", help="list freely licensed recordings for a pack")
    listing.add_argument("--pack", required=True, help="pack id, for instance 'deutschland'")
    listing.add_argument("--species", nargs="+", help="bird ids; default: every bird in the pack")
    listing.add_argument(
        "--limit", type=int, default=5, help="recordings to list per species (default: 5)"
    )
    listing.add_argument(
        "--type",
        help="only recordings whose type says this, for instance 'song', 'call' or "
        "'drumming'; default: song and call first, sounds the game cannot use hidden",
    )
    listing.add_argument(
        "--out",
        type=Path,
        default=DEFAULT_OUT,
        help=f"where to write the candidate list (default: {DEFAULT_OUT})",
    )
    listing.set_defaults(run=command_call_candidates)

    picking = calls.add_parser("pick", help="fetch and record one recording a human chose")
    picking.add_argument("--pack", required=True)
    picking.add_argument("--species", required=True, help="bird id, for instance 'amsel'")
    picking.add_argument(
        "--recording",
        required=True,
        type=xenocanto.recording_number,
        help="xeno-canto catalogue number, for instance 'XC965144'",
    )
    picking.add_argument(
        "--start", type=float, default=0.0, help="seconds into the recording (default: 0)"
    )
    picking.add_argument(
        "--duration",
        type=float,
        default=audio.DURATION,
        help=f"seconds to keep (default: {audio.DURATION:g})",
    )
    picking.set_defaults(run=command_call_pick)

    speaking = commands.add_parser("speech", help="the sentences the app says out loud")
    spoken = speaking.add_subparsers(dest="step", required=True)

    render = spoken.add_parser("render", help="ask a provider for one or more sentences")
    add_speech_place(render)
    render.add_argument("--species", nargs="+", help="bird ids; default: every bird in the pack")
    render.add_argument(
        "--sentence",
        nargs="+",
        help="String Catalog keys; default for a pack: " + ", ".join(sentences.SPECIES_SENTENCES),
    )
    render.add_argument(
        "--provider",
        required=True,
        choices=sorted(speech.PROVIDERS),
        help="which adapter speaks — 'fake' produces tones and reaches no vendor",
    )
    render.add_argument("--voice", help="a voice the provider offers; default: its own")
    render.add_argument(
        "--max-chars",
        type=int,
        default=MAX_CHARS,
        help=f"refuse a run longer than this many characters (default: {MAX_CHARS})",
    )
    render.set_defaults(run=command_speech_render)

    listing = spoken.add_parser("voices", help="the voices a provider offers")
    listing.add_argument(
        "--provider",
        required=True,
        choices=sorted(speech.PROVIDERS),
        help="which adapter to ask",
    )
    listing.set_defaults(run=command_speech_voices)

    importing = spoken.add_parser("import", help="record one take somebody made")
    add_speech_place(importing)
    importing.add_argument("--species", help="bird id, for instance 'amsel'")
    importing.add_argument("--sentence", required=True, help="String Catalog key")
    importing.add_argument(
        "--file",
        required=True,
        type=Path,
        help="the take, in a format afconvert reads: " + ", ".join(sorted(audio.SOURCE_SUFFIXES)),
    )
    importing.add_argument(
        "--attribution",
        required=True,
        help="who is heard, as the credits will name them, for instance 'Stimme: Johanna'",
    )
    importing.set_defaults(run=command_speech_import)

    upload = commands.add_parser("upload", help="upload a pack to the media bucket")
    upload.add_argument("--pack", required=True)
    upload.add_argument("--dry-run", action="store_true", help="report what would happen")
    upload.set_defaults(run=command_upload)

    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    # Everything below reports as one `::error::` line rather than a traceback:
    # the tool is run by a person who wants to know which photo to pick
    # instead, not by a developer reading a stack. `redact` here is a backstop:
    # `xenocanto.Client` already cleans every message it raises, so today this
    # changes nothing. It is the one line every failure passes through, and the
    # cost of being wrong about a key in a CI log is not worth the two words.
    try:
        return args.run(args)
    except (
        OSError,
        ValueError,
        LookupError,
        RuntimeError,
        httpx.HTTPError,
        BotoCoreError,
        ClientError,
    ) as error:
        print(f"::error::{escape_data(keys.redact(f'{type(error).__name__}: {error}'))}")
        return 1
