"""Tests for the sentences the app says out loud.

Nothing here reaches a vendor, and nothing reaches the repository: every test
works on a throwaway pack, a throwaway fixed set and a throwaway String
Catalog. The only provider that exists is `fake`, which produces tones — the
rule `tools/tests/` already follows for iNaturalist and xeno-canto.

Run from the repository root:
uv run --locked --project tools python -m unittest discover -s tools/tests -t tools
"""

from __future__ import annotations

import array
import contextlib
import io
import json
import tempfile
import unittest
import wave
from pathlib import Path
from unittest import mock

from fetch_media import audio, cli, manifest, speech
from fetch_media.speech import clips, fake, sentences

# The three keys the base pack's species sentences use, as the app's own
# catalogue spells them, plus the one that cannot become a clip.
CATALOG = {
    "sourceLanguage": "de",
    "strings": {
        "quiz.prompt.whereIs": {
            "localizations": {"de": {"stringUnit": {"state": "translated", "value": "Wo ist %1$@ %2$@?"}}}
        },
        "roundEnd.sticker.new.spoken": {
            "localizations": {
                "de": {"stringUnit": {"state": "translated", "value": "Super gemacht! %@ gesammelt!"}}
            }
        },
        "roundEnd.title": {
            "localizations": {"de": {"stringUnit": {"state": "translated", "value": "Super gemacht!"}}}
        },
        "timeBudget.starsToday.spoken": {
            "localizations": {
                "de": {
                    "variations": {
                        "plural": {
                            "other": {
                                "stringUnit": {
                                    "state": "translated",
                                    "value": "Heute hast du %lld Sterne gesammelt.",
                                }
                            }
                        }
                    }
                }
            }
        },
        "collection.birds": {"localizations": {}},
    },
}

AMSEL = {
    "id": "amsel",
    "name": "Amsel",
    "scientificName": "Turdus merula",
    "taxonID": 12716,
    "article": "die",
    "pronunciation": None,
    "photo": None,
    "call": None,
}

STAR = {**AMSEL, "id": "star", "name": "Star", "scientificName": "Sturnus vulgaris", "article": "der"}


class SentenceTests(unittest.TestCase):
    """What a clip says, and where the words come from."""

    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        catalog = Path(directory.name) / "Localizable.xcstrings"
        catalog.write_text(json.dumps(CATALOG), encoding="utf-8")
        mock.patch.object(sentences, "CATALOG", catalog).start()
        self.addCleanup(mock.patch.stopall)

    def test_fills_the_positional_placeholders_as_the_app_does(self) -> None:
        self.assertEqual(sentences.species_text(AMSEL, "quiz.prompt.whereIs"), "Wo ist die Amsel?")
        self.assertEqual(sentences.species_text(STAR, "quiz.prompt.whereIs"), "Wo ist der Star?")

    def test_fills_the_unpositional_one(self) -> None:
        self.assertEqual(
            sentences.species_text(AMSEL, "roundEnd.sticker.new.spoken"),
            "Super gemacht! Amsel gesammelt!",
        )

    def test_says_the_bare_name_where_the_app_has_no_key(self) -> None:
        """`collection.name` is Task 5's to add; until then the name is the sentence."""
        self.assertEqual(sentences.species_text(AMSEL, "collection.name"), "Amsel")

    def test_prefers_the_pronunciation_the_manifest_carries(self) -> None:
        odd = {**AMSEL, "name": "Zilpzalp", "pronunciation": "Zilp Zalp"}

        self.assertEqual(sentences.species_text(odd, "collection.name"), "Zilp Zalp")

    def test_refuses_a_sentence_that_belongs_to_no_species(self) -> None:
        with self.assertRaises(LookupError) as error:
            sentences.species_text(AMSEL, "roundEnd.title")

        self.assertIn("not a species sentence", str(error.exception))

    def test_reads_a_fixed_sentence_as_the_catalogue_has_it(self) -> None:
        self.assertEqual(sentences.fixed_text("roundEnd.title"), "Super gemacht!")

    def test_refuses_the_one_sentence_that_speaks_a_number(self) -> None:
        """Decision 4: one clip cannot say „7 Sterne" and „8 Sterne"."""
        with self.assertRaises(ValueError) as error:
            sentences.fixed_text("timeBudget.starsToday.spoken")

        self.assertIn("plural", str(error.exception))

    def test_refuses_a_key_the_catalogue_does_not_have(self) -> None:
        for key in ("nonsense.key", "collection.birds"):
            with self.subTest(key=key), self.assertRaises(LookupError):
                sentences.fixed_text(key)

    def test_refuses_a_placeholder_it_cannot_fill(self) -> None:
        with self.assertRaises(ValueError):
            sentences.fill("Heute hast du %lld Sterne gesammelt.")
        with self.assertRaises(ValueError):
            sentences.fill("Wo ist %1$@ %2$@?", "die")

    def test_refuses_an_argument_number_that_is_not_one(self) -> None:
        """`String(format:)` counts from 1; %0$@ would silently take the last."""
        with self.assertRaises(ValueError):
            sentences.fill("Wo ist %0$@?", "die", "Amsel")


