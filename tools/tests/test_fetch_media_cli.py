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
        cli.print_table(cli.by_observation(candidates))
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


class PackTestCase(unittest.TestCase):
    """A throwaway one-bird pack, in place of the one under data/packs."""

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
                        "photos": [
                            manifest.media_block(
                                file="photos/amsel.png",
                                sha256="0" * 64,
                                licence="CC-BY-4.0",
                                attribution="somebody else",
                                source_url="https://www.inaturalist.org/observations/1",
                                retrieved="2026-07-31",
                            )
                        ],
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

    def add_second_photo(self, content: bytes) -> None:
        """Give the pack's one bird a second photo, as `photos pick` would."""
        (self.pack / "photos" / "amsel-2.png").write_bytes(content)
        document = manifest.load(self.pack / "manifest.json")
        manifest.add_photo(
            document,
            "amsel",
            manifest.media_block(
                file="photos/amsel-2.png",
                sha256=manifest.sha256_of(self.pack / "photos" / "amsel-2.png"),
                licence="CC0-1.0",
                attribution="Somebody",
                source_url="https://www.inaturalist.org/observations/2",
                retrieved="2026-09-10",
            ),
        )
        manifest.save(self.pack / "manifest.json", document)

    def client_answering(self, handle) -> None:
        """Make every `inaturalist.Client()` answer from `handle`."""
        transport = httpx.MockTransport(handle)
        real_client = inaturalist.Client

        def client() -> inaturalist.Client:
            return real_client(transport=transport, min_interval=0)

        mock.patch.object(cli.inaturalist, "Client", client).start()


class CandidatesTests(PackTestCase):
    """`candidates` end to end — no network, no repository."""

    def run_candidates(self, results: list[dict], arguments: list[str] | None = None) -> str:
        self.client_answering(lambda request: httpx.Response(200, json={"results": results}))
        self.out = self.packs / "out"

        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = cli.main(
                ["photos", "candidates", "--pack", "basis", "--out", str(self.out), *(arguments or [])]
            )

        self.assertEqual(code, 0)
        return output.getvalue()

    def candidate_file(self) -> dict:
        return manifest.load(self.out / "basis-photo-candidates.json")

    def test_writes_the_candidate_list_beside_the_table(self) -> None:
        table = self.run_candidates([OBSERVATION])

        self.assertIn("20490738", table)
        document = self.candidate_file()
        self.assertEqual(document["pack"], "basis")
        self.assertEqual(len(document["candidates"]), 1)
        self.assertEqual(document["candidates"][0]["license"], "CC-BY-4.0")
        self.assertEqual(
            document["candidates"][0]["photo_url"],
            "https://inaturalist-open-data.s3.amazonaws.com/photos/31623386/original.jpeg",
        )

    def test_warns_about_a_species_without_a_usable_photo(self) -> None:
        table = self.run_candidates([])

        self.assertIn("::warning::amsel: no freely licensed photo found", table)
        self.assertIn("No usable photo", table)
        self.assertEqual(self.candidate_file()["candidates"], [])

    def test_reports_a_species_the_pack_does_not_have(self) -> None:
        self.client_answering(lambda request: httpx.Response(200, json={"results": []}))

        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = cli.main(["photos", "candidates", "--pack", "basis", "--species", "wiedehopf"])

        self.assertEqual(code, 1)
        self.assertIn("::error::", output.getvalue())


