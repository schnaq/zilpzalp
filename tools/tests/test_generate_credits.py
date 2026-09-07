"""Tests for the credits generator.

Run from the repository root:
python3 -m unittest discover -s tools/tests -t tools
"""

from __future__ import annotations

import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import generate_credits


def media(**overrides) -> dict:
    """A media object as the manifest spells it, with fields replaced."""
    asset = {
        "file": "photos/amsel.png",
        "sha256": "0" * 64,
        "license": "CC-BY-4.0",
        "attribution": "Alexis Tinker-Tsavalas",
        "sourceURL": "https://www.inaturalist.org/observations/1",
        "retrieved": "2026-07-31",
    }
    asset.update(overrides)
    return asset


def bird(**overrides) -> dict:
    """A bird entry, with the given fields replaced or removed."""
    entry = {
        "id": "amsel",
        "name": "Amsel",
        "scientificName": "Turdus merula",
        "taxonID": 12716,
        "article": "die",
        "pronunciation": None,
        "photo": media(),
        "call": None,
    }
    entry.update(overrides)
    return {key: value for key, value in entry.items() if value is not None or key == "call"}


class CreditsTestCase(unittest.TestCase):
    """Base class providing a throwaway packs directory and two output paths."""

    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        root = Path(directory.name)

        self.packs_dir = root / "packs"
        self.packs_dir.mkdir()
        self.markdown = root / "CREDITS.md"
        self.json = root / "credits.json"

    def write_pack(self, pack_id: str, birds: list[dict], title: str = "Unsere ersten Vögel") -> None:
        pack = self.packs_dir / pack_id
        pack.mkdir(parents=True, exist_ok=True)
        document = {"id": pack_id, "title": title, "birds": birds}
        (pack / "manifest.json").write_text(json.dumps(document, ensure_ascii=False), encoding="utf-8")

    def run_main(self) -> int:
        """Run main() against the throwaway paths, output suppressed."""
        with (
            mock.patch.object(generate_credits, "CREDITS_MD", self.markdown),
            mock.patch.object(generate_credits, "CREDITS_JSON", self.json),
            contextlib.redirect_stdout(io.StringIO()),
        ):
            return generate_credits.main([str(self.packs_dir)])

    def outputs(self) -> tuple[bytes, bytes]:
        return (self.markdown.read_bytes(), self.json.read_bytes())


class EveryAssetIsCredited(CreditsTestCase):
    """The point of the tool: nothing that ships is left unnamed."""

    def setUp(self) -> None:
        super().setUp()
        self.write_pack(
            "basis",
            [
                bird(),
                bird(
                    id="zilpzalp",
                    name="Zilpzalp",
                    photo=media(attribution="Tomas Broucek", sourceURL="https://example.org/photo/2"),
                    call=media(
                        file="calls/zilpzalp.mp3",
                        license="CC0-1.0",
                        attribution="Jarek Matusiak",
                        sourceURL="https://xeno-canto.org/1",
                    ),
                ),
            ],
        )
        self.run_main()

    def test_every_asset_appears_exactly_once_in_the_markdown(self) -> None:
        text = self.markdown.read_text(encoding="utf-8")

        for attribution in ("Alexis Tinker-Tsavalas", "Tomas Broucek", "Jarek Matusiak"):
            self.assertEqual(text.count(attribution), 1, attribution)
        self.assertEqual(text.count("| Zilpzalp | Call |"), 1)
        self.assertEqual(text.count("| Zilpzalp | Photo |"), 1)

    def test_every_asset_appears_exactly_once_in_the_json(self) -> None:
        entries = json.loads(self.json.read_text(encoding="utf-8"))["media"]

        self.assertEqual(
            [(entry["birdID"], entry["kind"]) for entry in entries],
            [("amsel", "photo"), ("zilpzalp", "photo"), ("zilpzalp", "call")],
        )

    def test_the_json_entry_carries_what_the_screen_needs(self) -> None:
        entries = json.loads(self.json.read_text(encoding="utf-8"))["media"]

        self.assertEqual(
            entries[0],
            {
                "packID": "basis",
                "birdID": "amsel",
                "birdName": "Amsel",
                "kind": "photo",
                "attribution": "Alexis Tinker-Tsavalas",
                "license": "CC-BY-4.0",
                "sourceURL": "https://www.inaturalist.org/observations/1",
            },
        )

    def test_the_licence_is_named_and_linked_in_the_markdown(self) -> None:
        text = self.markdown.read_text(encoding="utf-8")

        self.assertIn("[CC BY 4.0](https://creativecommons.org/licenses/by/4.0/)", text)
        self.assertIn("[CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/)", text)


