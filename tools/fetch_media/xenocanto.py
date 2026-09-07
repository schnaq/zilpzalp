"""Read-only access to the xeno-canto API, at curation time only.

Three findings that cost a day when they are rediscovered
(docs/medien-und-lizenzen.md, issue #16):

- **v2 is switched off** and v3 refuses every request without a key. The key
  lives in Infisical as `XENO_CANTO_API_KEY` and travels as a query parameter,
  which is why nothing here ever formats a URL into a message — see `redact`.
- **The `lic:` filter is mandatory.** Without it the answer is practically
  all NonCommercial: `sp:"Turdus merula"` alone returns 9537 recordings whose
  first hundred are exclusively BY-NC, BY-NC-SA and BY-NC-ND. With the filter
  the same species has 47 BY-SA, 61 PD and 17 BY. There is no way to ask for
  several licences at once, so a species costs one request per licence.
- **`numRecordings` is a string**, as is a recording's `id`.

Unlike iNaturalist, the server-side filter is not the last word: `lic:BY-SA`
also returns CC BY-SA **3.0**, which is not one of the three identifiers the
manifest, the licence gate and the Swift `License` enum share. Those
recordings are listed rather than dropped — a human should see that they
exist and why they cannot be used — so `licence_id` returns `None` for them
instead of raising, and `pick` refuses them.
"""

from __future__ import annotations

import os
import re
import time
from dataclasses import dataclass
from urllib.parse import urlparse

import httpx

API_ROOT = "https://xeno-canto.org/api/3"
RECORDING_URL = "https://xeno-canto.org/{}"

API_KEY_ENV = "XENO_CANTO_API_KEY"

# The API docs ask for a descriptive user agent, so a problem can be traced
# back to a project rather than to an anonymous script.
USER_AGENT = "zilpzalp-fetch-media/0.1 (+https://github.com/schnaq/zilpzalp)"

# "the server cannot usually accomodate indiscriminate automated requests" —
# one request per second is what the terms ask for, and it applies to the
# download of a recording just as much as to a search.
MIN_INTERVAL = 1.0

# The `lic:` values that return anything at all. `CC0` returns nothing; public
# domain recordings are filed under `PD`. Ordered as they are asked for:
# ShareAlike is the largest pool, PD the least demanding licence.
LICENCE_FILTERS = ("BY-SA", "BY", "PD")

# Quality better than C — that is A and B. Issue #16 prefers A and allows B,
# and #32 exists because Blaumeise and Buntspecht have no free A recording at
# all. Asking for both in one request keeps it at one request per licence.
QUALITY_FILTER = 'q:">C"'

# The `lic` field is a Creative Commons URL, and only these three name a
# licence the project may ship. CC BY-SA 3.0 is deliberately absent: recording
# it as `CC-BY-SA-4.0` would be a false attribution, and the licence gate and
# the Swift enum accept nothing else. Keys are normalised by `licence_key`.
LICENCES = {
    "creativecommons.org/publicdomain/zero/1.0": "CC0-1.0",
    "creativecommons.org/licenses/by/4.0": "CC-BY-4.0",
    "creativecommons.org/licenses/by-sa/4.0": "CC-BY-SA-4.0",
}

# For the messages that have to name what is allowed. Derived, so it cannot
# drift from the mapping above.
PERMITTED = ", ".join(sorted(LICENCES.values()))

# What the `type` field says when the recording is not the sound a child should
# learn: the flapping of a pheasant, a nestling begging, a call only ever heard
# at night. Measured over the ten base-pack species, these are 23 begging
# calls, 15 flight calls and 13 nocturnal flight calls out of 320 recordings.
# They are not errors — they are simply the wrong material for a quiz, so they
# stay out of the listing unless `--type` asks for them by name.
SKIPPED_TYPES = frozenset(
    {
        "begging call",
        "flight call",
        "nocturnal flight call",
        "wing flaps",
        "wingbeats",
        "wings noise",
        "hatchling or nestling",
    }
)

# The order the listing offers: song first, then call, then everything else —
# the preference issue #16 spells out. `type` is a free-text, comma-separated
# list ("call, bavardage, cri d'agitation"), so a descriptor is matched by
# substring, but only within one descriptor: "begging call" must not count as
# a call.
TYPE_GROUPS = ("song", "call")


class LicenceError(ValueError):
    """A licence xeno-canto reports that this project may not use.

    Nothing catches it by name — it exists because `cli.main` prints the class
    name, and "LicenceError" says at a glance what went wrong in the one
    refusal that matters most here.
    """


class XenoCantoError(RuntimeError):
    """A failed request, with the API key removed from the message."""


def redact(text: str) -> str:
    """Remove the API key from anything that might be printed.

    The key is a query parameter, so it is part of every request URL — and
    `httpx.HTTPStatusError` puts that URL into its message, which `cli.main`
    prints as an `::error::` line and CI keeps in its log. This is the single
    place that decides what a key looks like in text.
    """
    return re.sub(r"(?i)(key=)[^&\s'\"]+", r"\1…", text)