class PickTests(PackTestCase):
    """`pick` end to end against a throwaway pack — no network, no repository."""

    def run_pick(self, observation: dict, arguments: list[str] | None = None) -> int:
        def handle(request: httpx.Request) -> httpx.Response:
            if "api.inaturalist.org" in str(request.url):
                return httpx.Response(200, json={"results": [observation]})
            return httpx.Response(200, content=jpeg())

        self.client_answering(handle)

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

    def photos(self) -> list[dict]:
        document = manifest.load(self.pack / "manifest.json")
        return document["birds"][0]["photos"]

    def test_writes_the_photo_and_the_manifest_entry(self) -> None:
        self.assertEqual(self.run_pick(OBSERVATION), 0)

        entry = self.photos()[-1]
        self.assertEqual(entry["file"], "photos/amsel-2.heic")
        self.assertEqual(entry["license"], "CC-BY-4.0")
        self.assertEqual(entry["attribution"], "Alexis Tinker-Tsavalas")
        self.assertEqual(entry["sourceURL"], "https://www.inaturalist.org/observations/20490738")
        self.assertEqual(list(entry), list(manifest.MEDIA_KEYS))
        self.assertEqual(
            entry["sha256"], manifest.sha256_of(self.pack / "photos" / "amsel-2.heic")
        )

    def test_adds_the_photo_and_keeps_the_one_the_species_had(self) -> None:
        """Added, never overwritten (#194) — the portrait stays the first."""
        self.run_pick(OBSERVATION)

        self.assertEqual(
            [photo["file"] for photo in self.photos()],
            ["photos/amsel.png", "photos/amsel-2.heic"],
        )
        self.assertTrue((self.pack / "photos" / "amsel.png").exists())

    def test_regenerates_the_derived_files(self) -> None:
        self.run_pick(OBSERVATION)

        self.derived.assert_called_once_with()

    def test_refuses_an_observation_of_another_species(self) -> None:
        wrong = {**OBSERVATION, "taxon": {"id": 144849, "name": "Cyanistes caeruleus"}}

        self.assertEqual(self.run_pick(wrong), 1)
        self.assertEqual([photo["file"] for photo in self.photos()], ["photos/amsel.png"])

    def test_refuses_a_photo_whose_licence_changed(self) -> None:
        changed = {**OBSERVATION, "photos": [{**OBSERVATION["photos"][0], "license_code": "cc-by-nc"}]}

        self.assertEqual(self.run_pick(changed), 1)
        self.assertEqual(self.photos()[0]["attribution"], "somebody else")


class FrameTests(PackTestCase):
    """`frame` end to end — the box is given, so Apple Vision stays out of it."""

    def setUp(self) -> None:
        super().setUp()
        self.previews = self.packs / "previews"

    def run_frame(self, arguments: list[str] | None = None) -> tuple[int, str]:
        def handle(request: httpx.Request) -> httpx.Response:
            if "api.inaturalist.org" in str(request.url):
                return httpx.Response(200, json={"results": [OBSERVATION]})
            # Taller than wide and a bird in the upper left, so the crop can be
            # told apart from the centred square.
            return httpx.Response(200, content=jpeg(1200, 1600))

        self.client_answering(handle)

        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = cli.main(
                [
                    "photos",
                    "frame",
                    "--pack",
                    "basis",
                    "--species",
                    "amsel",
                    "--observation",
                    "20490738",
                    "--photo",
                    "31623386",
                    "--preview",
                    str(self.previews),
                    *(arguments or []),
                ]
            )
        return code, output.getvalue()

    def photos(self) -> list[dict]:
        return manifest.load(self.pack / "manifest.json")["birds"][0]["photos"]

    def test_crops_around_the_box_and_records_the_photo(self) -> None:
        # A 600×800 bird in the upper half: 144 px of air around it makes a
        # 1088 px square, which the top edge of the photo then holds in place.
        code, output = self.run_frame(["--box", "0.25,0.05,0.75,0.55"])

        self.assertEqual(code, 0)
        self.assertIn("--crop 56,0,1088,1088", output)
        self.assertEqual(self.photos()[-1]["file"], "photos/amsel-2.heic")

    def test_dry_run_writes_the_previews_and_nothing_else(self) -> None:
        code, output = self.run_frame(["--box", "0.25,0.05,0.75,0.55", "--dry-run"])

        self.assertEqual(code, 0)
        self.assertIn("Dry run", output)
        self.assertTrue((self.previews / "basis-amsel-source.png").is_file())
        self.assertTrue((self.previews / "basis-amsel-tile.png").is_file())
        self.assertEqual([photo["file"] for photo in self.photos()], ["photos/amsel.png"])
        self.derived.assert_not_called()

    def test_says_when_the_bird_is_too_far_away(self) -> None:
        code, output = self.run_frame(["--box", "0.5,0.5,0.55,0.55", "--dry-run"])

        self.assertEqual(code, 0)
        self.assertIn("::warning::", output)
        self.assertIn("less than a third", output)

    def test_refuses_an_original_no_square_fits_in(self) -> None:
        def handle(request: httpx.Request) -> httpx.Response:
            if "api.inaturalist.org" in str(request.url):
                return httpx.Response(200, json={"results": [OBSERVATION]})
            return httpx.Response(200, content=jpeg(1200, 800))

        self.client_answering(handle)

        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = cli.main(
                [
                    "photos",
                    "frame",
                    "--pack",
                    "basis",
                    "--species",
                    "amsel",
                    "--observation",
                    "20490738",
                    "--photo",
                    "31623386",
                    "--preview",
                    str(self.previews),
                    "--box",
                    "0.25,0.05,0.75,0.55",
                ]
            )

        self.assertEqual(code, 1)
        self.assertIn("::error::", output.getvalue())
        self.assertEqual([photo["file"] for photo in self.photos()], ["photos/amsel.png"])


