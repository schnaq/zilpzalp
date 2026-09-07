"""Tests for the xeno-canto side of the curation tool.

The record below is recorded from the live API (XC965144, an Amsel) and then
varied for the cases the real response does not conveniently contain: the
CC BY-SA 3.0 that `lic:BY-SA` really does return, and the sounds a quiz cannot
use. No test reaches the network.

The API key is the reason several of these exist. It travels as a query
parameter, so every message that quotes a URL would carry it into a terminal
and into a CI log — `KeyLeakTests` is the guard against that.

Run from the repository root:
uv run --locked --project tools python -m unittest discover -s tools/tests -t tools
"""

from __future__ import annotations

import contextlib
import io
import time
import unittest
from unittest import mock

import httpx

from fetch_media import audio, cli, manifest, xenocanto
from tests.test_fetch_media_audio import tone
from tests.test_fetch_media_cli import PackTestCase

KEY = "0123456789abcdef0123456789abcdef01234567"

BY_SA_4 = "https://creativecommons.org/licenses/by-sa/4.0/"
BY_SA_3 = "https://creativecommons.org/licenses/by-sa/3.0/"

# Recorded from GET /api/3/recordings?query=sp:"Turdus merula" lic:BY-SA q:">C"
RECORDED = {
    "id": "965144",
    "gen": "Turdus",
    "sp": "merula",
    "ssp": "",
    "en": "Common Blackbird",
    "rec": "Mirko Tomasi",
    "type": "song",
    "url": "https://xeno-canto.org/965144",
    "file": "https://xeno-canto.org/965144/download",
    "file-name": "XC965144-Nuova-registrazione-21.mp3",
    "lic": BY_SA_4,
    "q": "A",
    "length": "0:17",
    "smp": "48000",
}


def record(**overrides) -> dict:
    """The recorded recording, with the given fields replaced."""
    return {**RECORDED, **overrides}


def answer(records: list[dict], pages: int = 1) -> httpx.Response:
    """A search response, with `numRecordings` a string as the API sends it."""
    return httpx.Response(
        200,
        json={
            "numRecordings": str(len(records)),
            "numSpecies": "1",
            "page": 1,
            "numPages": pages,
            "recordings": records,
        },
    )


class RedactTests(unittest.TestCase):
    def test_removes_the_key_from_a_url(self) -> None:
        text = f"Client error '401 Unauthorized' for url 'https://xeno-canto.org/api/3/recordings?query=nr%3A1&key={KEY}'"

        redacted = xenocanto.redact(text)

        self.assertNotIn(KEY, redacted)
        self.assertIn("key=…", redacted)
        self.assertIn("query=nr%3A1", redacted)

    def test_removes_the_key_wherever_it_sits(self) -> None:
        for text in (
            f"?key={KEY}&query=nr:1",
            f"?KEY={KEY}",
            f"'https://xeno-canto.org/api/3/recordings?key={KEY}'",
            f"?key={KEY} trailing words",
        ):
            with self.subTest(text=text):
                self.assertNotIn(KEY, xenocanto.redact(text))

    def test_leaves_text_without_a_key_alone(self) -> None:
        self.assertEqual(xenocanto.redact("no key here"), "no key here")


class ApiKeyTests(unittest.TestCase):
    def test_reads_the_key_from_the_environment(self) -> None:
        self.assertEqual(xenocanto.api_key({"XENO_CANTO_API_KEY": KEY}), KEY)

    def test_names_the_variable_and_the_command_that_provides_it(self) -> None:
        with self.assertRaises(RuntimeError) as error:
            xenocanto.api_key({})

        self.assertIn("XENO_CANTO_API_KEY", str(error.exception))
        self.assertIn("infisical run", str(error.exception))


