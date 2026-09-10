"""Tests for the upload step, against a stubbed S3 client.

No test opens a socket and none of them needs a credential: the stubber answers
in place of the bucket.

Run from the repository root:
uv run --locked --project tools python -m unittest discover -s tools/tests -t tools
"""

from __future__ import annotations

import contextlib
import hashlib
import io
import os
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import boto3
from botocore.exceptions import ClientError
from botocore.stub import ANY, Stubber

from fetch_media import cli, manifest, s3

BUCKET = "zilpzalp-media"
PHOTO = b"not really a photo, but it hashes just the same"
PHOTO_SHA256 = hashlib.sha256(PHOTO).hexdigest()
CLIP = b"not really a recording either"
SENTENCE = "quiz.prompt.whereIs"
CLIP_FILE = f"speech/{SENTENCE}/amsel.m4a"

ENVIRONMENT = {
    "SCW_ACCESS_KEY": "access",
    "SCW_SECRET_KEY": "secret",
    "S3_BUCKET": BUCKET,
    "S3_REGION": "fr-par",
    "S3_ENDPOINT": "https://s3.fr-par.scw.cloud",
}


def stubbed_client():
    """A client that answers from a stub instead of from the network."""
    client = boto3.client(
        "s3",
        endpoint_url=ENVIRONMENT["S3_ENDPOINT"],
        region_name=ENVIRONMENT["S3_REGION"],
        aws_access_key_id="access",
        aws_secret_access_key="secret",
    )
    return client, Stubber(client)


class PackTestCase(unittest.TestCase):
    """Base class providing a throwaway pack with one photo."""

    def setUp(self) -> None:
        self._directory = tempfile.TemporaryDirectory()
        self.addCleanup(self._directory.cleanup)
        self.pack = Path(self._directory.name) / "basis"
        (self.pack / "photos").mkdir(parents=True)
        (self.pack / "photos" / "amsel.jpg").write_bytes(PHOTO)
        self.write_manifest(PHOTO_SHA256)

    def write_manifest(self, sha256: str) -> None:
        manifest.save(
            self.pack / "manifest.json",
            {
                "id": "basis",
                "title": "Unsere ersten Vögel",
                "birds": [
                    {
                        "id": "amsel",
                        "name": "Amsel",
                        "photos": [manifest.media_block(
                            file="photos/amsel.jpg",
                            sha256=sha256,
                            licence="CC-BY-4.0",
                            attribution="Alexis Tinker-Tsavalas",
                            source_url="https://www.inaturalist.org/observations/20490738",
                            retrieved="2026-09-07",
                        )],
                        "call": None,
                    }
                ],
            },
        )

    def record_a_sentence(self) -> None:
        """Give the pack's one bird a recorded sentence, clip and voice.

        Only the tests that are about speech call it: the others assert on an
        upload plan of exactly two objects.
        """
        clip = self.pack / CLIP_FILE
        clip.parent.mkdir(parents=True, exist_ok=True)
        clip.write_bytes(CLIP)

        document = manifest.load(self.pack / "manifest.json")
        manifest.set_voice(
            document,
            manifest.voice_block(
                licence="CC-BY-4.0",
                attribution="Stimme: Niemand",
                source_url="https://example.org/docs/sprachaufnahmen.md",
                retrieved="2026-09-09",
            ),
        )
        manifest.set_speech(
            document,
            "amsel",
            SENTENCE,
            manifest.speech_block(
                file=CLIP_FILE, sha256=manifest.sha256_of(clip), text="Wo ist die Amsel?"
            ),
        )
        manifest.save(self.pack / "manifest.json", document)


class ClientTests(unittest.TestCase):
    def test_names_the_missing_variables_and_no_value(self) -> None:
        partial = {**ENVIRONMENT, "SCW_SECRET_KEY": "", "S3_BUCKET": ""}

        with self.assertRaises(RuntimeError) as error:
            s3.client_from_env(partial)

        message = str(error.exception)
        self.assertIn("SCW_SECRET_KEY", message)
        self.assertIn("S3_BUCKET", message)
        self.assertNotIn(partial["SCW_ACCESS_KEY"], message)

    def test_returns_the_bucket_from_the_environment(self) -> None:
        _, bucket = s3.client_from_env(ENVIRONMENT)

        self.assertEqual(bucket, BUCKET)

    def test_sends_checksums_only_where_they_are_required(self) -> None:
        """Scaleway rejects the aws-chunked bodies botocore sends by default."""
        client, _ = s3.client_from_env(ENVIRONMENT)

        self.assertEqual(client.meta.config.request_checksum_calculation, "when_required")
        self.assertEqual(client.meta.config.response_checksum_validation, "when_required")


