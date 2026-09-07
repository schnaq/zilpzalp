"""Read-only access to the iNaturalist API, at curation time only.

Two findings that cost a day when they are rediscovered
(docs/medien-und-lizenzen.md): the `default_photo` of a taxon is unusable — it
often carries a NonCommercial licence or none at all — and `photo_license` is
silently ignored at the taxon endpoint, the response is identical with and
without it. Only `/v1/observations` filters for real. This module therefore
asks nothing else.

The licence is checked twice more after the server has filtered, per photo:
against `license_code`, and against the host the photo is served from. The API
documentation states that "the domain a photo is hosted under reflects the
license under which the photo is being shared", so an open-data host is
independent evidence for the same fact. One wrong field then cannot ship a
NonCommercial photo.
"""

from __future__ import annotations

import time
from dataclasses import dataclass
from urllib.parse import urlparse

import httpx

API_ROOT = "https://api.inaturalist.org/v1"
OBSERVATION_URL = "https://www.inaturalist.org/observations/{}"

# The API docs ask for a descriptive user agent, so a problem can be traced
# back to a project rather than to an anonymous script.
USER_AGENT = "zilpzalp-fetch-media/0.1 (+https://github.com/schnaq/zilpzalp)"

# The iNaturalist licence codes we accept, mapped to the identifiers the
# manifest, tools/license_gate.py and the Swift `License` enum share. Every
# other code — every NonCommercial and NoDerivatives variant above all — is an
# error rather than an asset that quietly reaches a build.
LICENCES = {"cc0": "CC0-1.0", "cc-by": "CC-BY-4.0", "cc-by-sa": "CC-BY-SA-4.0"}

# The parameter value that makes the server filter. Derived from LICENCES so
# the two can never drift apart.
PHOTO_LICENSE_FILTER = ",".join(LICENCES)

# Photos under an open licence are served from here; `static.inaturalist.org`
# holds the rest. See the module docstring.
OPEN_DATA_HOST = "inaturalist-open-data.s3.amazonaws.com"

# "we throttle API usage to a max of 100 requests per minute, though we ask
# that you try to keep it to 60 requests per minute or lower" — one second
# between requests is the rate they ask for, and curation is never in a hurry.
MIN_INTERVAL = 1.0


class LicenceError(ValueError):
    """A licence iNaturalist reports that this project may not use."""


def licence_id(code: object) -> str:
    """Map an iNaturalist licence code to the manifest's licence identifier.

    Raises `LicenceError` for everything else, `None` and the NonCommercial
    variants included. There is no default: a photo whose licence we cannot
    name is a photo we may not ship.
    """
    if not isinstance(code, str) or code.lower() not in LICENCES:
        allowed = ", ".join(LICENCES)
        raise LicenceError(f"licence '{code}' is not permitted (allowed: {allowed})")
    return LICENCES[code.lower()]


def is_open_data(url: object) -> bool:
    """Whether the photo URL is served from the open-data host."""
    return isinstance(url, str) and urlparse(url).hostname == OPEN_DATA_HOST


def original_url(square_url: str) -> str:
    """Turn the `square` URL the API returns into the `original` one.

    iNaturalist serves every size under the same path and only varies the file
    name — `square.jpeg`, `medium.jpeg`, `original.jpeg`.
    """
    head, _, name = square_url.rpartition("/")
    _, _, extension = name.rpartition(".")
    return f"{head}/original.{extension}"


def photographer(observation: dict) -> str:
    """The name to credit, exactly as iNaturalist reports it.

    `name` is what contributors fill in and what the base pack credits;
    `login` is the fallback for the ones who left it empty.
    """
    user = observation.get("user") or {}
    name = user.get("name")
    if isinstance(name, str) and name.strip():
        return name.strip()

    login = user.get("login")
    if isinstance(login, str) and login.strip():
        return login.strip()

    raise ValueError(f"observation {observation.get('id')}: has no user to credit")


def taxon_matches(observation: dict, taxon_id: int) -> bool:
    """Whether the observation really shows the species we asked for.

    The identification may be a subspecies, which carries its own taxon id and
    lists ours among its ancestors. Everything else is a wrong observation id —
    the one mistake that would file a Kohlmeise under `blaumeise.jpg`.
    """
    taxon = observation.get("taxon") or {}
    ancestors = taxon.get("ancestor_ids") or []
    return taxon.get("id") == taxon_id or taxon_id in ancestors


