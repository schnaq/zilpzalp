"""Upload a pack to the media bucket.

Layout in the bucket (issue #14): `packs/<id>/manifest.json`,
`packs/<id>/photos/…`, `packs/<id>/audio/…` and, since #163,
`packs/<id>/speech/<sentence>/…`. A bucket policy grants anonymous
`s3:GetObject` on `packs/*`, so an upload needs no per-object ACL.
`packs/index.json` is built by `index.py` and put through here as well, but
only after the pack it describes (#50).

Credentials come from Infisical and are only ever read from the environment —
never printed, never logged, never written to a file. The tool reports keys and
sizes, which is what a human needs to see.
"""

from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

import boto3
from botocore.config import Config
from botocore.exceptions import ClientError

from fetch_media import manifest

# What `infisical run --env=dev --path=/ --` injects. The names are public; the
# values are not, and nothing here prints them.
REQUIRED_ENV = ("SCW_ACCESS_KEY", "SCW_SECRET_KEY", "S3_BUCKET", "S3_REGION", "S3_ENDPOINT")

# The object metadata that makes an upload idempotent. An ETag would be the
# obvious candidate, but it is only the MD5 of a single-part upload and says
# nothing after a multipart one — the digest the manifest already carries is
# both stable and the thing the app verifies after a download.
SHA256_METADATA = "sha256"

CONTENT_TYPES = {
    ".jpg": "image/jpeg",
    ".jpeg": "image/jpeg",
    ".json": "application/json",
    ".m4a": "audio/mp4",
    ".mp3": "audio/mpeg",
    ".png": "image/png",
}


@dataclass(frozen=True)
class Upload:
    """One object of a pack, ready to be put."""

    key: str
    path: Path
    sha256: str

    @property
    def size(self) -> int:
        return self.path.stat().st_size

    @property
    def content_type(self) -> str:
        suffix = self.path.suffix.lower()
        if suffix not in CONTENT_TYPES:
            raise ValueError(f"{self.path.name}: no content type for '{suffix}'")
        return CONTENT_TYPES[suffix]


def client_from_env(environment: dict | None = None):
    """An S3 client for the media bucket, and the bucket's name.

    Raises `RuntimeError` naming the *variables* that are missing — never their
    values.
    """
    environment = os.environ if environment is None else environment

    missing = [name for name in REQUIRED_ENV if not environment.get(name)]
    if missing:
        raise RuntimeError(
            f"missing from the environment: {', '.join(missing)}. "
            "Run through 'infisical run --env=dev --path=/ --'."
        )

    client = boto3.client(
        "s3",
        endpoint_url=environment["S3_ENDPOINT"],
        region_name=environment["S3_REGION"],
        aws_access_key_id=environment["SCW_ACCESS_KEY"],
        aws_secret_access_key=environment["SCW_SECRET_KEY"],
        # Scaleway is S3-compatible, not S3. Since botocore 1.36 the default
        # `when_supported` sends a CRC32 trailer and `aws-chunked` encoding on
        # every put, which such stores reject. `when_required` sends checksums
        # only where the operation demands them, which is the pre-1.36
        # behaviour and what the bucket was verified with.
        config=Config(
            request_checksum_calculation="when_required",
            response_checksum_validation="when_required",
        ),
    )
    return client, environment["S3_BUCKET"]


def manifest_key(pack_id: str) -> str:
    """Where a pack's manifest sits in the bucket."""
    return f"packs/{pack_id}/manifest.json"


def plan(pack_id: str, pack_dir: Path) -> list[Upload]:
    """Everything of one pack that belongs in the bucket, in upload order.

    Media first, manifest last: a reader that sees the new manifest can always
    fetch the files it names. Only what the manifest declares is uploaded, and
    every file is checked against the digest the manifest promises before it
    leaves the machine — the bucket is what the app verifies its downloads
    against, so a wrong file there is worse than no file.
    """
    path = pack_dir / "manifest.json"
    document = manifest.load(path)

    uploads = []
    for relative, expected in manifest.media_files(document):
        media = pack_dir / relative
        if not media.is_file():
            raise FileNotFoundError(f"{pack_id}: the manifest names {relative}, which does not exist")

        actual = manifest.sha256_of(media)
        if actual != expected.lower():
            raise ValueError(
                f"{pack_id}: {relative} does not match its manifest entry "
                f"(manifest {expected}, file {actual}) — run the licence gate"
            )
        uploads.append(Upload(key=f"packs/{pack_id}/{relative}", path=media, sha256=actual))

    uploads.append(Upload(key=manifest_key(pack_id), path=path, sha256=manifest.sha256_of(path)))
    return uploads


def remote_sha256(client, bucket: str, key: str) -> str | None:
    """The digest the bucket holds for that key, `None` when it holds nothing."""
    try:
        head = client.head_object(Bucket=bucket, Key=key)
    except ClientError as error:
        if error.response.get("ResponseMetadata", {}).get("HTTPStatusCode") == 404:
            return None
        raise
    return head.get("Metadata", {}).get(SHA256_METADATA)


def put(client, bucket: str, upload: Upload) -> None:
    """Store one object, with its digest as metadata for the next run."""
    with upload.path.open("rb") as stream:
        client.put_object(
            Bucket=bucket,
            Key=upload.key,
            Body=stream,
            ContentType=upload.content_type,
            Metadata={SHA256_METADATA: upload.sha256},
        )


def report_line(verb: str, upload: Upload) -> str:
    """One line of the upload report: what happens, to which key, how large.

    Keys and sizes and nothing else — the report is read aloud in pull requests
    and must not be able to carry anything from the environment.
    """
    return f"{verb:>13}  {upload.key}  {upload.size} bytes"


def sync(client, bucket: str, uploads: list[Upload], dry_run: bool = False) -> list[str]:
    """Upload what has changed. Returns one report line per object."""
    report = []

    for upload in uploads:
        unchanged = remote_sha256(client, bucket, upload.key) == upload.sha256
        verb = "skip" if unchanged else ("would upload" if dry_run else "upload")
        report.append(report_line(verb, upload))

        if not unchanged and not dry_run:
            put(client, bucket, upload)

    return report