class LicenceTests(unittest.TestCase):
    def test_maps_the_three_permitted_urls(self) -> None:
        self.assertEqual(
            xenocanto.licence_id("https://creativecommons.org/publicdomain/zero/1.0/"), "CC0-1.0"
        )
        self.assertEqual(
            xenocanto.licence_id("https://creativecommons.org/licenses/by/4.0/"), "CC-BY-4.0"
        )
        self.assertEqual(xenocanto.licence_id(BY_SA_4), "CC-BY-SA-4.0")

    def test_rejects_share_alike_3_0(self) -> None:
        """`lic:BY-SA` really returns it, and 3.0 is not the 4.0 raw value."""
        self.assertIsNone(xenocanto.licence_id(BY_SA_3))

    def test_rejects_the_public_domain_mark_and_the_noncommercial_variants(self) -> None:
        for url in (
            "https://creativecommons.org/publicdomain/mark/1.0/",
            "https://creativecommons.org/licenses/by-nc-sa/4.0/",
            "https://creativecommons.org/licenses/by-nc-nd/4.0/",
            "",
            None,
        ):
            with self.subTest(url=url):
                self.assertIsNone(xenocanto.licence_id(url))

    def test_ignores_the_scheme_and_a_trailing_slash(self) -> None:
        self.assertEqual(
            xenocanto.licence_id("http://creativecommons.org/licenses/by-sa/4.0"), "CC-BY-SA-4.0"
        )

    def test_labels_a_licence_we_cannot_use_by_its_name(self) -> None:
        self.assertEqual(xenocanto.licence_label(BY_SA_3), "by-sa/3.0")
        self.assertEqual(xenocanto.licence_label(BY_SA_4), "CC-BY-SA-4.0")
        self.assertEqual(xenocanto.licence_label(""), "no licence")

    def test_the_manifest_identifiers_are_the_ones_the_gate_accepts(self) -> None:
        self.assertEqual(
            sorted(set(xenocanto.LICENCES.values())),
            ["CC-BY-4.0", "CC-BY-SA-4.0", "CC0-1.0"],
        )


class RecordingNumberTests(unittest.TestCase):
    def test_accepts_both_spellings(self) -> None:
        for text in ("965144", "XC965144", " xc965144 "):
            with self.subTest(text=text):
                self.assertEqual(xenocanto.recording_number(text), "965144")

    def test_refuses_anything_else(self) -> None:
        with self.assertRaises(ValueError):
            xenocanto.recording_number("the second one")


class TypeTests(unittest.TestCase):
    def test_splits_the_free_text_field(self) -> None:
        self.assertEqual(
            xenocanto.descriptors("call, bavardage, cri d'agitation"),
            ["call", "bavardage", "cri d'agitation"],
        )

    def test_matches_within_one_descriptor_only(self) -> None:
        """'begging call' must not answer a search for a call by accident."""
        self.assertTrue(xenocanto.matches_type(["alarm call"], "call"))
        self.assertTrue(xenocanto.matches_type(["begging call"], "begging"))
        self.assertFalse(xenocanto.matches_type(["song"], "call"))

    def test_skips_only_recordings_that_are_all_useless(self) -> None:
        self.assertTrue(xenocanto.is_skipped(["begging call"]))
        self.assertTrue(xenocanto.is_skipped(["nocturnal flight call", "wingbeats"]))
        self.assertFalse(xenocanto.is_skipped(["song", "begging call"]))

    def test_keeps_a_plain_flight_call(self) -> None:
        """The Eisvogel's whistle in flight is the sound a child learns it by."""
        self.assertFalse(xenocanto.is_skipped(["flight call"]))

    def test_does_not_skip_an_unlabelled_recording(self) -> None:
        """Eight of the base pack's free recordings carry no type at all."""
        self.assertFalse(xenocanto.is_skipped([]))

    def test_ranks_song_before_call_before_the_rest(self) -> None:
        self.assertLess(xenocanto.type_rank(["song"]), xenocanto.type_rank(["alarm call"]))
        self.assertLess(xenocanto.type_rank(["alarm call"]), xenocanto.type_rank([]))