class RealCatalogTests(unittest.TestCase):
    """One assertion against the catalogue the app actually ships."""

    def test_the_question_of_game_one_reads_as_the_app_speaks_it(self) -> None:
        self.assertEqual(sentences.species_text(AMSEL, "quiz.prompt.whereIs"), "Wo ist die Amsel?")


class ProviderTests(unittest.TestCase):
    def test_the_only_adapter_is_the_one_that_reaches_nobody(self) -> None:
        """Until decisions 1 and 2 are answered there is no vendor to reach."""
        self.assertEqual(sorted(speech.PROVIDERS), ["fake"])

    def test_names_what_it_has_when_asked_for_something_else(self) -> None:
        with self.assertRaises(LookupError) as error:
            speech.provider("elevenlabs")

        self.assertIn("fake", str(error.exception))

    def test_the_fake_provider_is_deterministic(self) -> None:
        """A test can then ask whether a re-render changed anything."""
        provider = speech.provider("fake")

        self.assertEqual(provider.render("Wo ist die Amsel?"), provider.render("Wo ist die Amsel?"))
        self.assertNotEqual(provider.render("Amsel"), provider.render("Star"))

    def test_it_returns_a_wav_the_encoder_can_read(self) -> None:
        """The contract every adapter has to keep — see speech/provider.py."""
        rendered = speech.provider("fake").render("Amsel")

        with wave.open(io.BytesIO(rendered), "rb") as handle:
            self.assertEqual(handle.getnchannels(), 1)
            self.assertEqual(handle.getsampwidth(), audio.SAMPLE_WIDTH)
            self.assertGreater(handle.getnframes(), 0)

    def test_it_leaves_room_for_the_trim_and_the_normaliser(self) -> None:
        """Silence at both ends, and a level well below the target."""
        with wave.open(io.BytesIO(speech.provider("fake").render("Amsel")), "rb") as handle:
            frames = array.array(audio.SAMPLE_TYPE)
            frames.frombytes(handle.readframes(handle.getnframes()))
            rate = handle.getframerate()

        self.assertEqual(frames[0], 0)
        self.assertEqual(frames[-1], 0)
        self.assertLess(audio.loudness(frames, rate), audio.TARGET)

    def test_it_licenses_what_it_produces(self) -> None:
        voice = speech.provider("fake").voice()

        self.assertEqual(voice.license, "CC0-1.0")
        self.assertTrue(voice.attribution)
        self.assertTrue(voice.source_url)


class StoreTests(unittest.TestCase):
    def test_refuses_to_write_outside_the_directory_it_was_given(self) -> None:
        """A manifest that names `../../something` is broken, not permission."""
        with tempfile.TemporaryDirectory() as directory:
            with self.assertRaises(ValueError) as error:
                cli.store(Path(directory) / "pack", "../escaped.m4a", b"nothing")

            self.assertIn("outside", str(error.exception))
            self.assertFalse((Path(directory) / "escaped.m4a").exists())