class OutputIsDeterministic(CreditsTestCase):
    def setUp(self) -> None:
        super().setUp()
        self.write_pack("basis", [bird()])

    def test_a_second_generation_from_scratch_yields_identical_bytes(self) -> None:
        self.run_main()
        first = self.outputs()

        self.markdown.unlink()
        self.json.unlink()
        self.run_main()

        self.assertEqual(self.outputs(), first)

    def test_packs_are_ordered_by_id_not_by_reading_order(self) -> None:
        self.write_pack("deutschland", [bird(id="star", name="Star")], title="Deutschland")
        self.run_main()

        text = self.markdown.read_text(encoding="utf-8")
        self.assertLess(text.index("(`basis`)"), text.index("(`deutschland`)"))

    def test_no_name_is_mangled_into_escape_sequences(self) -> None:
        # "Вячеслав Юсупов" photographed the Buntspecht. Nobody should have to
        # read their own name as В…
        self.write_pack("cyrillic", [bird(photo=media(attribution="Вячеслав Юсупов"))])
        self.run_main()

        self.assertIn("Вячеслав Юсупов", self.json.read_text(encoding="utf-8"))

    def test_a_pipe_in_a_name_does_not_shear_the_table(self) -> None:
        self.write_pack("piped", [bird(name="Am|sel", photo=media(attribution="A|B"))])
        self.run_main()

        self.assertIn(r"| Am\|sel | Photo | A\|B |", self.markdown.read_text(encoding="utf-8"))


class DriftIsTheCIContract(CreditsTestCase):
    """The exit code is what `mise run check` — and with it CI — acts on."""

    def setUp(self) -> None:
        super().setUp()
        self.write_pack("basis", [bird()])

    def test_the_first_generation_exits_1_and_writes_both_files(self) -> None:
        self.assertEqual(self.run_main(), 1)
        self.assertTrue(self.markdown.is_file())
        self.assertTrue(self.json.is_file())

    def test_current_outputs_exit_0(self) -> None:
        self.run_main()

        self.assertEqual(self.run_main(), 0)

    def test_a_bird_added_to_the_manifest_is_drift(self) -> None:
        self.run_main()

        self.write_pack("basis", [bird(), bird(id="star", name="Star")])

        self.assertEqual(self.run_main(), 1)
        self.assertIn("Star", self.markdown.read_text(encoding="utf-8"))

    def test_a_photo_missing_from_a_stale_output_is_drift(self) -> None:
        self.write_pack("basis", [bird(), bird(id="star", name="Star")])
        self.run_main()

        # What a hand-edited or half-updated credits file looks like: one bird
        # dropped out of both outputs while the manifest still declares it.
        for path in (self.markdown, self.json):
            path.write_text(
                path.read_text(encoding="utf-8").replace("Star", "Amsel"), encoding="utf-8"
            )

        self.assertEqual(self.run_main(), 1)
        self.assertEqual(self.markdown.read_text(encoding="utf-8").count("| Star |"), 1)

    def test_a_missing_packs_directory_exits_1(self) -> None:
        with (
            mock.patch.object(generate_credits, "CREDITS_MD", self.markdown),
            contextlib.redirect_stdout(io.StringIO()),
        ):
            self.assertEqual(generate_credits.main([str(self.packs_dir / "nowhere")]), 1)


