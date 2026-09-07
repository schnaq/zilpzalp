"""Tests for the iNaturalist side of the curation tool.

The observation below is recorded from the live API (observation 20490738, the
Amsel photo the base pack already credits) and then extended with the cases the
real response does not conveniently contain: a NonCommercial photo inside an
otherwise usable observation, a photo served from the non-open host, and a
subspecies identification. No test reaches the network.

Run from the repository root:
uv run --locked --project tools python -m unittest discover -s tools/tests -t tools
"""

from __future__ import annotations

import unittest
from unittest import mock

import httpx

from fetch_media import inaturalist

AMSEL = 12716

# Recorded from GET /v1/observations?taxon_id=12716&photo_license=cc0,cc-by,
# cc-by-sa&quality_grade=research&rank=species&per_page=2&order_by=votes
RECORDED = {
    "id": 20490738,
    "quality_grade": "research",
    "license_code": "cc-by",
    "user": {"login": "alexis_orion", "name": "Alexis Tinker-Tsavalas"},
    "taxon": {"id": 12716, "rank": "species", "name": "Turdus merula", "ancestor_ids": [3, 12716]},
    "photos": [
        {
            "id": 31623386,
            "license_code": "cc-by",
            "url": "https://inaturalist-open-data.s3.amazonaws.com/photos/31623386/square.jpeg",
            "attribution": "(c) Alexis Tinker-Tsavalas, some rights reserved (CC BY)",
            "original_dimensions": {"width": 2048, "height": 1538},
        },
        {
            "id": 31623395,
            "license_code": "cc-by",
            "url": "https://inaturalist-open-data.s3.amazonaws.com/photos/31623395/square.jpeg",
            "original_dimensions": {"width": 2048, "height": 1538},
        },
    ],
}


def observation(**overrides) -> dict:
    """The recorded observation, with the given fields replaced."""
    return {**RECORDED, **overrides}


def photo(**overrides) -> dict:
    """A usable photo, with the given fields replaced."""
    return {**RECORDED["photos"][0], **overrides}


class LicenceTests(unittest.TestCase):
    def test_maps_the_three_permitted_codes(self) -> None:
        self.assertEqual(inaturalist.licence_id("cc0"), "CC0-1.0")
        self.assertEqual(inaturalist.licence_id("cc-by"), "CC-BY-4.0")
        self.assertEqual(inaturalist.licence_id("cc-by-sa"), "CC-BY-SA-4.0")

    def test_rejects_noncommercial_and_noderivatives(self) -> None:
        for code in ("cc-by-nc", "cc-by-nc-sa", "cc-by-nc-nd", "cc-by-nd"):
            with self.subTest(code=code), self.assertRaises(inaturalist.LicenceError):
                inaturalist.licence_id(code)

    def test_rejects_an_absent_licence(self) -> None:
        """The default of an iNaturalist photo is all rights reserved."""
        for code in (None, "", "C"):
            with self.subTest(code=code), self.assertRaises(inaturalist.LicenceError):
                inaturalist.licence_id(code)

    def test_the_server_side_filter_lists_exactly_the_permitted_codes(self) -> None:
        self.assertEqual(inaturalist.PHOTO_LICENSE_FILTER, "cc0,cc-by,cc-by-sa")

    def test_only_the_open_data_host_counts_as_open(self) -> None:
        self.assertTrue(inaturalist.is_open_data(RECORDED["photos"][0]["url"]))
        self.assertFalse(
            inaturalist.is_open_data("https://static.inaturalist.org/photos/1/square.jpeg")
        )
        # A host that merely ends in the open one must not pass.
        self.assertFalse(
            inaturalist.is_open_data("https://evil.inaturalist-open-data.s3.amazonaws.com/x.jpeg")
        )


class CandidateTests(unittest.TestCase):
    def test_reads_the_recorded_observation(self) -> None:
        candidates = inaturalist.photo_candidates("amsel", AMSEL, [observation()])

        self.assertEqual(len(candidates), 2)
        first = candidates[0]
        self.assertEqual(first.bird_id, "amsel")
        self.assertEqual(first.observation_id, 20490738)
        self.assertEqual(first.photo_id, 31623386)
        self.assertEqual(first.photographer, "Alexis Tinker-Tsavalas")
        self.assertEqual(first.license, "CC-BY-4.0")
        self.assertEqual(
            first.photo_url,
            "https://inaturalist-open-data.s3.amazonaws.com/photos/31623386/original.jpeg",
        )
        self.assertEqual(first.observation_url, "https://www.inaturalist.org/observations/20490738")
        self.assertEqual(first.square_side, 1538)

    def test_drops_a_noncommercial_photo_from_a_matching_observation(self) -> None:
        """The server filters observations, not photos — one may hold both."""
        mixed = observation(photos=[photo(id=1, license_code="cc-by-nc"), photo(id=2)])

        candidates = inaturalist.photo_candidates("amsel", AMSEL, [mixed])

        self.assertEqual([candidate.photo_id for candidate in candidates], [2])

    def test_drops_a_photo_from_the_non_open_host(self) -> None:
        """The host is the second, independent piece of licence evidence."""
        wrong_host = observation(
            photos=[photo(url="https://static.inaturalist.org/photos/9/square.jpeg")]
        )

        self.assertEqual(inaturalist.photo_candidates("amsel", AMSEL, [wrong_host]), [])

    def test_keeps_a_subspecies_and_drops_another_species(self) -> None:
        subspecies = observation(
            id=1, taxon={"id": 999, "rank": "subspecies", "ancestor_ids": [3, AMSEL, 999]}
        )
        other = observation(id=2, taxon={"id": 12727, "rank": "species", "ancestor_ids": [3, 12727]})

        candidates = inaturalist.photo_candidates("amsel", AMSEL, [subspecies, other])

        self.assertEqual({candidate.observation_id for candidate in candidates}, {1})

    def test_credits_the_login_when_the_name_is_empty(self) -> None:
        anonymous = observation(user={"login": "alexis_orion", "name": ""})

        candidates = inaturalist.photo_candidates("amsel", AMSEL, [anonymous])

        self.assertEqual(candidates[0].photographer, "alexis_orion")

    def test_reports_an_unknown_square_side(self) -> None:
        without = observation(photos=[photo(original_dimensions=None)])

        self.assertIsNone(inaturalist.photo_candidates("amsel", AMSEL, [without])[0].square_side)