class CandidateTests(unittest.TestCase):
    def candidates(self, records: list[dict], wanted: str | None = None) -> list[str]:
        return [
            entry.recording_id for entry in xenocanto.call_candidates("amsel", records, wanted)
        ]

    def test_hides_the_sounds_the_game_cannot_use(self) -> None:
        records = [record(id="1", type="begging call"), record(id="2")]

        self.assertEqual(self.candidates(records), ["2"])

    def test_shows_them_when_type_asks_for_them_by_name(self) -> None:
        """The Buntspecht's drumming is the didactic choice, not its call (#32)."""
        records = [record(id="1", type="drumming"), record(id="2", type="song")]

        self.assertEqual(self.candidates(records, "drumming"), ["1"])

    def test_marks_a_recording_that_would_otherwise_be_hidden(self) -> None:
        found = xenocanto.call_candidates("amsel", [record(type="begging call")], "begging")

        self.assertTrue(found[0].skipped)

    def test_sorts_song_before_call_and_a_before_b(self) -> None:
        records = [
            record(id="1", type="call", q="A"),
            record(id="2", type="song", q="B"),
            record(id="3", type="song", q="A"),
        ]

        self.assertEqual(self.candidates(records), ["3", "2", "1"])

    def test_sorts_a_licence_we_cannot_use_last_but_keeps_it(self) -> None:
        records = [record(id="1", lic=BY_SA_3, type="song"), record(id="2", type="call")]

        self.assertEqual(self.candidates(records), ["2", "1"])


class RecordTests(unittest.TestCase):
    def test_reads_the_binomial_from_genus_and_species(self) -> None:
        """A subspecies keeps `gen` and `sp` and only fills `ssp`."""
        self.assertEqual(xenocanto.binomial(record(ssp="tristis")), "Turdus merula")

    def test_credits_the_recordist_with_the_catalogue_number(self) -> None:
        self.assertEqual(xenocanto.attribution(RECORDED), "Mirko Tomasi (XC965144)")

    def test_refuses_a_recording_without_a_recordist(self) -> None:
        with self.assertRaises(ValueError):
            xenocanto.attribution(record(rec=" "))


class ClientTests(unittest.TestCase):
    def client(self, handle, min_interval: float = 0.0) -> xenocanto.Client:
        return xenocanto.Client(
            KEY, transport=httpx.MockTransport(handle), min_interval=min_interval
        )

    def test_sends_the_key_only_to_the_api(self) -> None:
        """The download URL redirects; a default parameter would follow it."""
        seen = []

        def handle(request: httpx.Request) -> httpx.Response:
            seen.append(str(request.url))
            if "/api/" in str(request.url):
                return answer([RECORDED])
            return httpx.Response(200, content=b"audio")

        with self.client(handle) as client:
            client.recording("965144")
            client.download(RECORDED["file"])

        self.assertIn(f"key={KEY}", seen[0])
        self.assertNotIn(KEY, seen[1])

    def test_asks_once_per_licence(self) -> None:
        queries = []

        def handle(request: httpx.Request) -> httpx.Response:
            queries.append(request.url.params["query"])
            return answer([])

        with self.client(handle) as client:
            client.recordings("Turdus merula")

        self.assertEqual(len(queries), len(xenocanto.LICENCE_FILTERS))
        self.assertTrue(all('sp:"Turdus merula"' in query for query in queries))
        self.assertTrue(all(xenocanto.QUALITY_FILTER in query for query in queries))

    def test_holds_one_request_per_second_on_every_path(self) -> None:
        """The terms ask for it, and the download is a request like any other."""

        def handle(request: httpx.Request) -> httpx.Response:
            if "/api/" in str(request.url):
                return answer([RECORDED])
            return httpx.Response(200, content=b"audio")

        with self.client(handle, min_interval=0.2) as client:
            started = time.monotonic()
            client.recording("965144")
            client.download(RECORDED["file"])
            elapsed = time.monotonic() - started

        self.assertGreaterEqual(elapsed, 0.2)

    def test_remembers_a_result_it_did_not_walk_to_the_end(self) -> None:
        """One page is a hundred recordings; the counts must not claim more."""
        with self.client(lambda request: answer([RECORDED], pages=4)) as client:
            client.search("sp:Turdus")

        self.assertEqual(client.truncated, ["sp:Turdus"])

    def test_retries_once_when_the_connection_drops(self) -> None:
        """Thirty requests a second apart: one hiccup must not cost the run."""
        attempts = []

        def handle(request: httpx.Request) -> httpx.Response:
            attempts.append(request)
            if len(attempts) == 1:
                raise httpx.ConnectError("connection reset", request=request)
            return answer([RECORDED])

        with self.client(handle) as client:
            self.assertEqual(client.search("nr:965144"), [RECORDED])

        self.assertEqual(len(attempts), 2)

    def test_gives_up_after_the_second_connection_failure(self) -> None:
        def handle(request: httpx.Request) -> httpx.Response:
            raise httpx.ConnectError("connection reset", request=request)

        with self.client(handle) as client:
            with self.assertRaises(xenocanto.XenoCantoError):
                client.search("nr:965144")

    def test_reports_an_unknown_catalogue_number(self) -> None:
        with self.client(lambda request: answer([])) as client:
            with self.assertRaises(LookupError) as error:
                client.recording("999999999")

        self.assertIn("XC999999999", str(error.exception))

    def test_a_failed_request_carries_no_key(self) -> None:
        with self.client(lambda request: httpx.Response(401, json={"message": "invalid key"})) as (
            client
        ):
            with self.assertRaises(xenocanto.XenoCantoError) as error:
                client.search("nr:1")

        self.assertNotIn(KEY, str(error.exception))
        self.assertIn("401", str(error.exception))