def api_key(environment: dict | None = None) -> str:
    """The key for the API, from the environment Infisical fills.

    Raises `RuntimeError` naming the *variable* that is missing — never its
    value, exactly as `s3.client_from_env` does for the bucket credentials.
    """
    environment = os.environ if environment is None else environment
    key = environment.get(API_KEY_ENV)
    if not key:
        raise RuntimeError(
            f"missing from the environment: {API_KEY_ENV}. "
            "Run through 'infisical run --env=dev --path=/ --'."
        )
    return key


def licence_key(url: object) -> str:
    """Normalise a Creative Commons URL to `host/path`, without the scheme.

    xeno-canto serves `https://creativecommons.org/licenses/by-sa/4.0/`; the
    scheme and the trailing slash are noise, everything else is the licence.
    """
    if not isinstance(url, str):
        return ""
    parsed = urlparse(url.strip().lower())
    return f"{parsed.hostname or ''}{parsed.path}".rstrip("/")


def licence_id(url: object) -> str | None:
    """The manifest identifier for a `lic` URL, `None` when we may not use it.

    `None` rather than an exception because the listing shows the unusable
    recordings: a species whose free stock is all CC BY-SA 3.0 is a finding
    for a human, not a silently shorter table.
    """
    return LICENCES.get(licence_key(url))


def licence_label(url: object) -> str:
    """What to print in a listing: the identifier, or why the licence is out.

    A recording we may not use is shown by its licence rather than hidden, so
    "all of this species is CC BY-SA 3.0" is visible instead of looking like an
    empty result.
    """
    mapped = licence_id(url)
    if mapped is not None:
        return mapped
    key = licence_key(url).removeprefix("creativecommons.org/").removeprefix("licenses/")
    return key or "no licence"


def recording_number(text: str) -> str:
    """The catalogue number of `965144` or `XC965144`, as the API spells it."""
    number = text.strip().upper().removeprefix("XC")
    if not number.isdigit():
        raise ValueError(f"expected an XC catalogue number, got '{text}'")
    return number


def descriptors(type_field: object) -> list[str]:
    """The `type` field split into its descriptors, lowercased."""
    if not isinstance(type_field, str):
        return []
    return [part.strip().lower() for part in type_field.split(",") if part.strip()]


def matches_type(found: list[str], wanted: str) -> bool:
    """Whether any single descriptor contains `wanted`.

    Per descriptor, not across the whole field: `--type call` should find
    "alarm call" and "call, bavardage", and it should also find "begging call"
    — a human who asks for it by name gets it, marked as unusual.
    """
    wanted = wanted.strip().lower()
    return any(wanted in descriptor for descriptor in found)


def is_skipped(found: list[str]) -> bool:
    """Whether every descriptor names a sound the game cannot use.

    A recording without any `type` at all is not skipped: it is unlabelled,
    not useless, and there are eight of them among the base pack's species.
    """
    return bool(found) and all(descriptor in SKIPPED_TYPES for descriptor in found)


def type_rank(found: list[str]) -> int:
    """Song before call before everything else."""
    for rank, group in enumerate(TYPE_GROUPS):
        if matches_type(found, group) and not is_skipped(found):
            return rank
    return len(TYPE_GROUPS)


@dataclass(frozen=True)
class Candidate:
    """One recording, offered to a human for a decision."""

    bird_id: str
    recording_id: str
    recordist: str
    license: str | None
    license_url: str
    quality: str
    type: str
    length: str
    sample_rate: str
    recording_url: str
    file_url: str
    file_name: str
    skipped: bool

    @property
    def usable(self) -> bool:
        """Whether `pick` would accept this recording."""
        return self.license is not None


def candidate(bird_id: str, record: dict) -> Candidate:
    """One API record as a candidate. Nothing is filtered here."""
    found = descriptors(record.get("type"))
    return Candidate(
        bird_id=bird_id,
        recording_id=str(record["id"]),
        recordist=str(record.get("rec") or "").strip(),
        license=licence_id(record.get("lic")),
        license_url=str(record.get("lic") or ""),
        quality=str(record.get("q") or ""),
        type=str(record.get("type") or ""),
        length=str(record.get("length") or ""),
        sample_rate=str(record.get("smp") or ""),
        recording_url=RECORDING_URL.format(record["id"]),
        file_url=str(record.get("file") or ""),
        file_name=str(record.get("file-name") or ""),
        skipped=is_skipped(found),
    )


