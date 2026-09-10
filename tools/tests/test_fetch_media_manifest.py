"""Tests for reading and writing the pack manifests.

The one that matters most is the round trip against the real
`data/packs/deutschland/manifest.json`: whatever the tool writes must differ from
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
                "photos": [media()],
                "call": None,
            }
        ],
    }
    pack.update(overrides)
    return pack


class RoundTripTests(unittest.TestCase):
    def test_the_bundled_manifest_survives_byte_for_byte(self) -> None:
        """The real file, not a fixture: this is the format the tool must keep."""
        path = manifest.manifest_path("deutschland")
        original = path.read_bytes()

        rewritten = manifest.dump(manifest.load(path)).encode("utf-8")

        self.assertEqual(rewritten, original)

    def test_keeps_non_ascii_names_readable(self) -> None:
        pack = document()
        pack["birds"][0]["photos"][0]["attribution"] = "Вячеслав Юсупов"

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
        bundled = json.loads(manifest.manifest_path("deutschland").read_text(encoding="utf-8"))

        self.assertEqual(list(bundled["birds"][0]["photos"][0]), list(manifest.MEDIA_KEYS))


class SetMediaTests(unittest.TestCase):
    def test_replaces_the_call_and_reports_the_previous_file(self) -> None:
        pack = document()
        pack["birds"][0]["call"] = media(file="audio/amsel.m4a")

        previous = manifest.set_media(pack, "amsel", "call", media(file="audio/amsel-neu.m4a"))

        self.assertEqual(previous, "audio/amsel.m4a")
        self.assertEqual(pack["birds"][0]["call"]["file"], "audio/amsel-neu.m4a")

    def test_refuses_the_photos_it_no_longer_owns(self) -> None:
        # A photo is added to a set, not set — `add_photo` is the way in.
        with self.assertRaises(ValueError) as error:
            manifest.set_media(document(), "amsel", "photo", media())

        self.assertIn("photo", str(error.exception))

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

        manifest.set_media(pack, "amsel", "call", media(file="audio/amsel.m4a"))

        self.assertEqual(
            list(pack["birds"][0]),
            [
                "id",
                "name",
                "scientificName",
                "taxonID",
                "article",
                "pronunciation",
                "photos",
                "call",
            ],
        )
        self.assertEqual(len(pack["birds"][0]["photos"]), 1)


class PhotoSetTests(unittest.TestCase):
    """A species carries a list of photos, and these are the ways in and out."""

    def test_adds_a_photo_after_the_ones_the_species_has(self) -> None:
        pack = document()

        manifest.add_photo(pack, "amsel", media(file="photos/amsel-2.png"))

        self.assertEqual(
            [photo["file"] for photo in pack["birds"][0]["photos"]],
            ["photos/amsel.png", "photos/amsel-2.png"],
        )

    def test_adds_to_a_species_whose_photos_are_null(self) -> None:
        # A manifest may carry `"photos": null` the way it carries a null call.
        pack = document()
        pack["birds"][0]["photos"] = None

        manifest.add_photo(pack, "amsel", media())

        self.assertEqual(len(pack["birds"][0]["photos"]), 1)

    def test_numbers_the_next_file_one_past_the_highest_in_use(self) -> None:
        pack = document()
        entry = pack["birds"][0]

        self.assertEqual(manifest.next_photo_file(entry, "amsel", "heic"), "photos/amsel-2.heic")

        manifest.add_photo(pack, "amsel", media(file="photos/amsel-2.heic"))
        manifest.add_photo(pack, "amsel", media(file="photos/amsel-7.heic"))

        self.assertEqual(manifest.next_photo_file(entry, "amsel", "heic"), "photos/amsel-8.heic")

    def test_names_the_first_photo_after_the_species_alone(self) -> None:
        pack = document()
        pack["birds"][0]["photos"] = []

        self.assertEqual(
            manifest.next_photo_file(pack["birds"][0], "amsel", "heic"), "photos/amsel.heic"
        )

    def test_a_dropped_number_is_not_handed_out_again(self) -> None:
        # It is in the bucket and possibly on a device: a second, different
        # photo under that name would be the one file whose content depends on
        # when it was fetched.
        pack = document()
        manifest.add_photo(pack, "amsel", media(file="photos/amsel-2.heic"))
        manifest.add_photo(pack, "amsel", media(file="photos/amsel-3.heic"))
        manifest.drop_photo(pack, "amsel", "photos/amsel-2.heic")

        self.assertEqual(
            manifest.next_photo_file(pack["birds"][0], "amsel", "heic"), "photos/amsel-4.heic"
        )

    def test_drops_one_photo_and_returns_it(self) -> None:
        pack = document()
        manifest.add_photo(pack, "amsel", media(file="photos/amsel-2.png", attribution="Somebody"))

        gone = manifest.drop_photo(pack, "amsel", "photos/amsel-2.png")

        self.assertEqual(gone["attribution"], "Somebody")
        self.assertEqual([photo["file"] for photo in pack["birds"][0]["photos"]], ["photos/amsel.png"])

    def test_refuses_to_drop_the_last_photo(self) -> None:
        with self.assertRaises(ValueError) as error:
            manifest.drop_photo(document(), "amsel", "photos/amsel.png")

        self.assertIn("only photo", str(error.exception))

    def test_reports_a_photo_the_species_does_not_have(self) -> None:
        with self.assertRaises(LookupError) as error:
            manifest.drop_photo(document(), "amsel", "photos/kohlmeise.png")

        self.assertIn("photos/amsel.png", str(error.exception))

    def test_reports_an_unknown_bird_with_the_ones_it_knows(self) -> None:
        with self.assertRaises(LookupError) as error:
            manifest.bird(document(), "wiedehopf")

        self.assertIn("amsel", str(error.exception))


class SetSpeechTests(unittest.TestCase):
    def clip(self) -> dict:
        return manifest.speech_block(
            file="speech/collection.name/amsel.m4a", sha256="0" * 64, text="Amsel"
        )

    def test_fills_a_speech_map_that_a_manifest_declared_as_null(self) -> None:
        """A bird may carry `"speech": null` the way it carries `"call": null`."""
        pack = document()
        pack["birds"][0]["speech"] = None

        previous = manifest.set_speech(pack, "amsel", "collection.name", self.clip())

        self.assertIsNone(previous)
        self.assertEqual(pack["birds"][0]["speech"]["collection.name"]["text"], "Amsel")

    def test_fills_a_lines_map_that_the_fixed_set_declared_as_null(self) -> None:
        fixed = {"id": "speech", "title": "Ansagen", "lines": None}

        manifest.set_speech(fixed, None, "roundEnd.title", self.clip())

        self.assertEqual(list(fixed["lines"]), ["roundEnd.title"])

    def test_reports_the_recording_it_replaced(self) -> None:
        pack = document()
        manifest.set_speech(pack, "amsel", "collection.name", self.clip())

        previous = manifest.set_speech(
            pack, "amsel", "collection.name", {**self.clip(), "file": "speech/other.m4a"}
        )

        self.assertEqual(previous, "speech/collection.name/amsel.m4a")


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

    def test_lists_every_photo_of_a_species(self) -> None:
        # What makes the second photo reach the bucket and count towards the
        # download size: a photo that is not in this list is a tile the app
        # would name and never find.
        pack = document()
        manifest.add_photo(pack, "amsel", media(file="photos/amsel-2.png", sha256="3" * 64))

        self.assertEqual(
            manifest.media_files(pack),
            [("photos/amsel.png", "0" * 64), ("photos/amsel-2.png", "3" * 64)],
        )

    def test_lists_the_speech_clips_after_the_bird_s_own_media(self) -> None:
        # What makes `fetch-media upload` carry them: a clip that is not in
        # this list never reaches the bucket, and the downloaded pack is silent.
        pack = document()
        pack["birds"][0]["speech"] = {
            "quiz.prompt.whereIs": {
                "file": "speech/quiz.prompt.whereIs/amsel.m4a",
                "sha256": "2" * 64,
                "text": "Wo ist die Amsel?",
            }
        }

        self.assertEqual(
            manifest.media_files(pack),
            [("photos/amsel.png", "0" * 64), ("speech/quiz.prompt.whereIs/amsel.m4a", "2" * 64)],
        )

    def test_lists_a_file_two_sentences_share_only_once(self) -> None:
        # A species whose name is a sentence of its own can carry the same
        # recording under two keys. The downloader fetches each file once, so
        # uploading it twice would make the size and the progress disagree.
        pack = document()
        clip = {"file": "speech/amsel.m4a", "sha256": "2" * 64, "text": "Amsel"}
        pack["birds"][0]["speech"] = {"collection.name": clip, "quiz.answer.name": dict(clip)}

        self.assertEqual(
            manifest.media_files(pack),
            [("photos/amsel.png", "0" * 64), ("speech/amsel.m4a", "2" * 64)],
        )

    def test_refuses_to_set_speech_as_if_it_were_a_medium(self) -> None:
        # Speech nests one level deeper and carries no licence of its own, so
        # `set_media` must not be the way it is written.
        with self.assertRaises(ValueError) as error:
            manifest.set_media(document(), "amsel", manifest.SPEECH_KIND, media())

        self.assertIn("speech", str(error.exception))


if __name__ == "__main__":
    unittest.main()