class CallsTestCase(PackTestCase):
    """The throwaway pack of the photo tests, answered by xeno-canto instead."""

    def setUp(self) -> None:
        super().setUp()
        mock.patch.dict("os.environ", {"XENO_CANTO_API_KEY": KEY}).start()

    def client_answering(self, handle) -> None:
        transport = httpx.MockTransport(handle)
        real_client = xenocanto.Client

        def client(key: str) -> xenocanto.Client:
            return real_client(key, transport=transport, min_interval=0)

        mock.patch.object(cli.xenocanto, "Client", client).start()

    def run_command(self, arguments: list[str]) -> tuple[int, str]:
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            code = cli.main(arguments)
        return code, output.getvalue()


class CandidatesTests(CallsTestCase):
    """`calls candidates` end to end — no network, no repository."""

    def run_candidates(self, records: list[dict], arguments: list[str] | None = None) -> str:
        self.client_answering(lambda request: answer(records))
        self.out = self.packs / "out"

        code, printed = self.run_command(
            ["calls", "candidates", "--pack", "basis", "--out", str(self.out), *(arguments or [])]
        )

        self.assertEqual(code, 0)
        return printed

    def candidate_file(self) -> dict:
        return manifest.load(self.out / "basis-call-candidates.json")

    def test_lists_the_recording_and_writes_the_candidate_file(self) -> None:
        table = self.run_candidates([RECORDED])

        self.assertIn("XC965144", table)
        self.assertIn("Mirko Tomasi", table)
        self.assertIn("CC-BY-SA-4.0", table)
        # Three requests, one per licence, all answered with the same recording.
        self.assertEqual(len(self.candidate_file()["candidates"]), 3)

    def test_marks_a_licence_the_project_may_not_ship(self) -> None:
        table = self.run_candidates([record(lic=BY_SA_3)])

        self.assertIn("by-sa/3.0 !", table)
        self.assertIn("cannot ship", table)

    def test_counts_the_free_stock_per_species(self) -> None:
        """The number issue #32 asks for: how much is usable, in which quality."""
        table = self.run_candidates([record(id="1", q="B"), record(id="2", q="B", lic=BY_SA_3)])

        self.assertIn("amsel", table)
        self.assertIn("3 usable (0 in A, 3 in B), 3 unusable", table)

    def test_counts_the_recordings_the_type_filter_holds_back(self) -> None:
        table = self.run_candidates([record(id="1"), record(id="2", type="begging call")])

        self.assertIn("0 unusable, 3 of another type", table)
        self.assertIn("--type shows it", table)

    def test_says_when_the_counts_are_only_a_floor(self) -> None:
        self.client_answering(lambda request: answer([RECORDED], pages=2))
        self.out = self.packs / "out"

        _, printed = self.run_command(
            ["calls", "candidates", "--pack", "basis", "--out", str(self.out)]
        )

        self.assertIn("::warning::3 search(es) had more than one page", printed)

    def test_warns_about_a_species_without_a_usable_recording(self) -> None:
        table = self.run_candidates([record(lic=BY_SA_3)])

        self.assertIn("::warning::amsel: no freely licensed recording found", table)

    def test_limits_the_table_but_not_the_candidate_file(self) -> None:
        table = self.run_candidates([record(id="1"), record(id="2")], ["--limit", "1"])

        self.assertEqual(table.count("XC1 "), 1)
        self.assertNotIn("XC2", table)
        self.assertEqual(len(self.candidate_file()["candidates"]), 6)