class DropTests(PackTestCase):
    """`photos drop` end to end — the one step that unlinks a photo."""

    def setUp(self) -> None:
        super().setUp()
        self.add_second_photo(b"the second photo")

    def run_drop(self, file: str) -> tuple[int, str]:
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = cli.main(
                ["photos", "drop", "--pack", "basis", "--species", "amsel", "--file", file]
            )
        return code, output.getvalue()

    def photos(self) -> list[dict]:
        return manifest.load(self.pack / "manifest.json")["birds"][0]["photos"]

    def test_removes_the_entry_and_the_file(self) -> None:
        code, output = self.run_drop("photos/amsel-2.png")

        self.assertEqual(code, 0)
        self.assertEqual([photo["file"] for photo in self.photos()], ["photos/amsel.png"])
        self.assertFalse((self.pack / "photos" / "amsel-2.png").exists())
        self.assertIn("Somebody", output)
        self.derived.assert_called_once_with()

    def test_keeps_a_file_another_species_still_names(self) -> None:
        # Two birds may share a photo; the manifest is what says whether one is
        # still in use.
        document = manifest.load(self.pack / "manifest.json")
        second = dict(document["birds"][0], id="schwarzdrossel")
        document["birds"].append(second)
        manifest.save(self.pack / "manifest.json", document)

        self.assertEqual(self.run_drop("photos/amsel-2.png")[0], 0)
        self.assertTrue((self.pack / "photos" / "amsel-2.png").exists())

    def test_refuses_to_drop_the_last_photo(self) -> None:
        self.run_drop("photos/amsel-2.png")

        code, output = self.run_drop("photos/amsel.png")

        self.assertEqual(code, 1)
        self.assertIn("::error::", output)
        self.assertEqual(len(self.photos()), 1)

    def test_reports_a_photo_the_species_does_not_have(self) -> None:
        code, output = self.run_drop("photos/kohlmeise.png")

        self.assertEqual(code, 1)
        self.assertIn("::error::", output)