class FindPhotoTests(unittest.TestCase):
    """`pick` re-reads the API instead of trusting a candidate file."""

    def test_returns_the_named_photo(self) -> None:
        self.assertEqual(inaturalist.find_photo(observation(), 31623395)["id"], 31623395)

    def test_rejects_a_photo_whose_licence_changed(self) -> None:
        changed = observation(photos=[photo(license_code="cc-by-nc")])

        with self.assertRaises(inaturalist.LicenceError):
            inaturalist.find_photo(changed, 31623386)

    def test_rejects_a_photo_from_the_non_open_host(self) -> None:
        moved = observation(photos=[photo(url="https://static.inaturalist.org/photos/1/sq.jpeg")])

        with self.assertRaises(inaturalist.LicenceError):
            inaturalist.find_photo(moved, 31623386)

    def test_reports_a_photo_that_is_not_in_the_observation(self) -> None:
        with self.assertRaises(LookupError):
            inaturalist.find_photo(observation(), 5)


class ClientTests(unittest.TestCase):
    """The client against a mock transport — no test reaches the network."""

    def setUp(self) -> None:
        self.requests: list[httpx.Request] = []

    def transport(self, payload: dict) -> httpx.MockTransport:
        def handle(request: httpx.Request) -> httpx.Response:
            self.requests.append(request)
            return httpx.Response(200, json=payload)

        return httpx.MockTransport(handle)

    def test_asks_the_observations_endpoint_with_the_licence_filter(self) -> None:
        transport = self.transport({"results": [observation()]})

        with inaturalist.Client(transport=transport, min_interval=0) as client:
            results = client.observations(AMSEL, per_page=5)

        self.assertEqual(len(results), 1)
        request = self.requests[0]
        self.assertEqual(request.url.path, "/v1/observations")
        self.assertEqual(
            dict(request.url.params),
            {
                "taxon_id": str(AMSEL),
                "photo_license": "cc0,cc-by,cc-by-sa",
                "quality_grade": "research",
                "rank": "species",
                "order_by": "votes",
                "per_page": "5",
                "locale": "de",
            },
        )

    def test_identifies_itself(self) -> None:
        """The API docs ask for a user agent that names the project."""
        with inaturalist.Client(transport=self.transport({"results": []}), min_interval=0) as client:
            client.observations(AMSEL, per_page=1)

        self.assertEqual(self.requests[0].headers["User-Agent"], inaturalist.USER_AGENT)
        self.assertIn("github.com/schnaq/zilpzalp", inaturalist.USER_AGENT)

    def test_never_asks_the_taxon_endpoint(self) -> None:
        """photo_license is silently ignored there — see the module docstring."""
        transport = self.transport({"results": [observation()]})

        with inaturalist.Client(transport=transport, min_interval=0) as client:
            client.observations(AMSEL, per_page=1)
            client.observation(20490738)

        self.assertTrue(all("/taxa" not in str(request.url) for request in self.requests))

    def test_waits_between_requests(self) -> None:
        transport = self.transport({"results": [observation()]})

        with mock.patch("fetch_media.inaturalist.time.sleep") as sleep:
            with inaturalist.Client(transport=transport, min_interval=1.0) as client:
                client.observations(AMSEL, per_page=1)
                client.observations(AMSEL, per_page=1)

        # Not before the first request, and no faster than one per second after.
        self.assertEqual(sleep.call_count, 1)
        self.assertGreater(sleep.call_args.args[0], 0)
        self.assertLessEqual(sleep.call_args.args[0], 1.0)

    def test_reports_a_missing_observation(self) -> None:
        with inaturalist.Client(transport=self.transport({"results": []}), min_interval=0) as client:
            with self.assertRaises(LookupError):
                client.observation(1)

    def test_retries_a_dropped_connection_once(self) -> None:
        answers = [httpx.RemoteProtocolError("server disconnected"), httpx.Response(200, json={})]

        def handle(request: httpx.Request) -> httpx.Response:
            answer = answers.pop(0)
            if isinstance(answer, Exception):
                raise answer
            return answer

        with inaturalist.Client(transport=httpx.MockTransport(handle), min_interval=0) as client:
            self.assertEqual(client.observations(AMSEL, per_page=1), [])

        self.assertEqual(answers, [])

    def test_gives_up_after_the_retry(self) -> None:
        def handle(request: httpx.Request) -> httpx.Response:
            raise httpx.ConnectError("no route")

        with inaturalist.Client(transport=httpx.MockTransport(handle), min_interval=0) as client:
            with self.assertRaises(httpx.ConnectError):
                client.observations(AMSEL, per_page=1)

    def test_raises_on_an_http_error(self) -> None:
        transport = httpx.MockTransport(lambda request: httpx.Response(429))

        with inaturalist.Client(transport=transport, min_interval=0) as client:
            with self.assertRaises(httpx.HTTPStatusError):
                client.observations(AMSEL, per_page=1)


if __name__ == "__main__":
    unittest.main()