class PickTests(CallsTestCase):
    """`calls pick` end to end, including a real afconvert run on a short tone."""

    def run_pick(self, found: dict, arguments: list[str] | None = None) -> tuple[int, str]:
        def handle(request: httpx.Request) -> httpx.Response:
            if "/api/" in str(request.url):
                return answer([found])
            return httpx.Response(200, content=tone(seconds=0.5))

        self.client_answering(handle)
        return self.run_command(
            [
                "calls",
                "pick",
                "--pack",
                "basis",
                "--species",
                "amsel",
                "--recording",
                "XC965144",
                "--duration",
                "0.3",
                *(arguments or []),
            ]
        )

    def call_entry(self) -> dict | None:
        return manifest.load(self.pack / "manifest.json")["birds"][0]["call"]

    def test_writes_the_recording_and_the_manifest_entry(self) -> None:
        code, _ = self.run_pick(record(**{"file-name": "XC965144-amsel.wav"}))

        self.assertEqual(code, 0)
        entry = self.call_entry()
        self.assertEqual(entry["file"], "audio/amsel.m4a")
        self.assertEqual(entry["license"], "CC-BY-SA-4.0")
        self.assertEqual(entry["attribution"], "Mirko Tomasi (XC965144)")
        self.assertEqual(entry["sourceURL"], "https://xeno-canto.org/965144")
        self.assertEqual(list(entry), list(manifest.MEDIA_KEYS))
        self.assertEqual(
            entry["sha256"], manifest.sha256_of(self.pack / "audio" / f"amsel{audio.EXTENSION}")
        )

    def test_leaves_the_photo_alone(self) -> None:
        self.run_pick(record(**{"file-name": "XC965144-amsel.wav"}))

        document = manifest.load(self.pack / "manifest.json")
        self.assertEqual(document["birds"][0]["photo"]["file"], "photos/amsel.png")

    def test_regenerates_the_derived_files(self) -> None:
        self.run_pick(record(**{"file-name": "XC965144-amsel.wav"}))

        self.derived.assert_called_once_with()

    def test_refuses_a_recording_of_another_species(self) -> None:
        code, printed = self.run_pick(record(gen="Cyanistes", sp="caeruleus"))

        self.assertEqual(code, 1)
        self.assertIn("Cyanistes caeruleus", printed)
        self.assertIsNone(self.call_entry())

    def test_refuses_share_alike_3_0(self) -> None:
        code, printed = self.run_pick(record(lic=BY_SA_3))

        self.assertEqual(code, 1)
        self.assertIn("by-sa/3.0", printed)
        self.assertIsNone(self.call_entry())


class KeyLeakTests(CallsTestCase):
    """The key travels in a URL, so every printed failure is a suspect."""

    def test_the_key_never_reaches_stdout_when_the_api_refuses(self) -> None:
        self.client_answering(
            lambda request: httpx.Response(401, json={"message": "Missing or invalid 'key'"})
        )

        code, printed = self.run_command(["calls", "candidates", "--pack", "basis"])

        self.assertEqual(code, 1)
        self.assertNotIn(KEY, printed)
        self.assertIn("::error::", printed)
        self.assertIn("key=…", printed)

    def test_the_key_never_reaches_stdout_on_a_successful_run(self) -> None:
        self.client_answering(lambda request: answer([RECORDED]))
        self.out = self.packs / "out"

        _, printed = self.run_command(
            ["calls", "candidates", "--pack", "basis", "--out", str(self.out)]
        )

        self.assertNotIn(KEY, printed)
        self.assertNotIn(KEY, (self.out / "basis-call-candidates.json").read_text(encoding="utf-8"))

    def test_a_missing_key_names_the_variable_instead_of_failing_late(self) -> None:
        with mock.patch.dict("os.environ", {"XENO_CANTO_API_KEY": ""}):
            code, printed = self.run_command(["calls", "candidates", "--pack", "basis"])

        self.assertEqual(code, 1)
        self.assertIn("XENO_CANTO_API_KEY", printed)


if __name__ == "__main__":
    unittest.main()
