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
          "manifest": "packs/deutschland/manifest.json"
        }
      ]
    }

`manifest` is a bucket key, not a URL: the manifest's own media paths are
relative to it as well, so a downloader resolves everything against the base it
already used to fetch the index — which is what lets #33 test against a local
server, and what lets the bucket move behind a CDN without regenerating the
index. `downloadSize` is in bytes and counts every object of the pack, the
manifest included, so it is what a download actually costs.
"""

from __future__ import annotations

from collections.abc import Callable
from pathlib import Path

from fetch_media import manifest, s3

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
BUNDLED_PACKS = ("basis",)


def packs() -> list[str]:
    """Every pack under `data/packs/`, by id, in a stable order."""
    return sorted(
        path.name for path in manifest.PACKS_DIR.iterdir() if (path / "manifest.json").is_file()
    )


def entry(pack_id: str) -> dict:
    """One pack's line in the index, from its manifest and its upload plan.

    The size is summed over `s3.plan`, so it is the size of the objects that
    actually end up in the bucket rather than of whatever else the pack
    directory may hold.
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
    return {
        "id": pack_id,
        "title": document["title"],
        "speciesCount": len(document.get("birds") or []),
        "downloadSize": sum(upload.size for upload in uploads),
        "manifest": s3.manifest_key(pack_id),
    }


def build(*, uploading: str | None, in_bucket: Callable[[str], bool]) -> dict:
    """The index document: the packs a downloader can really fetch.

    A pack is listed only when the bucket holds its manifest, or when this run
    is about to put it there. Without that guard the index of a multi-pack
    repository would advertise packs nobody has ever uploaded.
    """
    entries = []
    for pack_id in packs():
        if pack_id in BUNDLED_PACKS:
            continue
        if pack_id != uploading and not in_bucket(s3.manifest_key(pack_id)):
            continue
        entries.append(entry(pack_id))

    return {"packs": entries}


def staged(document: dict, directory: Path) -> s3.Upload:
    """Write the index into a scratch directory and describe it as an object."""
    path = directory / Path(KEY).name
    manifest.save(path, document)
    return s3.Upload(key=KEY, path=path, sha256=manifest.sha256_of(path))