class AuditTests(PackTestCase):
    """`audit` end to end: the previews go out, the verdicts come back."""

    def setUp(self) -> None:
        super().setUp()
        (self.pack / "photos" / "amsel.png").write_bytes(jpeg(1024, 1024))
        self.audit = self.packs / "audit"
        mock.patch.object(cli, "AUDIT_DIR", self.audit).start()
        self.directory = self.audit / "basis"

    def run_audit(self, arguments: list[str] | None = None, stdin: str = "") -> tuple[int, str]:
        output = io.StringIO()
        with contextlib.redirect_stdout(output), mock.patch("sys.stdin", io.StringIO(stdin)):
            code = cli.main(["photos", "audit", "--pack", "basis", *(arguments or [])])
        return code, output.getvalue()

    def verdict_file(self) -> list[dict]:
        return manifest.load(self.directory / cli.VERDICTS_FILE)["verdicts"]

    def test_exports_every_tile_with_its_attribution(self) -> None:
        code, output = self.run_audit()

        self.assertEqual(code, 0)
        self.assertTrue((self.directory / "amsel.png").is_file())
        tiles = manifest.load(self.directory / cli.TILES_FILE)["tiles"]
        self.assertEqual(
            tiles,
            [
                {
                    "photo": "photos/amsel.png",
                    "species": "amsel",
                    "name": "Amsel",
                    "file": "amsel.png",
                    "attribution": "somebody else",
                    "license": "CC-BY-4.0",
                    "sourceURL": "https://www.inaturalist.org/observations/1",
                }
            ],
        )
        self.assertIn("1 tile(s), 0 judged", output)

    def test_exports_one_tile_per_photo(self) -> None:
        # A species with two photos ships two tiles, and each of them is right
        # or wrong on its own.
        self.add_second_photo(jpeg(1024, 1024))

        code, output = self.run_audit()

        self.assertEqual(code, 0)
        self.assertTrue((self.directory / "amsel-2.png").is_file())
        tiles = manifest.load(self.directory / cli.TILES_FILE)["tiles"]
        self.assertEqual(
            [tile["photo"] for tile in tiles], ["photos/amsel.png", "photos/amsel-2.png"]
        )
        self.assertIn("2 tile(s), 0 judged", output)

    def test_merges_a_verdict_and_counts_it(self) -> None:
        verdict = (
            '[{"photo": "photos/amsel.png", "bird_visible": true, "fills_frame": false, '
            '"head_inside": true, "reason": "a speck on a wire"}]'
        )

        code, output = self.run_audit(["--add-verdicts", "-"], stdin=verdict)

        self.assertEqual(code, 0)
        self.assertEqual(self.verdict_file()[0]["reason"], "a speck on a wire")
        self.assertIn("too far away: 1 — photos/amsel.png", output)
        self.assertIn("no bird visible: 0", output)

    def test_keeps_the_verdicts_of_the_batches_before(self) -> None:
        first = (
            '[{"photo": "photos/amsel.png", "bird_visible": false, "fills_frame": false, '
            '"head_inside": false}]'
        )
        self.run_audit(["--add-verdicts", "-"], stdin=first)

        # A second batch about nothing: the answer from the first has to
        # survive, because one batch is one call and a run may stop halfway.
        self.run_audit(["--add-verdicts", "-"], stdin="[]")

        self.assertEqual(len(self.verdict_file()), 1)
        self.assertFalse(self.verdict_file()[0]["bird_visible"])

    def test_lets_a_later_verdict_win(self) -> None:
        judged = (
            '[{"photo": "photos/amsel.png", "bird_visible": %s, "fills_frame": true, '
            '"head_inside": true}]'
        )
        self.run_audit(["--add-verdicts", "-"], stdin=judged % "false")
        self.run_audit(["--add-verdicts", "-"], stdin=judged % "true")

        self.assertEqual(len(self.verdict_file()), 1)
        self.assertTrue(self.verdict_file()[0]["bird_visible"])

    def test_refuses_a_verdict_about_a_photo_the_pack_lacks(self) -> None:
        stray = (
            '[{"photo": "photos/wiedehopf.png", "bird_visible": true, "fills_frame": true, '
            '"head_inside": true}]'
        )

        code, output = self.run_audit(["--add-verdicts", "-"], stdin=stray)

        self.assertEqual(code, 1)
        self.assertIn("::error::", output)
        self.assertFalse((self.directory / cli.VERDICTS_FILE).exists())

    def test_writes_nothing_when_half_a_batch_is_refused(self) -> None:
        """A batch is validated before it is written, so the one before survives."""
        first = (
            '[{"photo": "photos/amsel.png", "bird_visible": true, "fills_frame": true, '
            '"head_inside": true}]'
        )
        self.run_audit(["--add-verdicts", "-"], stdin=first)

        # A usable answer followed by one about a species the pack does not
        # hold. Neither may reach the file, and the verdict already in it may
        # not be overwritten by the half that passed.
        mixed = (
            '[{"photo": "photos/amsel.png", "bird_visible": false, "fills_frame": false, '
            '"head_inside": false}, {"photo": "photos/wiedehopf.png", "bird_visible": true, '
            '"fills_frame": true, "head_inside": true}]'
        )
        code, _ = self.run_audit(["--add-verdicts", "-"], stdin=mixed)

        self.assertEqual(code, 1)
        self.assertEqual(len(self.verdict_file()), 1)
        self.assertTrue(self.verdict_file()[0]["bird_visible"])

    def test_refuses_a_photo_that_is_not_even_a_name(self) -> None:
        """An unhashable photo is a refused verdict, not a stray TypeError."""
        nested = (
            '[{"photo": ["photos/amsel.png"], "bird_visible": true, "fills_frame": true, '
            '"head_inside": true}]'
        )

        code, output = self.run_audit(["--add-verdicts", "-"], stdin=nested)

        self.assertEqual(code, 1)
        self.assertIn("::error::", output)
        self.assertFalse((self.directory / cli.VERDICTS_FILE).exists())

    def test_refuses_an_answer_that_is_not_yes_or_no(self) -> None:
        vague = (
            '[{"photo": "photos/amsel.png", "bird_visible": "maybe", "fills_frame": true, '
            '"head_inside": true}]'
        )

        code, output = self.run_audit(["--add-verdicts", "-"], stdin=vague)

        self.assertEqual(code, 1)
        self.assertIn("has to be true or false", output)

    def test_warns_about_a_species_without_a_photo(self) -> None:
        document = manifest.load(self.pack / "manifest.json")
        document["birds"][0]["photos"] = []
        manifest.save(self.pack / "manifest.json", document)

        code, output = self.run_audit()

        self.assertEqual(code, 0)
        self.assertIn("::warning::amsel: has no photo to audit", output)


if __name__ == "__main__":
    unittest.main()