def call_candidates(bird_id: str, records: list[dict], wanted: str | None = None) -> list[Candidate]:
    """The recordings worth showing, song first, then call, quality A first.

    Without `wanted` the sounds of `SKIPPED_TYPES` stay out. With it, only the
    recordings whose `type` contains it are shown — the skipped ones included,
    because that is the only way to reach the Buntspecht's drumming, which is
    didactically the better choice than its call (#32).

    Recordings we may not use sort last but stay in: they are a finding, not
    noise. The caller's `--limit` may cut them off, which is why the summary
    counts them separately.
    """
    candidates = [candidate(bird_id, record) for record in records]

    if wanted:
        candidates = [entry for entry in candidates if matches_type(descriptors(entry.type), wanted)]
    else:
        candidates = [entry for entry in candidates if not entry.skipped]

    # Stable, so recordings of equal rank and quality keep the API's order.
    return sorted(
        candidates,
        key=lambda entry: (not entry.usable, type_rank(descriptors(entry.type)), entry.quality),
    )


def find_recording(records: list[dict], recording_id: str) -> dict:
    """The one record with that XC number, or a `LookupError`."""
    for record in records:
        if str(record.get("id")) == str(recording_id):
            return record
    raise LookupError(f"xeno-canto has no recording XC{recording_id}")


def binomial(record: dict) -> str:
    """The species the recording is filed under, as `Genus species`.

    A subspecies carries its own `ssp` field and leaves `gen` and `sp` alone,
    so this is a complete comparison — unlike iNaturalist, where a subspecies
    has a taxon id of its own.
    """
    return f"{record.get('gen', '')} {record.get('sp', '')}".strip()


def attribution(record: dict) -> str:
    """Who to credit: the recordist and the XC catalogue number.

    The terms demand recordist, licence and catalogue number. The licence is a
    field of its own in the manifest and a column of its own in CREDITS.md, so
    repeating it here would print it twice on the credits screen.
    """
    recordist = str(record.get("rec") or "").strip()
    if not recordist:
        raise ValueError(f"XC{record.get('id')}: has no recordist to credit")
    return f"{recordist} (XC{record['id']})"


class Client:
    """A rate-limited, read-only client for the xeno-canto API."""

    def __init__(
        self,
        key: str,
        transport: httpx.BaseTransport | None = None,
        min_interval: float = MIN_INTERVAL,
    ) -> None:
        self._key = key
        self._http = httpx.Client(
            headers={"User-Agent": USER_AGENT},
            timeout=60.0,
            follow_redirects=True,
            transport=transport,
        )
        self._min_interval = min_interval
        self._last_request: float | None = None
        self.truncated: list[str] = []

    def __enter__(self) -> Client:
        return self

    def __exit__(self, *_: object) -> None:
        self._http.close()

    def _wait(self) -> None:
        """Hold the request rate the terms ask for — on every path."""
        if self._last_request is not None:
            pause = self._min_interval - (time.monotonic() - self._last_request)
            if pause > 0:
                time.sleep(pause)
        self._last_request = time.monotonic()

    def _get(self, url: str, params: dict | None = None) -> httpx.Response:
        """Fetch `url`, waiting out the rate limit first.

        One retry when the connection itself fails: a pack is thirty searches
        and ten downloads in a row, each a second apart, and losing the
        twenty-ninth to a hiccup would mean asking for all of them again.

        Every failure is re-raised as a `XenoCantoError` whose message has been
        through `redact`: an `HTTPStatusError` carries the request URL, and the
        request URL of a search carries the key.
        """
        try:
            self._wait()
            try:
                response = self._http.get(url, params=params)
            except httpx.TransportError:
                self._wait()
                response = self._http.get(url, params=params)

            response.raise_for_status()
            return response
        except httpx.HTTPError as error:
            raise XenoCantoError(redact(f"{type(error).__name__}: {error}")) from None

    def search(self, query: str) -> list[dict]:
        """The recordings for one query. The key is added here and nowhere else.

        Page 1 only, a hundred recordings. The richest of the base-pack species
        offers 61 under one licence, so a second page would be a surprise —
        and a human cannot listen to several hundred candidates anyway. A
        query that had more is remembered in `truncated`, so the counts the
        caller prints can say that they are a floor rather than a total.
        """
        payload = self._get(f"{API_ROOT}/recordings", {"query": query, "key": self._key}).json()
        if int(payload.get("numPages") or 1) > 1:
            self.truncated.append(query)
        return payload.get("recordings") or []

    def recordings(self, scientific_name: str) -> list[dict]:
        """Every freely licensed A or B recording of one species.

        One request per licence, because the API takes a single `lic:` value.
        """
        found = []
        for licence in LICENCE_FILTERS:
            found += self.search(f'sp:"{scientific_name}" lic:{licence} {QUALITY_FILTER}')
        return found

    def recording(self, recording_id: str) -> dict:
        """One recording by its XC number, re-read at pick time.

        Deliberately without a `lic:` filter: a recording whose licence is not
        one of ours must reach `pick` so it can say so, rather than come back
        as "no such recording".
        """
        return find_recording(self.search(f"nr:{recording_id}"), recording_id)

    def download(self, url: str) -> bytes:
        """The bytes behind a recording's download URL — no key involved."""
        return self._get(url).content