class TargetTests(unittest.TestCase):
    def test_a_species_sentence_lives_under_its_key(self) -> None:
        target = clips.Target(directory=Path("/p"), path=Path("/p/manifest.json"), bird_id="amsel")

        self.assertEqual(
            target.file("quiz.prompt.whereIs"), "speech/quiz.prompt.whereIs/amsel.m4a"
        )
        self.assertEqual(target.label, "amsel")

    def test_a_fixed_sentence_lives_beside_its_manifest(self) -> None:
        target = clips.Target(directory=Path("/s"), path=Path("/s/manifest.json"), bird_id=None)

        self.assertEqual(target.file("roundEnd.title"), "roundEnd.title.m4a")
        self.assertEqual(target.label, "fixed")


class SpeechTestCase(unittest.TestCase):
    """A throwaway two-bird pack and a throwaway fixed set."""

    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        root = Path(directory.name)

        self.packs = root / "packs"
        self.pack = self.packs / "basis"
        self.pack.mkdir(parents=True)
        manifest.save(
            self.pack / "manifest.json",
            {"id": "basis", "title": "Unsere ersten Vögel", "birds": [dict(AMSEL), dict(STAR)]},
        )

        self.fixed = root / "speech"
        self.fixed.mkdir()
        manifest.save(
            self.fixed / "manifest.json", {"id": "speech", "title": "Ansagen", "lines": {}}
        )

        catalog = root / "Localizable.xcstrings"
        catalog.write_text(json.dumps(CATALOG), encoding="utf-8")

        mock.patch.object(manifest, "PACKS_DIR", self.packs).start()
        mock.patch.object(manifest, "SPEECH_DIR", self.fixed).start()
        mock.patch.object(sentences, "CATALOG", catalog).start()
        # The derived files have their own tools' tests, and running them here
        # would write into the repository.
        self.derived = mock.patch.object(cli, "regenerate_derived").start()
        self.addCleanup(mock.patch.stopall)

    def run_command(self, arguments: list[str]) -> tuple[int, str]:
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = cli.main(arguments)
        return code, output.getvalue()

    def render(self, *arguments: str) -> tuple[int, str]:
        return self.run_command(["speech", "render", "--provider", "fake", *arguments])

    def document(self) -> dict:
        return manifest.load(self.pack / "manifest.json")

    def clips_of(self, bird_id: str) -> dict:
        return manifest.bird(self.document(), bird_id).get("speech") or {}

    def take(self) -> Path:
        """A take somebody recorded — tones, so that nothing unheard is real."""
        path = self.pack.parent / "take.wav"
        path.write_bytes(fake.FakeProvider().render("Wo ist die Amsel?"))
        return path


