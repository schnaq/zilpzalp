"""Tests for reading and writing the pack manifests.

The one that matters most is the round trip against the real
`data/packs/basis/manifest.json`: whatever the tool writes must differ from
what it read only in the medium that actually changed.

Run from the repository root:
uv run --locked --project tools python -m unittest discover -s tools/tests -t tools
"""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

from fetch_media import manifest


def media(**overrides) -> dict:
    """A media object as the manifest spells it."""
    block = manifest.media_block(
        file="photos/amsel.png",
        sha256="0" * 64,
        licence="CC-BY-4.0",
        attribution="Alexis Tinker-Tsavalas",
        source_url="https://www.inaturalist.org/observations/20490738",
        retrieved="2026-07-31",
    )
    block.update(overrides)
    return block


def document(**overrides) -> dict:
    """A one-bird pack."""
    pack = {
        "id": "basis",
        "title": "Unsere ersten Vögel",
        "birds": [
            {
                "id": "amsel",
                "name": "Amsel",
                "scientificName": "Turdus merula",
                "taxonID": 12716,
                "article": "die",
                "pronunciation": None,
                "photo": media(),
                "call": None,
            }
        ],
    }
    pack.update(overrides)
    return pack


class RoundTripTests(unittest.TestCase):
    def test_the_bundled_manifest_survives_byte_for_byte(self) -> None:
        """The real file, not a fixture: this is the format the tool must keep."""
        path = manifest.manifest_path("basis")
        original = path.read_bytes()

        rewritten = manifest.dump(manifest.load(path)).encode("utf-8")

        self.assertEqual(rewritten, original)

    def test_keeps_non_ascii_names_readable(self) -> None:
        pack = document()
        pack["birds"][0]["photo"]["attribution"] = "Вячеслав Юсупов"

        self.assertIn("Вячеслав Юсупов", manifest.dump(pack))

    def test_writes_two_space_indent_and_a_final_newline(self) -> None:
        text = manifest.dump(document())

        self.assertTrue(text.startswith('{\n  "id": "basis",\n'))
        self.assertTrue(text.endswith("}\n"))

    def test_saves_and_reads_back(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            manifest.save(path, document())

            self.assertEqual(manifest.load(path), document())

    def test_rejects_a_manifest_that_is_not_an_object(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "manifest.json"
            path.write_text("[]", encoding="utf-8")

            with self.assertRaises(ValueError):
                manifest.load(path)


class MediaBlockTests(unittest.TestCase):
    def test_holds_the_keys_in_the_manifest_order(self) -> None:
        self.assertEqual(list(media()), list(manifest.MEDIA_KEYS))

    def test_matches_the_bundled_manifest(self) -> None:
        """The order the repository already carries, so a diff stays small."""
        bundled = json.loads(manifest.manifest_path("basis").read_text(encoding="utf-8"))

        self.assertEqual(list(bundled["birds"][0]["photo"]), list(manifest.MEDIA_KEYS))


class SetMediaTests(unittest.TestCase):
    def test_replaces_the_photo_and_reports_the_previous_file(self) -> None:
        pack = document()

        previous = manifest.set_media(pack, "amsel", "photo", media(file="photos/amsel.jpg"))

        self.assertEqual(previous, "photos/amsel.png")
        self.assertEqual(pack["birds"][0]["photo"]["file"], "photos/amsel.jpg")

    def test_fills_a_call_that_was_null_and_reports_no_previous_file(self) -> None:
        pack = document()

        previous = manifest.set_media(pack, "amsel", "call", media(file="audio/amsel.m4a"))

        self.assertIsNone(previous)
        self.assertEqual(pack["birds"][0]["call"]["file"], "audio/amsel.m4a")

    def test_refuses_a_kind_that_is_not_a_medium(self) -> None:
        with self.assertRaises(ValueError) as error:
            manifest.set_media(document(), "amsel", "sonogram", media())

        self.assertIn("sonogram", str(error.exception))

    def test_leaves_the_bird_s_other_fields_and_their_order_alone(self) -> None:
        pack = document()

        manifest.set_media(pack, "amsel", "photo", media(file="photos/amsel.jpg"))

        self.assertEqual(
            list(pack["birds"][0]),
            ["id", "name", "scientificName", "taxonID", "article", "pronunciation", "photo", "call"],
        )
        self.assertIsNone(pack["birds"][0]["call"])

    def test_reports_an_unknown_bird_with_the_ones_it_knows(self) -> None:
        with self.assertRaises(LookupError) as error:
            manifest.bird(document(), "wiedehopf")

        self.assertIn("amsel", str(error.exception))


class MediaFilesTests(unittest.TestCase):
    def test_lists_photo_and_call_in_manifest_order(self) -> None:
        pack = document()
        pack["birds"][0]["call"] = media(file="audio/amsel.mp3", sha256="1" * 64)

        self.assertEqual(
            manifest.media_files(pack),
            [("photos/amsel.png", "0" * 64), ("audio/amsel.mp3", "1" * 64)],
        )

    def test_skips_a_bird_without_a_call(self) -> None:
        self.assertEqual(manifest.media_files(document()), [("photos/amsel.png", "0" * 64)])


if __name__ == "__main__":
    unittest.main()
