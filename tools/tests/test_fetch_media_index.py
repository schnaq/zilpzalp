"""Tests for packs/index.json — the list a pack downloader (#33) reads.

No test opens a socket and none of them needs a credential: the packs live in a
throwaway directory, and what the bucket already holds is a predicate.

Run from the repository root:
uv run --locked --project tools python -m unittest discover -s tools/tests -t tools
"""

from __future__ import annotations

import contextlib
import io
import json
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import sync_bundled_packs

from fetch_media import cli, index, manifest, s3

BUCKET = "zilpzalp-media"
PHOTO = b"not really a photo, but it hashes just the same"
CLIP = b"not really a recording either"


def never(key: str) -> bool:
    """A bucket that holds nothing."""
    return False


def always(key: str) -> bool:
    """A bucket that holds every pack already."""
    return True


class PacksTestCase(unittest.TestCase):
    """Base class providing a throwaway `data/packs` with two packs."""

    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.packs = Path(directory.name)

        patched = mock.patch.object(manifest, "PACKS_DIR", self.packs)
        patched.start()
        self.addCleanup(patched.stop)

        self.write_pack("basis", "Unsere ersten Vögel", ["amsel"])
        self.write_pack("deutschland", "Vögel in Deutschland", ["amsel", "star"])

    def write_pack(
        self,
        pack_id: str,
        title: str,
        birds: list[str],
        declared: str | None = None,
        speech: bool = False,
    ) -> None:
        """A pack of one photo per bird, all with the same made-up bytes.

        With `speech`, every bird also has one recorded sentence — the same
        made-up bytes again, and one voice for the whole manifest.
        """
        pack = self.packs / pack_id
        (pack / "photos").mkdir(parents=True, exist_ok=True)

        entries = []
        for bird in birds:
            (pack / "photos" / f"{bird}.jpg").write_bytes(PHOTO)
            entries.append(
                {
                    "id": bird,
                    "name": bird.capitalize(),
                    "photo": manifest.media_block(
                        file=f"photos/{bird}.jpg",
                        sha256=manifest.sha256_of(pack / "photos" / f"{bird}.jpg"),
                        licence="CC-BY-4.0",
                        attribution="Alexis Tinker-Tsavalas",
                        source_url="https://www.inaturalist.org/observations/20490738",
                        retrieved="2026-09-07",
                    ),
                    "call": None,
                }
            )

        document = {"id": declared or pack_id, "title": title, "birds": entries}
        if speech:
            self.record_sentences(pack, document, birds)
        manifest.save(pack / "manifest.json", document)

    def record_sentences(self, pack: Path, document: dict, birds: list[str]) -> None:
        """One clip per bird, and the voice that spoke them all."""
        manifest.set_voice(
            document,
            manifest.voice_block(
                licence="CC-BY-4.0",
                attribution="Stimme: Niemand",
                source_url="https://example.org/docs/sprachaufnahmen.md",
                retrieved="2026-09-09",
            ),
        )
        for bird in birds:
            clip = pack / "speech" / "collection.name" / f"{bird}.m4a"
            clip.parent.mkdir(parents=True, exist_ok=True)
            clip.write_bytes(CLIP)
            manifest.set_speech(
                document,
                bird,
                "collection.name",
                manifest.speech_block(
                    file=f"speech/collection.name/{bird}.m4a",
                    sha256=manifest.sha256_of(clip),
                    text=bird.capitalize(),
                ),
            )

    def manifest_size(self, pack_id: str) -> int:
        return (self.packs / pack_id / "manifest.json").stat().st_size