class RenderTests(SpeechTestCase):
    def test_writes_the_clip_the_entry_and_the_voice(self) -> None:
        code, printed = self.render("--pack", "basis", "--species", "amsel")

        self.assertEqual(code, 0)
        entry = self.clips_of("amsel")["quiz.prompt.whereIs"]
        self.assertEqual(entry["file"], "speech/quiz.prompt.whereIs/amsel.m4a")
        self.assertEqual(entry["text"], "Wo ist die Amsel?")
        self.assertEqual(list(entry), list(manifest.SPEECH_KEYS))

        clip = self.pack / entry["file"]
        self.assertEqual(entry["sha256"], manifest.sha256_of(clip))
        self.assertIn(b"ftyp", clip.read_bytes()[:12])

        voice = self.document()["voice"]
        self.assertEqual(voice["license"], "CC0-1.0")
        self.assertEqual(list(voice), list(manifest.VOICE_KEYS))
        self.assertIn("Listen to every clip", printed)

    def test_the_voice_sits_where_the_schema_shows_it(self) -> None:
        self.render("--pack", "basis", "--species", "amsel")

        self.assertEqual(list(self.document()), ["id", "title", "voice", "birds"])

    def test_renders_every_species_sentence_by_default(self) -> None:
        self.render("--pack", "basis", "--species", "amsel")

        self.assertEqual(list(self.clips_of("amsel")), list(sentences.SPECIES_SENTENCES))

    def test_renders_one_sentence_when_one_is_named(self) -> None:
        self.render("--pack", "basis", "--sentence", "collection.name")

        self.assertEqual(list(self.clips_of("amsel")), ["collection.name"])
        self.assertEqual(list(self.clips_of("star")), ["collection.name"])

    def test_re_rendering_one_species_touches_one_clip_and_one_entry(self) -> None:
        self.render("--pack", "basis", "--sentence", "collection.name")
        untouched = {
            path: path.read_bytes() for path in sorted(self.pack.rglob("*.m4a")) if "star" in path.name
        }
        before = self.clips_of("star")["collection.name"]

        self.render("--pack", "basis", "--species", "amsel", "--sentence", "collection.name")

        self.assertEqual(
            {path: path.read_bytes() for path in untouched}, untouched, "the star's clip changed"
        )
        self.assertEqual(self.clips_of("star")["collection.name"], before)
        self.assertEqual(len(list(self.pack.rglob("*.m4a"))), 2)
        self.assertEqual(
            self.clips_of("amsel")["collection.name"]["sha256"],
            manifest.sha256_of(self.pack / "speech" / "collection.name" / "amsel.m4a"),
        )

    def test_leaves_the_date_of_a_voice_that_has_not_changed(self) -> None:
        """A re-render is not a new voice, and must not show up as one."""
        self.render("--pack", "basis", "--species", "amsel")
        aged = self.document()
        aged["voice"]["retrieved"] = "2026-01-01"
        manifest.save(self.pack / "manifest.json", aged)

        self.render("--pack", "basis", "--species", "amsel")

        self.assertEqual(self.document()["voice"]["retrieved"], "2026-01-01")

    def test_writes_a_fixed_sentence_beside_its_own_manifest(self) -> None:
        code, _ = self.render("--set", "fixed", "--sentence", "roundEnd.title")

        self.assertEqual(code, 0)
        document = manifest.load(self.fixed / "manifest.json")
        entry = document["lines"]["roundEnd.title"]
        self.assertEqual(entry["file"], "roundEnd.title.m4a")
        self.assertEqual(entry["text"], "Super gemacht!")
        self.assertEqual(entry["sha256"], manifest.sha256_of(self.fixed / "roundEnd.title.m4a"))
        self.assertEqual(list(document), ["id", "title", "voice", "lines"])

    def test_regenerates_the_derived_files(self) -> None:
        self.render("--pack", "basis", "--species", "amsel")

        self.derived.assert_called_once_with()

    def test_normalises_what_it_records(self) -> None:
        """A sentence and a call have to sit at one loudness (#148)."""
        code, printed = self.render("--pack", "basis", "--sentence", "collection.name")

        self.assertEqual(code, 0)
        self.assertIn(f"{audio.TARGET:.1f} dBFS", printed)

    def test_refuses_a_species_the_pack_does_not_have(self) -> None:
        code, printed = self.render("--pack", "basis", "--species", "wiedehopf")

        self.assertEqual(code, 1)
        self.assertIn("::error::", printed)
        self.assertEqual(list(self.pack.rglob("*.m4a")), [])

    def test_refuses_a_sentence_before_it_produces_anything(self) -> None:
        """With a paid provider this is the difference between a typo and a bill."""
        code, _ = self.render("--pack", "basis", "--sentence", "collection.name", "nonsense.key")

        self.assertEqual(code, 1)
        self.assertEqual(list(self.pack.rglob("*.m4a")), [])

    def test_refuses_a_species_for_the_fixed_set(self) -> None:
        code, printed = self.render(
            "--set", "fixed", "--sentence", "roundEnd.title", "--species", "amsel"
        )

        self.assertEqual(code, 1)
        self.assertIn("no species", printed)

    def test_refuses_another_voice_before_it_renders_anything(self) -> None:
        """With a paid provider, after the first clip would already be a bill."""
        self.run_command(
            [
                "speech",
                "import",
                "--pack",
                "basis",
                "--species",
                "amsel",
                "--sentence",
                "collection.name",
                "--file",
                str(self.take()),
                "--attribution",
                "Stimme: Johanna",
            ]
        )

        with mock.patch.object(fake.FakeProvider, "render", autospec=True) as rendered:
            code, printed = self.render("--pack", "basis", "--species", "star")

        self.assertEqual(code, 1)
        self.assertIn("one voice", printed)
        rendered.assert_not_called()
        self.assertEqual(self.clips_of("star"), {})
        self.assertEqual(self.document()["voice"]["attribution"], "Stimme: Johanna")

    def test_refuses_the_fixed_set_without_a_sentence(self) -> None:
        code, printed = self.render("--set", "fixed")

        self.assertEqual(code, 1)
        self.assertIn("--sentence", printed)