@dataclass(frozen=True)
class Candidate:
    """One freely licensed photo, offered to a human for a decision."""

    bird_id: str
    taxon_id: int
    observation_id: int
    photo_id: int
    photographer: str
    license_code: str
    license: str
    photo_url: str
    observation_url: str
    width: int | None
    height: int | None

    @property
    def square_side(self) -> int | None:
        """The side of the largest square the original can yield."""
        if self.width is None or self.height is None:
            return None
        return min(self.width, self.height)


def photo_candidates(bird_id: str, taxon_id: int, observations: list[dict]) -> list[Candidate]:
    """Every usable photo of these observations, in the order the API returned.

    Photos whose licence or host disagrees with our rules are dropped rather
    than reported: the server was asked to filter, and an observation may hold
    a mix of licences even when it matched.
    """
    candidates = []

    for observation in observations:
        if not taxon_matches(observation, taxon_id):
            continue

        for photo in observation.get("photos") or []:
            url = photo.get("url")
            if not is_open_data(url):
                continue
            try:
                licence = licence_id(photo.get("license_code"))
            except LicenceError:
                continue

            dimensions = photo.get("original_dimensions") or {}
            candidates.append(
                Candidate(
                    bird_id=bird_id,
                    taxon_id=taxon_id,
                    observation_id=observation["id"],
                    photo_id=photo["id"],
                    photographer=photographer(observation),
                    license_code=photo["license_code"],
                    license=licence,
                    photo_url=original_url(url),
                    observation_url=OBSERVATION_URL.format(observation["id"]),
                    width=dimensions.get("width"),
                    height=dimensions.get("height"),
                )
            )

    return candidates


def find_photo(observation: dict, photo_id: int) -> dict:
    """The photo with that id, checked against both licence rules.

    Raises `LookupError` when the observation does not hold it and
    `LicenceError` when it may not be used — `pick` re-reads the API rather
    than trusting a candidate file that may be days old and whose photo may
    have changed its licence since.
    """
    for photo in observation.get("photos") or []:
        if photo.get("id") != photo_id:
            continue
        licence_id(photo.get("license_code"))
        if not is_open_data(photo.get("url")):
            raise LicenceError(
                f"photo {photo_id} is not served from {OPEN_DATA_HOST}, "
                "which contradicts the licence it declares"
            )
        return photo

    raise LookupError(f"observation {observation.get('id')} has no photo {photo_id}")


class Client:
    """A rate-limited, read-only client for the iNaturalist API."""

    def __init__(
        self,
        transport: httpx.BaseTransport | None = None,
        min_interval: float = MIN_INTERVAL,
    ) -> None:
        self._http = httpx.Client(
            base_url=API_ROOT,
            headers={"User-Agent": USER_AGENT},
            timeout=30.0,
            follow_redirects=True,
            transport=transport,
        )
        self._min_interval = min_interval
        self._last_request: float | None = None

    def __enter__(self) -> Client:
        return self

    def __exit__(self, *_: object) -> None:
        self._http.close()

    def _wait(self) -> None:
        """Hold the request rate the API documentation asks for."""
        if self._last_request is not None:
            pause = self._min_interval - (time.monotonic() - self._last_request)
            if pause > 0:
                time.sleep(pause)
        self._last_request = time.monotonic()

    def _get(self, url: str, params: dict | None = None) -> httpx.Response:
        """Fetch `url`, waiting out the rate limit first.

        One retry, because the server was observed to close a connection
        without answering. A whole pack is ten requests in a row; losing the
        ninth to a hiccup would mean asking for all ten again.
        """
        for attempt in (1, 2):
            self._wait()
            try:
                response = self._http.get(url, params=params)
                break
            except httpx.TransportError:
                if attempt == 2:
                    raise

        response.raise_for_status()
        return response

    def observations(self, taxon_id: int, per_page: int) -> list[dict]:
        """Research-grade observations of that taxon whose photos we may use."""
        payload = self._get(
            "/observations",
            {
                "taxon_id": taxon_id,
                "photo_license": PHOTO_LICENSE_FILTER,
                "quality_grade": "research",
                # taxon_id alone also returns subspecies; the pack names a
                # species and the photos should show it.
                "rank": "species",
                # Community favourites first. That is a popularity ranking, not
                # a didactic one — a human still looks at every candidate.
                "order_by": "votes",
                "per_page": per_page,
                "locale": "de",
            },
        )
        return payload.json().get("results") or []

    def observation(self, observation_id: int) -> dict:
        """One observation, read again at pick time to re-check its licence."""
        results = self._get(f"/observations/{observation_id}").json().get("results") or []
        if not results:
            raise LookupError(f"no observation {observation_id}")
        return results[0]

    def download(self, url: str) -> bytes:
        """The bytes behind a photo URL."""
        return self._get(url).content