class EntryTests(PacksTestCase):
    def test_names_every_field_of_a_pack(self) -> None:
        """Field by field, as #50 asks."""
        self.assertEqual(
            index.entry("deutschland"),
            {
                "id": "deutschland",
                "title": "Vögel in Deutschland",
                "speciesCount": 2,
                # Both photos and the manifest — what a download really costs.
                "downloadSize": 2 * len(PHOTO) + self.manifest_size("deutschland"),
                "manifest": "packs/deutschland/manifest.json",
            },
        )

    def test_counts_the_speech_clips_in_the_download_size(self) -> None:
        """#166: the size a parent is shown is what the download really costs,
        and since #163 a pack's recordings are part of it."""
        self.write_pack("deutschland", "Vögel in Deutschland", ["amsel", "star"], speech=True)

        self.assertEqual(
            index.entry("deutschland")["downloadSize"],
            2 * len(PHOTO) + 2 * len(CLIP) + self.manifest_size("deutschland"),
        )

    def test_sums_the_objects_that_are_uploaded(self) -> None:
        """Not whatever else the pack directory happens to hold."""
        (self.packs / "deutschland" / "photos" / "orphan.jpg").write_bytes(b"x" * 4096)

        self.assertEqual(
            index.entry("deutschland")["downloadSize"],
            sum(upload.size for upload in s3.plan("deutschland", self.packs / "deutschland")),
        )

    def test_refuses_a_pack_whose_manifest_calls_it_something_else(self) -> None:
        """The bucket keys come from the directory; a downloader would miss."""
        self.write_pack("alpen", "Vögel der Alpen", ["star"], declared="alpes")

        with self.assertRaises(ValueError) as error:
            index.entry("alpen")

        self.assertIn("alpes", str(error.exception))


class BuildTests(PacksTestCase):
    def test_leaves_out_the_bundled_pack(self) -> None:
        """It ships inside the app and cannot be downloaded."""
        document = index.build(uploading=None, in_bucket=always)

        self.assertEqual([entry["id"] for entry in document["packs"]], ["deutschland"])

    def test_bundled_packs_agree_with_the_sync_script(self) -> None:
        """tools/sync_bundled_packs.py is the source of truth; this is a copy."""
        self.assertEqual(index.BUNDLED_PACKS, sync_bundled_packs.BUNDLED_PACKS)

    def test_is_empty_while_the_only_pack_is_the_bundled_one(self) -> None:
        """Today's state, and the index that goes into the bucket for it."""
        shutil.rmtree(self.packs / "deutschland")

        self.assertEqual(index.build(uploading="basis", in_bucket=always), {"packs": []})

    def test_lists_the_pack_of_this_run_although_the_bucket_has_nothing(self) -> None:
        """It is uploaded moments before the index."""
        document = index.build(uploading="deutschland", in_bucket=never)

        self.assertEqual([entry["id"] for entry in document["packs"]], ["deutschland"])

    def test_leaves_out_a_pack_the_bucket_does_not_have(self) -> None:
        """The index must never name a manifest nobody can fetch."""
        self.assertEqual(index.build(uploading="basis", in_bucket=never), {"packs": []})

    def test_asks_the_bucket_for_the_manifest_of_every_other_pack(self) -> None:
        asked = []

        index.build(uploading=None, in_bucket=lambda key: asked.append(key) or True)

        self.assertEqual(asked, ["packs/deutschland/manifest.json"])

    def test_orders_the_packs_by_id(self) -> None:
        """A second run must produce the same bytes as the first."""
        self.write_pack("alpen", "Vögel der Alpen", ["star"])

        document = index.build(uploading=None, in_bucket=always)

        self.assertEqual([entry["id"] for entry in document["packs"]], ["alpen", "deutschland"])


class StagedTests(PacksTestCase):
    def staged(self, document: dict) -> tuple[s3.Upload, str]:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        upload = index.staged(document, Path(directory.name))
        return upload, upload.path.read_text(encoding="utf-8")

    def test_describes_the_index_as_the_object_it_becomes(self) -> None:
        upload, written = self.staged(index.build(uploading="deutschland", in_bucket=never))

        self.assertEqual(upload.key, "packs/index.json")
        self.assertEqual(upload.content_type, "application/json")
        self.assertEqual(upload.sha256, manifest.sha256_of(upload.path))
        self.assertEqual(upload.size, len(written.encode("utf-8")))

    def test_writes_the_document_as_the_repository_writes_json(self) -> None:
        """Two-space indent, a trailing newline, umlauts as themselves."""
        _, written = self.staged(index.build(uploading="deutschland", in_bucket=never))

        self.assertIn('\n      "title": "Vögel in Deutschland",', written)
        self.assertTrue(written.endswith("}\n"))
        self.assertEqual(len(json.loads(written)["packs"]), 1)