class ImportTests(SpeechTestCase):
    def run_import(
        self, *arguments: str, file: Path | None = None, attribution: str = "Stimme: Johanna"
    ) -> tuple[int, str]:
        return self.run_command(
            [
                "speech",
                "import",
                "--file",
                str(file or self.take()),
                "--attribution",
                attribution,
                *arguments,
            ]
        )

    def test_records_a_take_the_way_a_call_is_recorded(self) -> None:
        code, printed = self.run_import(
            "--pack", "basis", "--species", "amsel", "--sentence", "quiz.prompt.whereIs"
        )

        self.assertEqual(code, 0)
        entry = self.clips_of("amsel")["quiz.prompt.whereIs"]
        self.assertEqual(entry["text"], "Wo ist die Amsel?")
        self.assertEqual(entry["sha256"], manifest.sha256_of(self.pack / entry["file"]))
        self.assertIn(f"{audio.TARGET:.1f} dBFS", printed)

    def test_credits_the_voice_the_command_names(self) -> None:
        self.run_import(
            "--pack", "basis", "--species", "amsel", "--sentence", "quiz.prompt.whereIs"
        )

        voice = self.document()["voice"]
        self.assertEqual(voice["attribution"], "Stimme: Johanna")
        self.assertEqual(voice["license"], speech.IMPORT_LICENCE)
        self.assertEqual(voice["sourceURL"], speech.RECORDING_DOC)

    def test_imports_a_fixed_sentence_too(self) -> None:
        code, _ = self.run_import("--set", "fixed", "--sentence", "roundEnd.title")

        self.assertEqual(code, 0)
        document = manifest.load(self.fixed / "manifest.json")
        self.assertEqual(document["lines"]["roundEnd.title"]["text"], "Super gemacht!")
        self.assertEqual(document["voice"]["attribution"], "Stimme: Johanna")

    def test_refuses_a_second_voice_in_one_manifest(self) -> None:
        """Thirty clips would otherwise carry the licence of the thirty-first."""
        self.run_import(
            "--pack", "basis", "--species", "amsel", "--sentence", "quiz.prompt.whereIs"
        )

        code, printed = self.run_import(
            "--pack",
            "basis",
            "--species",
            "star",
            "--sentence",
            "quiz.prompt.whereIs",
            attribution="Stimme: jemand anderes",
        )

        self.assertEqual(code, 1)
        self.assertIn("one voice", printed)
        self.assertEqual(self.clips_of("star"), {})
        self.assertEqual(self.document()["voice"]["attribution"], "Stimme: Johanna")

    def test_refuses_a_pack_without_a_species(self) -> None:
        code, printed = self.run_import("--pack", "basis", "--sentence", "quiz.prompt.whereIs")

        self.assertEqual(code, 1)
        self.assertIn("--species", printed)

    def test_reports_a_take_afconvert_cannot_read(self) -> None:
        broken = self.pack.parent / "broken.wav"
        broken.write_bytes(b"not a wav at all")

        code, printed = self.run_import(
            "--pack", "basis", "--species", "amsel", "--sentence", "collection.name", file=broken
        )

        self.assertEqual(code, 1)
        self.assertIn("::error::", printed)
        self.assertEqual(self.clips_of("amsel"), {})


if __name__ == "__main__":
    unittest.main()