class BrokenManifestsFailWithASentence(CreditsTestCase):
    """The tool runs before the licence gate, so it must not raise a traceback."""

    def test_malformed_json_exits_1(self) -> None:
        self.write_pack("basis", [bird()])
        (self.packs_dir / "basis" / "manifest.json").write_text("{", encoding="utf-8")

        self.assertEqual(self.run_main(), 1)

    def test_a_bird_without_a_photo_exits_1(self) -> None:
        self.write_pack("basis", [bird(photo=None)])

        self.assertEqual(self.run_main(), 1)

    def test_a_photo_without_attribution_exits_1(self) -> None:
        self.write_pack("basis", [bird(photo=media(attribution="  "))])

        self.assertEqual(self.run_main(), 1)

    def test_a_manifest_without_birds_exits_1(self) -> None:
        (self.packs_dir / "basis").mkdir()
        (self.packs_dir / "basis" / "manifest.json").write_text(
            '{"id": "basis", "title": "…"}', encoding="utf-8"
        )

        self.assertEqual(self.run_main(), 1)

    def test_nothing_is_written_when_a_manifest_is_broken(self) -> None:
        self.write_pack("basis", [bird(photo=None)])
        self.run_main()

        self.assertFalse(self.markdown.exists())


class StaticListsMatchTheRepository(unittest.TestCase):
    """The font and icon entries are only right as long as their files exist."""

    def test_every_declared_licence_file_is_in_the_repository(self) -> None:
        self.assertEqual(generate_credits.missing_licence_files(), [])

    def test_a_missing_licence_file_fails_before_anything_is_written(self) -> None:
        ghost = dict(generate_credits.FONTS[0], licenseFile="apps/nowhere/OFL.txt")

        with (
            mock.patch.object(generate_credits, "FONTS", (ghost,)),
            contextlib.redirect_stdout(io.StringIO()) as output,
        ):
            self.assertEqual(generate_credits.main([str(generate_credits.DEFAULT_PACKS_DIR)]), 1)

        self.assertIn("Licence file missing: apps/nowhere/OFL.txt", output.getvalue())

    def test_every_font_and_icon_reaches_the_json(self) -> None:
        document = json.loads(generate_credits.CREDITS_JSON.read_text(encoding="utf-8"))

        self.assertEqual(
            [entry["name"] for entry in document["fonts"]],
            [entry["name"] for entry in generate_credits.FONTS],
        )
        self.assertEqual(
            [entry["name"] for entry in document["icons"]],
            [entry["name"] for entry in generate_credits.ICONS],
        )


class CommittedCreditsMatchTheRealPacks(unittest.TestCase):
    """The test the issue asks for, against the packs that actually ship."""

    @classmethod
    def setUpClass(cls) -> None:
        cls.packs = generate_credits.read_packs(generate_credits.DEFAULT_PACKS_DIR)
        cls.entries = [entry for pack in cls.packs for entry in pack["media"]]

    def test_there_is_something_to_credit(self) -> None:
        self.assertTrue(self.entries)

    def test_every_asset_of_every_manifest_is_named_in_both_outputs(self) -> None:
        markdown = generate_credits.CREDITS_MD.read_text(encoding="utf-8")
        document = json.loads(generate_credits.CREDITS_JSON.read_text(encoding="utf-8"))
        credited = {(entry["packID"], entry["birdID"], entry["kind"]) for entry in document["media"]}

        for entry in self.entries:
            key = (entry["packID"], entry["birdID"], entry["kind"])
            self.assertIn(key, credited, key)
            self.assertIn(generate_credits.cell(entry["attribution"]), markdown, key)

        self.assertEqual(len(document["media"]), len(self.entries))

    def test_the_committed_files_are_what_the_generator_writes(self) -> None:
        # The same guarantee `mise run check` gives, so that removing the mise
        # wiring cannot make the credits drift unnoticed.
        self.assertEqual(
            generate_credits.CREDITS_MD.read_text(encoding="utf-8"),
            generate_credits.render_markdown(self.packs),
        )
        self.assertEqual(
            generate_credits.CREDITS_JSON.read_text(encoding="utf-8"),
            generate_credits.render_json(self.packs),
        )


if __name__ == "__main__":
    unittest.main()