class PlanTests(PackTestCase):
    def test_uploads_the_media_before_the_manifest(self) -> None:
        """A reader of the new manifest can always fetch what it names."""
        uploads = s3.plan("basis", self.pack)

        self.assertEqual(
            [upload.key for upload in uploads],
            ["packs/basis/photos/amsel.jpg", "packs/basis/manifest.json"],
        )
        self.assertEqual(uploads[0].sha256, PHOTO_SHA256)
        self.assertEqual(uploads[0].size, len(PHOTO))

    def test_uploads_a_recorded_sentence_like_every_other_medium(self) -> None:
        """#166: a clip that is not in the plan never reaches the bucket, and
        the pack a parent downloads is silent."""
        self.record_a_sentence()

        uploads = s3.plan("basis", self.pack)

        self.assertEqual(
            [upload.key for upload in uploads],
            [
                "packs/basis/photos/amsel.jpg",
                f"packs/basis/{CLIP_FILE}",
                "packs/basis/manifest.json",
            ],
        )
        self.assertEqual(uploads[1].sha256, hashlib.sha256(CLIP).hexdigest())
        self.assertEqual(uploads[1].size, len(CLIP))
        self.assertEqual(uploads[1].content_type, "audio/mp4")

    def test_refuses_a_clip_that_does_not_match_its_manifest_entry(self) -> None:
        """The bucket is what a download is verified against, so a wrong clip
        there is worse than no clip."""
        self.record_a_sentence()
        (self.pack / CLIP_FILE).write_bytes(b"a different sentence")

        with self.assertRaises(ValueError) as error:
            s3.plan("basis", self.pack)

        self.assertIn(CLIP_FILE, str(error.exception))

    def test_refuses_a_file_that_does_not_match_its_manifest_entry(self) -> None:
        self.write_manifest("f" * 64)

        with self.assertRaises(ValueError) as error:
            s3.plan("basis", self.pack)

        self.assertIn("photos/amsel.jpg", str(error.exception))

    def test_refuses_a_manifest_entry_without_a_file(self) -> None:
        (self.pack / "photos" / "amsel.jpg").unlink()

        with self.assertRaises(FileNotFoundError):
            s3.plan("basis", self.pack)

    def test_names_the_content_type_by_suffix(self) -> None:
        uploads = s3.plan("basis", self.pack)

        self.assertEqual(uploads[0].content_type, "image/jpeg")
        self.assertEqual(uploads[1].content_type, "application/json")

    def test_names_the_content_type_of_a_photo_tile(self) -> None:
        """What `photos pick` writes: without the suffix the upload would fail."""
        upload = s3.Upload(key="packs/basis/photos/amsel.heic", path=Path("amsel.heic"), sha256="")

        self.assertEqual(upload.content_type, "image/heic")

    def test_refuses_a_suffix_it_cannot_name(self) -> None:
        upload = s3.Upload(key="packs/basis/photos/amsel.tiff", path=Path("amsel.tiff"), sha256="")

        with self.assertRaises(ValueError):
            _ = upload.content_type


