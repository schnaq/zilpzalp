"""The command line of the curation tool.

Three kinds of medium, and a human between every step:

    photos candidates --pack deutschland [--species amsel …] [--limit 5]
    photos pick --pack deutschland --species amsel --observation 20490738 --photo 31623386
    calls candidates --pack deutschland [--species amsel …] [--limit 5] [--type song]
    calls pick --pack deutschland --species amsel --recording XC965144 [--start 12.5]
    speech render --provider fake --pack deutschland [--species amsel …] [--sentence …]
    speech render --provider fake --set fixed --sentence roundEnd.title
    speech import --pack deutschland --species amsel --sentence … --file take3.wav
                  --attribution "Stimme: …"
    upload --pack deutschland [--dry-run]

`candidates` asks the source and lists what may be used; it never chooses.
`pick` fetches the one medium a human named, crops or trims it, writes the
manifest entry and regenerates the derived files. `speech` produces the
sentences the app says out loud — `render` asks a provider, `import` takes a
recording somebody made — and records them the same way. `upload` puts the
pack in the bucket and, last, the index of the packs that can be downloaded
from there.

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
import subprocess
import sys
import tempfile
from pathlib import Path

import httpx
from botocore.exceptions import BotoCoreError, ClientError

from fetch_media import audio, images, inaturalist, index, keys, manifest, s3, speech, xenocanto
from fetch_media.speech import clips, sentences

# Candidate lists are working material for a human, not a build artefact, and
# `data/packs/` is off limits for them: the licence gate reads every *.json
# below it as a manifest.
DEFAULT_OUT = Path(tempfile.gettempdir()) / "zilpzalp-fetch-media"

# Run in the order `mise run check` runs them, so a manifest change leaves the
# repository exactly as CI expects to find it.
DERIVED_TOOLS = ("sync_bundled_packs.py", "generate_credits.py")


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


def remove_orphan(directory: Path, label: str, previous: str | None, relative: str) -> None:
    """Delete the file the manifest no longer names.

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


def command_pick(args: argparse.Namespace) -> int:
    """Fetch, crop and record the one photo a human chose."""
    path = manifest.manifest_path(args.pack)
    document = manifest.load(path)
    bird = manifest.bird(document, args.species)

    with inaturalist.Client() as client:
        observation = client.observation(args.observation)
        if not inaturalist.taxon_matches(observation, bird["taxonID"]):
            taxon = observation.get("taxon") or {}
            raise ValueError(
                f"observation {args.observation} shows {taxon.get('name')} "
                f"(taxon {taxon.get('id')}), not {bird['scientificName']} (taxon {bird['taxonID']})"
            )

        photo = inaturalist.find_photo(observation, args.photo)
        original = inaturalist.original_url(photo["url"])
        print(f"{args.species}: downloading {original}")
        encoded = images.square_photo(client.download(original), args.crop)

    record_medium(
        args.pack,
        document,
        args.species,
        "photo",
        f"photos/{args.species}.{images.SUFFIX}",
        encoded,
        licence=inaturalist.licence_id(photo["license_code"]),
        attribution=inaturalist.photographer(observation),
        source_url=inaturalist.OBSERVATION_URL.format(args.observation),
    )
    regenerate_derived()
    print("\nLook at the photo before you commit it — nothing else has seen it yet.")
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


def command_speech_render(args: argparse.Namespace) -> int:
    """Ask a provider for every sentence named, and record what comes back."""
    provider = speech.provider(args.provider)
    document, work = speech_work(args.pack, args.set, args.species, args.sentence)

    # Before the first sentence is spoken, not after: a provider that is not
    # the one this manifest was produced with is refused here, where it has
    # cost nothing. `record_clip` asks again per clip and finds it agreed.
    voice = provider.voice()
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
    render.set_defaults(run=command_speech_render)

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
