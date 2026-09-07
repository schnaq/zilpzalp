"""Tests for what the command line puts in front of the human who decides.

Run from the repository root:
uv run --locked --project tools python -m unittest discover -s tools/tests -t tools
"""

from __future__ import annotations

import contextlib
import io
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import httpx
from PIL import Image

from fetch_media import cli, inaturalist, manifest


def candidate(**overrides) -> inaturalist.Candidate:
    """A usable photo, with the given fields replaced."""
    fields = {
        "bird_id": "amsel",
        "taxon_id": 12716,
        "observation_id": 20490738,
        "photo_id": 31623386,
        "photographer": "Alexis Tinker-Tsavalas",
        "license_code": "cc-by",
        "license": "CC-BY-4.0",
        "photo_url": "https://inaturalist-open-data.s3.amazonaws.com/photos/1/original.jpeg",
        "observation_url": "https://www.inaturalist.org/observations/20490738",
        "width": 2048,
        "height": 1538,
    }
    fields.update(overrides)
    return inaturalist.Candidate(**fields)


def printed(candidates: list[inaturalist.Candidate]) -> str:
    output = io.StringIO()
    with contextlib.redirect_stdout(output):
        cli.print_table(candidates)
    return output.getvalue()


class TableTests(unittest.TestCase):
    def test_shows_one_line_per_observation(self) -> None:
        """Twelve shots of the same bird from the same minute are one decision."""
        series = [candidate(photo_id=photo) for photo in (1, 2, 3)]

        table = printed(series)

        self.assertEqual(table.count("20490738  "), 1)
        self.assertIn("1 +2", table)

    def test_lists_separate_observations_separately(self) -> None:
        table = printed([candidate(), candidate(observation_id=2, photo_id=9)])

        self.assertIn("20490738", table)
        self.assertIn("9", table)
        self.assertNotIn("+", table.split("\n+n")[0])

    def test_marks_a_photo_that_is_too_small(self) -> None:
        table = printed([candidate(width=1200, height=800)])

        self.assertIn("1200×800 !", table)
        self.assertIn("refuses to upscale", table)

    def test_says_so_when_nothing_is_usable(self) -> None:
        self.assertIn("No usable photo", printed([]))


class SelectionTests(unittest.TestCase):
    def setUp(self) -> None:
        self.pack = {"id": "basis", "birds": [{"id": "amsel"}, {"id": "star"}]}

    def test_takes_the_whole_pack_by_default(self) -> None:
        self.assertEqual(cli.selected_birds(self.pack, None), self.pack["birds"])

    def test_takes_the_named_species_in_the_order_given(self) -> None:
        self.assertEqual(
            cli.selected_birds(self.pack, ["star", "amsel"]),
            [{"id": "star"}, {"id": "amsel"}],
        )

    def test_reports_a_species_the_pack_does_not_have(self) -> None:
        with self.assertRaises(LookupError):
            cli.selected_birds(self.pack, ["wiedehopf"])


OBSERVATION = {
    "id": 20490738,
    "user": {"login": "alexis_orion", "name": "Alexis Tinker-Tsavalas"},
    "taxon": {"id": 12716, "name": "Turdus merula", "ancestor_ids": [3, 12716]},
    "photos": [
        {
            "id": 31623386,
            "license_code": "cc-by",
            "url": "https://inaturalist-open-data.s3.amazonaws.com/photos/31623386/square.jpeg",
            "original_dimensions": {"width": 1200, "height": 1200},
        }
    ],
}


def jpeg(width: int = 1200, height: int = 1200) -> bytes:
    buffer = io.BytesIO()
    Image.new("RGB", (width, height), (120, 120, 120)).save(buffer, format="JPEG")
    return buffer.getvalue()


class PickTests(unittest.TestCase):
    """`pick` end to end against a throwaway pack — no network, no repository."""

    def setUp(self) -> None:
        directory = tempfile.TemporaryDirectory()
        self.addCleanup(directory.cleanup)
        self.packs = Path(directory.name)
        self.pack = self.packs / "basis"
        (self.pack / "photos").mkdir(parents=True)
        (self.pack / "photos" / "amsel.png").write_bytes(b"the photo of the design phase")
        manifest.save(
            self.pack / "manifest.json",
            {
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
                        "photo": manifest.media_block(
                            file="photos/amsel.png",
                            sha256="0" * 64,
                            licence="CC-BY-4.0",
                            attribution="somebody else",
                            source_url="https://www.inaturalist.org/observations/1",
                            retrieved="2026-07-31",
                        ),
                        "call": None,
                    }
                ],
            },
        )

        mock.patch.object(manifest, "PACKS_DIR", self.packs).start()
        # The derived files have their own tools' tests, and running them here
        # would write into the repository.
        self.derived = mock.patch.object(cli, "regenerate_derived").start()
        self.addCleanup(mock.patch.stopall)

    def run_pick(self, observation: dict, arguments: list[str] | None = None) -> int:
        def handle(request: httpx.Request) -> httpx.Response:
            if "api.inaturalist.org" in str(request.url):
                return httpx.Response(200, json={"results": [observation]})
            return httpx.Response(200, content=jpeg())

        transport = httpx.MockTransport(handle)
        real_client = inaturalist.Client

        def client() -> inaturalist.Client:
            return real_client(transport=transport, min_interval=0)

        with mock.patch.object(cli.inaturalist, "Client", client):
            with contextlib.redirect_stdout(io.StringIO()):
                return cli.main(
                    [
                        "photos",
                        "pick",
                        "--pack",
                        "basis",
                        "--species",
                        "amsel",
                        "--observation",
                        "20490738",
                        "--photo",
                        "31623386",
                        *(arguments or []),
                    ]
                )

    def photo_entry(self) -> dict:
        document = manifest.load(self.pack / "manifest.json")
        return document["birds"][0]["photo"]

    def test_writes_the_photo_and_the_manifest_entry(self) -> None:
        self.assertEqual(self.run_pick(OBSERVATION), 0)

        entry = self.photo_entry()
        self.assertEqual(entry["file"], "photos/amsel.jpg")
        self.assertEqual(entry["license"], "CC-BY-4.0")
        self.assertEqual(entry["attribution"], "Alexis Tinker-Tsavalas")
        self.assertEqual(entry["sourceURL"], "https://www.inaturalist.org/observations/20490738")
        self.assertEqual(list(entry), list(manifest.MEDIA_KEYS))
        self.assertEqual(
            entry["sha256"], manifest.sha256_of(self.pack / "photos" / "amsel.jpg")
        )

    def test_removes_the_photo_the_manifest_no_longer_names(self) -> None:
        """It would otherwise still be copied into the app bundle."""
        self.run_pick(OBSERVATION)

        self.assertFalse((self.pack / "photos" / "amsel.png").exists())

    def test_regenerates_the_derived_files(self) -> None:
        self.run_pick(OBSERVATION)

        self.derived.assert_called_once_with()

    def test_refuses_an_observation_of_another_species(self) -> None:
        wrong = {**OBSERVATION, "taxon": {"id": 144849, "name": "Cyanistes caeruleus"}}

        self.assertEqual(self.run_pick(wrong), 1)
        self.assertEqual(self.photo_entry()["file"], "photos/amsel.png")

    def test_refuses_a_photo_whose_licence_changed(self) -> None:
        changed = {**OBSERVATION, "photos": [{**OBSERVATION["photos"][0], "license_code": "cc-by-nc"}]}

        self.assertEqual(self.run_pick(changed), 1)
        self.assertEqual(self.photo_entry()["attribution"], "somebody else")


if __name__ == "__main__":
    unittest.main()
