"""Build `packs/index.json` — what a pack downloader (#33) can see.

The index is generated from the manifests under `data/packs/`, never written by
hand, and never committed: `data/packs/` is off limits for it, because the
licence gate and the credits generator read every `*.json` below it as a
manifest. It is built into a scratch file and uploaded from there.

One entry per downloadable pack:

    {
      "packs": [
        {
          "id": "deutschland",
          "title": "Vögel in Deutschland",
          "speciesCount": 24,
          "downloadSize": 12345678,
          "manifest": "packs/deutschland/manifest.json",
          "manifestSha256": "…",
          "covers": ["amsel", "blaumeise", "rotkehlchen"],
          "species": [
            {
              "id": "amsel",
              "name": "Amsel",
              "preview": "packs/deutschland/previews/amsel.jpg",
              "attribution": "…",
              "license": "CC-BY-4.0"
            }
          ]
        }
      ],
      "retired": [{"id": "welt", "successors": ["suedamerika", "nordamerika", …]}]
    }

`manifest` is a bucket key, not a URL: the manifest's own media paths are
relative to it as well, so a downloader resolves everything against the base it
already used to fetch the index — which is what lets #33 test against a local
server, and what lets the bucket move behind a CDN without regenerating the
index. `downloadSize` is in bytes and counts every object of the pack, the
manifest included, so it is what a download actually costs.

Everything after `manifest` is optional for a reader (#262): the 1.0.0 app
ignores it, and an index without it still has to work.

- `manifestSha256` is the manifest the bucket holds, so the app can tell an
  installed pack from a newer one.
- `covers` and `species` feed the grown-ups' gallery: three birds for the card
  and one small preview per bird, with the attribution and licence of the
  photo it was cut from — the app prints those beside the previews, because a
  pack's credits are not on the device before it is downloaded. Both are left
  out until the bucket holds the pack's previews.
- `retired` lists packs that were dissolved into others, see `RETIRED`.
"""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path

from fetch_media import images, manifest, s3

# Where the index sits in the bucket (#14).
KEY = "packs/index.json"

# The packs that ship inside the app. They are not downloadable and have no
# place in the index.
#
# The source of truth is BUNDLED_PACKS in tools/sync_bundled_packs.py, which is
# standard-library only and lives outside this project's virtual environment.
# Importing it happens to work today, but only through the `.pth` file uv's
# editable install drops into the environment — a wheel or `--no-editable`
# would break the upload. So the tuple is duplicated here, and
# test_fetch_media_index.py fails as soon as the two disagree.
BUNDLED_PACKS = ("deutschland",)

# Packs that were dissolved into others, with the packs that took their birds
# over. A retired pack leaves `packs` and is listed under `retired`, so a
# device that has it installed is offered the successors and then lets it go.
# Every species of a retired pack must be in one of its successors — `build`
# refuses otherwise, as long as the retired manifest is still in data/packs —
# or a child would lose those stickers from the album.
#
# "Vögel der Welt" (welt) was dissolved into the regional packs (2026-10-22).
# Its manifest is gone from data/packs, so `check_retired` no longer checks its
# birds: every one but raggi-paradiesvogel, which never had a photo pass
# review, is in one of these six. test_fetch_media_index.py checks that they
# are packs, since the app migrates only once the index lists all of them.
RETIRED: dict[str, tuple[str, ...]] = {
    "welt": (
        "suedamerika",
        "nordamerika",
        "australien-ozeanien",
        "polar-meer",
        "asien",
        "greifvoegel-eulen",
    ),
}

# How many birds stand for a pack on its card.
COVER_COUNT = 3


def packs() -> list[str]:
    """Every pack under `data/packs/`, by id, in a stable order."""
    return sorted(
        path.name for path in manifest.PACKS_DIR.iterdir() if (path / "manifest.json").is_file()
    )


def preview_key(pack_id: str, species: str) -> str:
    """Where a species' preview sits in the bucket."""
    return f"packs/{pack_id}/previews/{species}.jpg"


def birds(pack_id: str) -> list[dict]:
    """The birds of a pack's manifest."""
    return manifest.load(manifest.manifest_path(pack_id)).get("birds") or []