class CommandTests(PacksTestCase):
    """The index is the last object of an upload run."""

    def upload(self, *arguments: str) -> tuple[int, list[str]]:
        output = io.StringIO()
        empty = {name: "" for name in s3.REQUIRED_ENV}
        with mock.patch.dict(os.environ, empty), contextlib.redirect_stdout(output):
            exit_code = cli.main(["upload", "--pack", "deutschland", *arguments])
        return exit_code, output.getvalue().splitlines()

    def index_size(self) -> int:
        """The bytes the index of this run amounts to."""
        document = index.build(uploading="deutschland", in_bucket=never)
        return len(manifest.dump(document).encode("utf-8"))

    def staged_index(self):
        """Catch the document the command hands to `index.staged`."""
        return mock.patch.object(index, "staged", wraps=index.staged)

    def listed(self, staged) -> list[str]:
        """The pack ids of that document."""
        return [pack["id"] for pack in staged.call_args.args[0]["packs"]]

    def test_reports_the_index_last_on_a_dry_run(self) -> None:
        """`s3.sync` is covered against a stubbed bucket in the s3 tests; what
        matters here is that the index is reported, and reported last."""
        credentials = mock.patch.object(
            s3, "client_from_env", return_value=(mock.sentinel.client, BUCKET)
        )
        # The bucket holds nothing yet, neither the pack nor the index.
        empty_bucket = mock.patch.object(s3, "remote_sha256", return_value=None)

        with credentials, empty_bucket:
            exit_code, lines = self.upload("--dry-run")

        self.assertEqual(exit_code, 0)
        self.assertEqual(
            lines[:4],
            [
                f" would upload  packs/deutschland/photos/amsel.jpg  {len(PHOTO)} bytes",
                f" would upload  packs/deutschland/photos/star.jpg  {len(PHOTO)} bytes",
                " would upload  packs/deutschland/manifest.json  "
                f"{self.manifest_size('deutschland')} bytes",
                f" would upload  packs/index.json  {self.index_size()} bytes",
            ],
        )

    def test_lists_a_pack_the_bucket_already_holds(self) -> None:
        """The other half of the guard, through the command this time."""
        self.write_pack("alpen", "Vögel der Alpen", ["star"])
        credentials = mock.patch.object(
            s3, "client_from_env", return_value=(mock.sentinel.client, BUCKET)
        )
        holds_everything = mock.patch.object(s3, "remote_sha256", return_value="0" * 64)

        with credentials, holds_everything, self.staged_index() as staged:
            exit_code, _ = self.upload("--dry-run")

        self.assertEqual(exit_code, 0)
        self.assertEqual(self.listed(staged), ["alpen", "deutschland"])

    def test_lists_the_index_without_credentials(self) -> None:
        """Issue #15: a dry run works on a machine without S3 keys."""
        self.write_pack("alpen", "Vögel der Alpen", ["star"])

        with self.staged_index() as staged:
            exit_code, lines = self.upload("--dry-run")

        self.assertEqual(exit_code, 0)
        self.assertIn("unchecked  packs/index.json", lines[-1])
        # Nothing can be asked about `alpen`, so it stays out of the index.
        self.assertEqual(self.listed(staged), ["deutschland"])

    def test_writes_nothing_below_data_packs(self) -> None:
        """The licence gate and the credits generator read every *.json there."""
        self.upload("--dry-run")

        self.assertEqual(list(self.packs.rglob("index.json")), [])


if __name__ == "__main__":
    unittest.main()
