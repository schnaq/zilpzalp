"""The command line of the curation tool.

Three steps, and a human between them:

    photos candidates --pack basis [--species amsel …] [--limit 5]
    photos pick --pack basis --species amsel --observation 20490738 --photo 31623386
    upload --pack basis [--dry-run]

`candidates` asks iNaturalist and lists what may be used; it never chooses.
`pick` fetches the one photo a human named, crops it, writes the manifest entry
and regenerates the derived files. `upload` puts the pack in the bucket and,
last, the index of the packs that can be downloaded from there.

Only `upload` needs credentials, and it reads them from the environment, where
`infisical run --env=dev --path=/ --` puts them. The other two run on any
machine, with no login and no key.
"""

from __future__ import annotations

import argparse
import dataclasses
import datetime
import subprocess
import sys
import tempfile
from pathlib import Path

import httpx
from botocore.exceptions import BotoCoreError, ClientError

from fetch_media import images, inaturalist, index, manifest, s3

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


def selected_birds(document: dict, species: list[str] | None) -> list[dict]:
    """The birds to work on: the named ones, or the whole pack."""
    if not species:
        return list(document.get("birds") or [])
    return [manifest.bird(document, bird_id) for bird_id in species]


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
    # The last column is left unpadded so the URL stays clickable.
    widths = [max(len(row[column]) for row in [header, *rows]) for column in range(len(header) - 1)]

    for row in [header, *rows]:
        cells = [cell.ljust(width) for cell, width in zip(row, widths, strict=False)]
        print("  ".join([*cells, row[-1]]).rstrip())

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

    pack = manifest.pack_dir(args.pack)
    relative = f"photos/{args.species}.jpg"
    destination = pack / relative
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(encoded)

    digest = manifest.sha256_of(destination)
    previous = manifest.set_photo(
        document,
        args.species,
        manifest.media_block(
            file=relative,
            sha256=digest,
            licence=inaturalist.licence_id(photo["license_code"]),
            attribution=inaturalist.photographer(observation),
            source_url=inaturalist.OBSERVATION_URL.format(args.observation),
            retrieved=datetime.date.today().isoformat(),
        ),
    )
    manifest.save(path, document)

    # The manifest is the truth about the pack directory. A photo it no longer
    # names would still be copied into the app bundle by sync_bundled_packs.py.
    if previous and previous != relative:
        orphan = pack / previous
        if orphan.is_file() and orphan.resolve().is_relative_to(pack.resolve()):
            orphan.unlink()
            print(f"{args.species}: removed the previous {previous}")

    print(f"{args.species}: {relative}  {len(encoded)} bytes  sha256 {digest}")
    regenerate_derived()
    print("\nLook at the photo before you commit it — nothing else has seen it yet.")
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


def build_parser() -> argparse.ArgumentParser:
    """The whole command line.

    Finding a medium is specific to its source, so `candidates` and `pick` sit
    under `photos` and #16 will add a `calls` beside it. Uploading is not:
    `upload` puts the whole pack in the bucket, photos and recordings alike,
    and therefore stays at the top level where a second medium needs no second
    copy of it.
    """
    parser = argparse.ArgumentParser(prog="fetch_media", description=__doc__.splitlines()[0])
    commands = parser.add_subparsers(dest="command", required=True)
    photos = commands.add_parser("photos", help="photos from iNaturalist").add_subparsers(
        dest="step", required=True
    )

    candidates = photos.add_parser("candidates", help="list freely licensed photos for a pack")
    candidates.add_argument("--pack", required=True, help="pack id, for instance 'basis'")
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

    upload = commands.add_parser("upload", help="upload a pack to the media bucket")
    upload.add_argument("--pack", required=True)
    upload.add_argument("--dry-run", action="store_true", help="report what would happen")
    upload.set_defaults(run=command_upload)

    return parser


def main(argv: list[str] | None = None) -> int:
    args = build_parser().parse_args(argv)

    # Everything below reports as one `::error::` line rather than a traceback:
    # the tool is run by a person who wants to know which photo to pick
    # instead, not by a developer reading a stack.
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
        print(f"::error::{escape_data(f'{type(error).__name__}: {error}')}")
        return 1