def entry(pack_id: str, *, manifest_sha256: str | None = None, previews: bool = True) -> dict:
    """One pack's line in the index, from its manifest and its upload plan.

    The size is summed over `s3.plan`, so it is the size of the objects that
    actually end up in the bucket rather than of whatever else the pack
    directory may hold. The previews are not part of it: they are looked at,
    not downloaded.

    `manifest_sha256` is the digest the bucket holds, the local manifest's when
    this run uploads it. `previews` says whether the bucket holds the pack's
    previews, so the entry never names one nobody can fetch.
    """
    pack = manifest.pack_dir(pack_id)
    document = manifest.load(manifest.manifest_path(pack_id))

    declared = document.get("id")
    if declared != pack_id:
        raise ValueError(
            f"{pack_id}: the manifest calls the pack '{declared}', but the bucket keys "
            "are built from the directory name — a downloader would fetch the wrong pack"
        )

    uploads = s3.plan(pack_id, pack)
    pack_birds = document.get("birds") or []
    line = {
        "id": pack_id,
        "title": document["title"],
        "speciesCount": len(pack_birds),
        "downloadSize": sum(upload.size for upload in uploads),
        "manifest": s3.manifest_key(pack_id),
        "manifestSha256": manifest_sha256 or manifest.sha256_of(manifest.manifest_path(pack_id)),
    }
    if previews:
        portrayed = [bird for bird in pack_birds if manifest.photos(bird)]
        line["covers"] = [bird["id"] for bird in portrayed[:COVER_COUNT]]
        line["species"] = [
            {
                "id": bird["id"],
                "name": bird["name"],
                "preview": preview_key(pack_id, bird["id"]),
                "attribution": manifest.photos(bird)[0]["attribution"],
                "license": manifest.photos(bird)[0]["license"],
            }
            for bird in portrayed
        ]
    return line


def staged_previews(pack_id: str, directory: Path) -> list[s3.Upload]:
    """One preview per bird, cut from its curated portrait, as objects.

    Staged outside the repository like the index, because nothing below
    `data/packs/` may be anything but a pack's own media. Every bird with a
    photo gets one, which is the list `entry` names.
    """
    pack = manifest.pack_dir(pack_id)
    uploads = []
    for bird in birds(pack_id):
        photos = manifest.photos(bird)
        if not photos:
            continue
        path = directory / "previews" / pack_id / f"{bird['id']}.jpg"
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(images.thumbnail_jpeg((pack / photos[0]["file"]).read_bytes()))
        uploads.append(
            s3.Upload(
                key=preview_key(pack_id, bird["id"]),
                path=path,
                sha256=manifest.sha256_of(path),
            )
        )
    return uploads


def check_retired() -> None:
    """Refuse a retired pack whose birds are not all in its successors."""
    for retired, successors in RETIRED.items():
        if not manifest.manifest_path(retired).is_file():
            continue
        kept = {bird["id"] for successor in successors for bird in birds(successor)}
        lost = sorted({bird["id"] for bird in birds(retired)} - kept)
        if lost:
            raise ValueError(
                f"{retired} is retired, but no successor carries {', '.join(lost)} — "
                "those stickers would leave every album"
            )


def build(*, uploading: str | None, remote: Callable[[str], str | None]) -> dict:
    """The index document: the packs a downloader can really fetch.

    A pack is listed only when the bucket holds its manifest, or when this run
    is about to put it there. Without that guard the index of a multi-pack
    repository would advertise packs nobody has ever uploaded.

    Presence, deliberately, not sameness: a pack whose manifest was re-curated
    but not yet uploaded keeps its entry, described by the local files, rather
    than vanishing from the app's pack list until somebody uploads it again.
    The entry is then a little ahead of the bucket — a size, not a broken
    download, since the downloader verifies every file against the manifest it
    fetched. Whoever adds the second pack should revisit that trade. The
    manifest's digest is the bucket's all the same: a local digest the bucket
    does not hold would show "Aktualisieren" forever (#262).

    `remote` answers with the digest the bucket holds for a key, `None` when
    it holds nothing. The pack of this run is described by its local files,
    previews included, because they are uploaded moments before the index.
    """
    check_retired()
    entries = []
    for pack_id in packs():
        if pack_id in BUNDLED_PACKS or pack_id in RETIRED:
            continue
        if pack_id == uploading:
            entries.append(entry(pack_id))
            continue
        digest = remote(s3.manifest_key(pack_id))
        if digest is None:
            continue
        first = next((bird["id"] for bird in birds(pack_id) if manifest.photos(bird)), None)
        previews = first is not None and remote(preview_key(pack_id, first)) is not None
        entries.append(entry(pack_id, manifest_sha256=digest, previews=previews))

    document: dict = {"packs": entries}
    if RETIRED:
        document["retired"] = [
            {"id": pack_id, "successors": list(successors)}
            for pack_id, successors in sorted(RETIRED.items())
        ]
    return document


def staged(document: dict, directory: Path) -> s3.Upload:
    """Write the index into a scratch directory and describe it as an object."""
    path = directory / Path(KEY).name
    manifest.save(path, document)
    return s3.Upload(key=KEY, path=path, sha256=manifest.sha256_of(path))