class SyncTests(PackTestCase):
    def setUp(self) -> None:
        super().setUp()
        self.uploads = s3.plan("basis", self.pack)
        self.client, self.stubber = stubbed_client()
        self.stubber.activate()
        self.addCleanup(self.stubber.deactivate)

    def expect_head(self, upload: s3.Upload, sha256: str | None) -> None:
        """Answer the next head_object: `None` means the bucket has no such key."""
        if sha256 is None:
            self.stubber.add_client_error(
                "head_object",
                service_error_code="404",
                http_status_code=404,
                expected_params={"Bucket": BUCKET, "Key": upload.key},
            )
        else:
            self.stubber.add_response(
                "head_object",
                {"Metadata": {"sha256": sha256}},
                {"Bucket": BUCKET, "Key": upload.key},
            )

    def expect_put(self, upload: s3.Upload) -> None:
        self.stubber.add_response(
            "put_object",
            {},
            {
                "Bucket": BUCKET,
                "Key": upload.key,
                "Body": ANY,
                "ContentType": upload.content_type,
                "Metadata": {"sha256": upload.sha256},
            },
        )

    def test_uploads_what_the_bucket_does_not_have(self) -> None:
        for upload in self.uploads:
            self.expect_head(upload, None)
            self.expect_put(upload)

        report = s3.sync(self.client, BUCKET, self.uploads)

        self.stubber.assert_no_pending_responses()
        self.assertTrue(all(line.startswith("       upload") for line in report))

    def test_skips_an_object_whose_digest_already_matches(self) -> None:
        for upload in self.uploads:
            self.expect_head(upload, upload.sha256)

        report = s3.sync(self.client, BUCKET, self.uploads)

        self.stubber.assert_no_pending_responses()
        self.assertTrue(all("skip" in line for line in report))

    def test_uploads_an_object_that_changed(self) -> None:
        photo, manifest_object = self.uploads
        self.expect_head(photo, "0" * 64)
        self.expect_put(photo)
        self.expect_head(manifest_object, manifest_object.sha256)

        report = s3.sync(self.client, BUCKET, self.uploads)

        self.stubber.assert_no_pending_responses()
        self.assertIn("upload", report[0])
        self.assertIn("skip", report[1])

    def test_uploads_nothing_on_a_dry_run(self) -> None:
        for upload in self.uploads:
            self.expect_head(upload, None)

        report = s3.sync(self.client, BUCKET, self.uploads, dry_run=True)

        # No put_object was stubbed, so a real one would have raised here.
        self.stubber.assert_no_pending_responses()
        self.assertTrue(all("would upload" in line for line in report))

    def test_reports_keys_and_sizes_only(self) -> None:
        """The report goes into a pull request; it must not carry anything else."""
        for upload in self.uploads:
            self.expect_head(upload, None)

        report = s3.sync(self.client, BUCKET, self.uploads, dry_run=True)

        self.assertEqual(
            report,
            [
                f" would upload  packs/basis/photos/amsel.jpg  {len(PHOTO)} bytes",
                f" would upload  packs/basis/manifest.json  {self.uploads[1].size} bytes",
            ],
        )

    def test_lets_an_unexpected_error_through(self) -> None:
        """A 403 is a broken key or policy, not an absent object."""
        self.stubber.add_client_error("head_object", service_error_code="403", http_status_code=403)

        with self.assertRaises(ClientError):
            s3.sync(self.client, BUCKET, self.uploads)


class WithoutCredentialsTests(PackTestCase):
    """Issue #15: the tool has to be usable on a machine without S3 keys."""

    def upload(self, *arguments: str) -> tuple[int, str]:
        output = io.StringIO()
        empty = {name: "" for name in s3.REQUIRED_ENV}
        with mock.patch.dict(os.environ, empty), mock.patch.object(
            manifest, "PACKS_DIR", self.pack.parent
        ), contextlib.redirect_stdout(output):
            exit_code = cli.main(["upload", "--pack", "basis", *arguments])
        return exit_code, output.getvalue()

    def test_lists_the_plan_on_a_dry_run(self) -> None:
        exit_code, output = self.upload("--dry-run")

        self.assertEqual(exit_code, 0)
        self.assertIn("unchecked  packs/basis/photos/amsel.jpg", output)
        self.assertIn("unchecked  packs/basis/manifest.json", output)

    def test_lists_the_speech_clips_on_a_dry_run(self) -> None:
        """The acceptance #166 asks for: what a dry run names is what the app
        can download, and a pack's clips are part of it."""
        self.record_a_sentence()

        exit_code, output = self.upload("--dry-run")

        self.assertEqual(exit_code, 0)
        self.assertIn(f"unchecked  packs/basis/{CLIP_FILE}  {len(CLIP)} bytes", output)

    def test_refuses_a_real_upload(self) -> None:
        exit_code, output = self.upload()

        self.assertEqual(exit_code, 1)
        self.assertIn("::error::", output)
        self.assertIn("SCW_ACCESS_KEY", output)


if __name__ == "__main__":
    unittest.main()
