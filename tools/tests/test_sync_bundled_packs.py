"""Tests for the bundled pack sync.

Run from the repository root:
python3 -m unittest discover -s tools/tests -t tools
"""

from __future__ import annotations

import contextlib
import io
import shutil
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import sync_bundled_packs


class SyncTestCase(unittest.TestCase):
    """Base class providing a throwaway pack and the directory it mirrors into."""

    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        root = Path(directory.name)

        # The shape the repository has: a packs directory holding one pack,
        # and a resource directory that is to mirror it.
        self.source_dir = root / "data"
        self.bundle_dir = root / "bundle"
        self.source = self.source_dir / "basis"
        self.destination = self.bundle_dir / "basis"

        (self.source / "photos").mkdir(parents=True)
        (self.source / "manifest.json").write_text('{"id": "basis"}', encoding="utf-8")
        (self.source / "photos" / "amsel.png").write_bytes(b"a photo")

    def sync(self) -> list[str]:
        return sync_bundled_packs.sync(self.source, self.destination)

    def run_main(self) -> int:
        """Run main() against the throwaway directories, output suppressed."""
        with (
            mock.patch.object(sync_bundled_packs, "SOURCE_DIR", self.source_dir),
            mock.patch.object(sync_bundled_packs, "BUNDLE_DIR", self.bundle_dir),
            mock.patch.object(sync_bundled_packs, "BUNDLED_PACKS", ("basis",)),
            contextlib.redirect_stdout(io.StringIO()),
        ):
            return sync_bundled_packs.main()


class SyncCreatesTheCopy(SyncTestCase):
    def test_reports_a_missing_destination_and_creates_it(self) -> None:
        changed = self.sync()

        self.assertEqual(changed, ["(the whole pack)"])
        self.assertEqual((self.destination / "photos" / "amsel.png").read_bytes(), b"a photo")

    def test_a_second_run_reports_nothing(self) -> None:
        self.sync()

        self.assertEqual(self.sync(), [])

    def test_a_hidden_file_is_not_copied(self) -> None:
        (self.source / ".DS_Store").write_bytes(b"finder")

        self.sync()

        self.assertFalse((self.destination / ".DS_Store").exists())


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

    def test_a_hidden_file_is_not_drift(self) -> None:
        # Finder drops .DS_Store into any directory somebody opens. It is
        # git-ignored, so treating it as drift would fail CI over nothing.
        (self.source / ".DS_Store").write_bytes(b"finder")

        self.assertEqual(self.sync(), [])
        self.assertFalse((self.destination / ".DS_Store").exists())


class SyncRefusesAMissingSource(SyncTestCase):
    def test_a_source_that_is_not_there_raises(self) -> None:
        with self.assertRaises(FileNotFoundError):
            sync_bundled_packs.sync(self.source / "nowhere", self.destination)


class MainIsTheCIContract(SyncTestCase):
    """The exit code is what `mise run check` — and with it CI — acts on."""

    def test_a_missing_copy_exits_1_and_is_healed(self) -> None:
        self.assertEqual(self.run_main(), 1)
        self.assertTrue((self.destination / "manifest.json").is_file())

    def test_a_current_copy_exits_0(self) -> None:
        self.run_main()

        self.assertEqual(self.run_main(), 0)

    def test_a_missing_source_exits_1(self) -> None:
        shutil.rmtree(self.source)

        self.assertEqual(self.run_main(), 1)


class BundledPacksMatchTheRepository(unittest.TestCase):
    """The paths in the script are only right as long as the repository agrees."""

    def test_every_bundled_pack_exists_in_data_packs(self) -> None:
        for pack in sync_bundled_packs.BUNDLED_PACKS:
            self.assertTrue((sync_bundled_packs.SOURCE_DIR / pack).is_dir(), pack)


if __name__ == "__main__":
    unittest.main()
