"""Tests for the bundled pack sync.

Run from the repository root:
python3 -m unittest discover -s tools/tests -t tools
"""

from __future__ import annotations

import tempfile
import unittest
from pathlib import Path

import sync_bundled_packs


class SyncTestCase(unittest.TestCase):
    """Base class providing a source and a destination pack directory."""

    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        root = Path(directory.name)

        self.source = root / "source"
        self.destination = root / "destination"
        (self.source / "photos").mkdir(parents=True)
        (self.source / "manifest.json").write_text('{"id": "basis"}', encoding="utf-8")
        (self.source / "photos" / "amsel.png").write_bytes(b"a photo")

    def sync(self) -> list[str]:
        return sync_bundled_packs.sync(self.source, self.destination)


class SyncCreatesTheCopy(SyncTestCase):
    def test_reports_a_missing_destination_and_creates_it(self) -> None:
        changed = self.sync()

        self.assertEqual(changed, ["(the whole pack)"])
        self.assertEqual(
            (self.destination / "photos" / "amsel.png").read_bytes(), b"a photo"
        )

    def test_a_second_run_reports_nothing(self) -> None:
        self.sync()

        self.assertEqual(self.sync(), [])


class SyncHealsDrift(SyncTestCase):
    def setUp(self) -> None:
        super().setUp()
        self.sync()

    def test_changed_content_is_reported_and_replaced(self) -> None:
        (self.source / "photos" / "amsel.png").write_bytes(b"a better photo")

        changed = self.sync()

        self.assertEqual(changed, ["photos/amsel.png"])
        self.assertEqual(
            (self.destination / "photos" / "amsel.png").read_bytes(), b"a better photo"
        )

    def test_an_added_file_is_reported_and_copied(self) -> None:
        (self.source / "photos" / "star.png").write_bytes(b"another photo")

        self.assertEqual(self.sync(), ["photos/star.png"])
        self.assertTrue((self.destination / "photos" / "star.png").is_file())

    def test_a_removed_file_is_reported_and_deleted(self) -> None:
        (self.source / "photos" / "amsel.png").unlink()

        self.assertEqual(self.sync(), ["photos/amsel.png"])
        self.assertFalse((self.destination / "photos" / "amsel.png").exists())

    def test_a_file_only_in_the_destination_is_removed(self) -> None:
        (self.destination / "photos" / "leftover.png").write_bytes(b"stale")

        self.assertEqual(self.sync(), ["photos/leftover.png"])
        self.assertFalse((self.destination / "photos" / "leftover.png").exists())

    def test_equal_content_is_not_drift_even_with_fresh_timestamps(self) -> None:
        # A checkout gives every file the same fresh mtime. Comparing anything
        # but the bytes would report drift that is not there.
        (self.source / "photos" / "amsel.png").write_bytes(b"a photo")

        self.assertEqual(self.sync(), [])


class SyncRefusesAMissingSource(SyncTestCase):
    def test_a_source_that_is_not_there_raises(self) -> None:
        with self.assertRaises(FileNotFoundError):
            sync_bundled_packs.sync(self.source / "nowhere", self.destination)


class BundledPacksMatchTheRepository(unittest.TestCase):
    """The paths in the script are only right as long as the repository agrees."""

    def test_every_bundled_pack_exists_in_data_packs(self) -> None:
        for pack in sync_bundled_packs.BUNDLED_PACKS:
            self.assertTrue((sync_bundled_packs.SOURCE_DIR / pack).is_dir(), pack)


if __name__ == "__main__":
    unittest.main()
