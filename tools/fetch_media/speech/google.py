"""Google Cloud Text-to-Speech, the renderer issue #234 settled on.

Why this one, in one paragraph: Chirp 3 HD speaks native German at the current
top tier, the whole app is a few thousand characters a month against a free
tier of a million, and the grant is the plainest of the three that were read at
the source — *"You can use the audio data files you create using Cloud
Text-to-Speech to power your applications"*
(<https://docs.cloud.google.com/text-to-speech/docs/basics>), with no
attribution and no disclosure owed. ElevenLabs stays in the tree as
`elevenlabs.py` and is not used: that account is on the free tier, which is
non-commercial.

**One honest difference to `elevenlabs.py`.** ElevenLabs hands us the output in
writing (§4(c)(ii)), so `CC-BY-4.0` there is a claim about something we own.
Google grants *use*, and section 2.1 of
docs/superpowers/plans/2026-09-08-recorded-speech.md records that no ownership
clause could be read at the source — no prohibition either. Publishing the
clips under `CC-BY-4.0` is therefore Christian's decision in #234, not a
paraphrase of a licence. It is written down here so that nobody later mistakes
it for one.

Findings that would otherwise be rediscovered against a live project:

- **The key is a whole JSON document, not a string.** A service-account key
  arrives as one environment variable holding the file, and the request needs
  an OAuth2 access token rather than the key itself: a JWT signed with the
  account's private key (RS256) is exchanged at `token_uri` for a bearer token
  that lasts an hour. That is the whole of `token()` below, and it is why
  `cryptography` is the one dependency this adapter adds.
- **Three secrets, and only one of them is in the environment.** `keys.redact`
  blanks what the environment holds — the JSON blob. The private key inside it,
  the signed assertion and the access token are derived, so `_scrub` blanks
  those as well. A token endpoint that echoes an assertion back inside
  `error_description` is not hypothetical.
- **`pitch` is not sent.** Chirp 3 HD documents `pace`/`speakingRate` and says
  nothing about the `AudioConfig` `pitch` field for these voices; sending a
  field a model does not take is a 400 rather than a hint. `pitch: 0` means
  "unchanged" anyway, so omitting it changes nothing audible and cannot be
  refused. Do not re-add it.
- **LINEAR16 comes back with a RIFF header.** Unlike ElevenLabs' `pcm_24000`,
  which is headerless, `audioContent` decodes to a playable WAV. `samples()`
  therefore unwraps it and `wav_bytes` puts this project's own header back on,
  so that the WAV contract of `provider.py` is one shape rather than two — and
  so that a vendor that one day serves raw samples still works.

There is deliberately **no default voice**, for the reason `elevenlabs.py`
gives: which voice a child hears is a product decision. `speech voices
--provider google` lists the de-DE Chirp 3 HD voices; `--voice` then names one,
by its full name or by its short one.
"""

from __future__ import annotations

import base64
import json
import time
import wave
from io import BytesIO

import httpx
from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import padding

from fetch_media import keys
from fetch_media.speech.provider import RECORDING_DOC, Voice, VoiceOption, wav_bytes

API_ROOT = "https://texttospeech.googleapis.com/v1"

# The only language this app speaks, and the only one worth listing.
LANGUAGE = "de-DE"

# The voice family the plan compared: Chirp 3 HD. Standard and WaveNet voices
# are cheaper per character in a tier nobody here reaches, and they sound it.
FAMILY = "Chirp3-HD"

# 24 kHz, which is what Chirp 3 HD reports as its natural rate and what the
# ElevenLabs adapter asks for. The pipeline encodes to 64 kbit/s mono AAC
# afterwards, so a higher rate would be discarded by the encoder rather than
# heard by a child. `audio.py` forces no rate of its own.
RATE = 24000

# Deterministic as far as the API allows: the normal pace, spelled out rather
# than defaulted, so that a change of default at the vendor cannot change how a
# clip rendered next year compares with one rendered today. `pitch` is
# deliberately absent — see the module docstring.
SPEAKING_RATE = 1.0

# What the assertion asks for. `cloud-platform` is the scope the token endpoint
# takes for a service account; Text-to-Speech has no narrower one.
SCOPE = "https://www.googleapis.com/auth/cloud-platform"

# RFC 7523: a JWT presented in place of a password.
GRANT = "urn:ietf:params:oauth:grant-type:jwt-bearer"

# An hour is the maximum Google accepts for an assertion, and the token it
# returns lasts as long. The margin is for the clock and the flight time: a
# token that expires between the check and the request would fail one clip in a
# long run for no reason a human could see.
TOKEN_LIFETIME = 3600
TOKEN_MARGIN = 60

# What a sentence costs at the meter is what a sentence is worth waiting for.
TIMEOUT = 120.0

# The licence the clips are published under. Christian's decision in #234, not
# a quotation from Google's terms — see the module docstring.
LICENCE = "CC-BY-4.0"

# The fields a service-account key must have for this to work at all.
REQUIRED = ("client_email", "private_key", "token_uri")


class GoogleTTSError(RuntimeError):
    """A refused request, with every secret removed from the message."""


def attribution(name: str) -> str:
    """How the credits screen names the voice."""
    return f"Stimme: {name} (Google Cloud Text-to-Speech)"


def account(raw: str) -> dict:
    """The service-account key as a document, or a refusal naming the variable.

    Never the value: a malformed key is a wrong Infisical entry, and the way to
    say so is the variable's name, exactly as `keys.api_key` does for a missing
    one.
    """
    try:
        parsed = json.loads(raw)
    except (json.JSONDecodeError, ValueError):
        parsed = None

    if not isinstance(parsed, dict):
        raise GoogleTTSError(
            f"{keys.GOOGLE_TTS} is not a JSON document. It holds the whole "
            "service-account key file, as downloaded from the Google Cloud "
            "console — see docs/sprachaufnahmen.md."
        )

    missing = [field for field in REQUIRED if not parsed.get(field)]
    if missing:
        raise GoogleTTSError(
            f"{keys.GOOGLE_TTS} is missing {', '.join(missing)}. That is not a "
            "service-account key; a user credential or an API key will not do."
        )
    return parsed


def segment(payload: dict | bytes) -> bytes:
    """One base64url segment of a JWT, unpadded as RFC 7515 requires."""
    raw = payload if isinstance(payload, bytes) else json.dumps(payload, separators=(",", ":")).encode()
    return base64.urlsafe_b64encode(raw).rstrip(b"=")


def assertion(key: dict, now: int) -> str:
    """The signed JWT that buys an access token.

    Hand-rolled rather than `google-auth` or `pyjwt`: it is twenty lines
    against a specification that has not moved since 2015, and it keeps this
    tool at one new dependency — `cryptography`, which does the signing.
    """
    claims = {
        "iss": key["client_email"],
        "scope": SCOPE,
        "aud": key["token_uri"],
        "iat": now,
        "exp": now + TOKEN_LIFETIME,
    }
    signing_input = b".".join((segment({"alg": "RS256", "typ": "JWT"}), segment(claims)))

    try:
        private = serialization.load_pem_private_key(key["private_key"].encode(), password=None)
        signature = private.sign(signing_input, padding.PKCS1v15(), hashes.SHA256())
    except (ValueError, TypeError) as error:
        # The exception carries the reason, never the key material — but the
        # key material is what it was handed, so nothing of it is repeated.
        raise GoogleTTSError(
            f"the private key in {keys.GOOGLE_TTS} cannot be read "
            f"({type(error).__name__}). Download the key again as JSON."
        ) from None

    return b".".join((signing_input, segment(signature))).decode()


def samples(content: bytes) -> tuple[bytes, int]:
    """The 16-bit mono PCM inside `audioContent`, and its rate.

    LINEAR16 arrives as a playable WAV rather than as raw samples, so the
    header comes off here and `wav_bytes` puts this project's own back on. A
    response that is raw after all is passed straight through, at the rate that
    was asked for.
    """
    if not content.startswith(b"RIFF"):
        return content, RATE

    with wave.open(BytesIO(content), "rb") as source:
        if source.getnchannels() != 1 or source.getsampwidth() != 2:
            raise GoogleTTSError(
                f"the API answered with {source.getnchannels()} channel(s) at "
                f"{source.getsampwidth() * 8} bit, and a clip is mono 16-bit "
                "PCM — see speech/provider.py."
            )
        return source.readframes(source.getnframes()), source.getframerate()


def said(response: httpx.Response) -> str:
    """What the vendor called the problem, from either shape of error body.

    The API answers `{"error": {"message": …}}` and the token endpoint answers
    `{"error": "invalid_grant", "error_description": …}`. A refusal that
    printed "unparseable body" instead of "API has not been used" would send
    somebody to the wrong console page.
    """
    try:
        error = (response.json() or {}).get("error")
    except (json.JSONDecodeError, ValueError, AttributeError):
        error = None

    if isinstance(error, dict):
        told = str(error.get("message") or error.get("status") or "").strip()
    elif isinstance(error, str):
        description = ""
        try:
            description = str((response.json() or {}).get("error_description") or "").strip()
        except (json.JSONDecodeError, ValueError, AttributeError):
            description = ""
        told = f"{error}: {description}".strip(": ") if description else error.strip()
    else:
        told = ""

    return told or response.text.strip()[:200] or response.reason_phrase


def hint(status: int, told: str) -> str:
    """The sentence that turns a status code into something to go and do."""
    if "invalid_grant" in told:
        # A refusal from the token endpoint rather than from the API, and it
        # arrives as a 400 as readily as as a 401. The cause nobody suspects
        # is the last one named: an assertion signed against a clock that is
        # minutes out is rejected exactly like a wrong key.
        return (
            f" — the assertion was refused. Check that {keys.GOOGLE_TTS} holds "
            "the current key of a service account that still exists, and that "
            "this machine's clock is right."
        )
    if status == 401:
        return (
            f" — check {keys.GOOGLE_TTS}: it holds the whole service-account "
            "key file, and every command is wrapped in "
            "'infisical run --env=dev --path=/ --'."
        )
    if status == 403:
        return (
            " — the Cloud Text-to-Speech API is probably not enabled in that "
            "project, or the service account may not call it. Enable "
            "texttospeech.googleapis.com and give the account the "
            "Text-to-Speech role: docs/sprachaufnahmen.md."
        )
    if status == 429:
        return " — too many requests at once; wait and render again."
    if status == 400:
        return (
            " — check --voice against "
            "'fetch-media speech voices --provider google': a voice name is "
            f"the whole {LANGUAGE}-{FAMILY}-… string, and a misspelt one is a "
            "400 rather than a listing."
        )
    return ""


class GoogleProvider:
    """The provider `--provider google` selects."""

    name = "google"

    def __init__(self, transport: httpx.BaseTransport | None = None) -> None:
        # Read at construction rather than at the first request: a missing key
        # is a missing Infisical wrapper, and that is worth hearing before a
        # hundred sentences have been resolved.
        self._key = account(keys.api_key(keys.GOOGLE_TTS))
        self._http = httpx.Client(base_url=API_ROOT, timeout=TIMEOUT, transport=transport)
        # An access token lasts an hour, which is longer than any run: fetched
        # once, and again only if a run outlives it.
        self._token: str | None = None
        self._expires = 0.0
        # Everything derived from the key that must never reach a message. The
        # environment holds only the JSON blob, so `keys.redact` alone would
        # not catch these.
        self._derived: list[str] = [self._key["private_key"]]
        # One listing per run: every `render()` resolves the same `--voice`,
        # and asking the vendor once per clip would be a request per sentence
        # for an answer that cannot change.
        self._offered: list[VoiceOption] | None = None

    def _scrub(self, text: str) -> str:
        """A message with every secret gone — the environment's and the derived."""
        scrubbed = keys.redact(text)
        for secret in self._derived:
            if secret:
                scrubbed = scrubbed.replace(secret, keys.REPLACEMENT)
        return scrubbed

    def _fail(self, response: httpx.Response) -> GoogleTTSError:
        told = said(response)
        return GoogleTTSError(
            self._scrub(f"{response.status_code}: {told}{hint(response.status_code, told)}")
        )

    def token(self) -> str:
        """A bearer token for this run, bought with a freshly signed assertion."""
        if self._token and time.time() < self._expires - TOKEN_MARGIN:
            return self._token

        signed = assertion(self._key, int(time.time()))
        self._derived.append(signed)
        try:
            response = self._http.post(
                self._key["token_uri"],
                data={"grant_type": GRANT, "assertion": signed},
                headers={"Content-Type": "application/x-www-form-urlencoded"},
            )
        except httpx.HTTPError as error:
            raise GoogleTTSError(
                self._scrub(f"{type(error).__name__}: {error} — reaching {self._key['token_uri']}")
            ) from None

        if response.is_error:
            raise self._fail(response)

        granted = response.json() or {}
        self._token = str(granted.get("access_token") or "")
        if not self._token:
            raise GoogleTTSError(
                f"{self._key['token_uri']} answered without an access token."
            )
        self._derived.append(self._token)
        self._expires = time.time() + float(granted.get("expires_in") or TOKEN_LIFETIME)
        return self._token

    def _request(self, method: str, url: str, **kwargs: object) -> httpx.Response:
        """One call, with every failure named without naming a secret."""
        bearer = {"Authorization": f"Bearer {self.token()}"}
        try:
            response = self._http.request(method, url, headers=bearer, **kwargs)
        except httpx.HTTPError as error:
            raise GoogleTTSError(self._scrub(f"{type(error).__name__}: {error}")) from None

        if response.is_error:
            raise self._fail(response)
        return response

    def voices(self) -> list[VoiceOption]:
        """The German Chirp 3 HD voices, as `speech voices` prints them.

        Filtered rather than listed whole: the endpoint answers with every
        voice of every family, and a list of two hundred names in which only
        thirty can be chosen is not a list a person reads.
        """
        if self._offered is None:
            payload = self._request("GET", "/voices", params={"languageCode": LANGUAGE}).json()
            self._offered = [
                VoiceOption(
                    id=str(entry.get("name") or ""),
                    name=str(entry.get("name") or "").rsplit("-", 1)[-1],
                    description=(
                        f"{str(entry.get('ssmlGender') or 'unspecified').lower()}, "
                        f"{entry.get('naturalSampleRateHertz') or RATE} Hz"
                    ),
                )
                for entry in (payload.get("voices") or [])
                if FAMILY in str(entry.get("name") or "")
                and LANGUAGE in (entry.get("languageCodes") or [])
            ]
        return self._offered

    def chosen(self, voice: str | None) -> VoiceOption:
        """The voice `--voice` names, by its full name or by its short one.

        Refuses rather than picks: a run without `--voice` would otherwise
        record whichever voice the API happens to list first, and the pack
        would carry it for good.
        """
        if not voice:
            raise ValueError(
                "--voice names the voice to speak with: a name from "
                "'fetch-media speech voices --provider google'."
            )

        offered = self.voices()
        for option in offered:
            if voice in (option.id, option.name):
                return option

        known = ", ".join(option.id for option in offered) or "none"
        raise LookupError(f"no {LANGUAGE} {FAMILY} voice '{voice}' (offered: {known})")

    def voice(self, voice: str | None = None) -> Voice:
        """Who is heard, and under which licence the clips are published."""
        return Voice(
            license=LICENCE,
            attribution=attribution(self.chosen(voice).name),
            source_url=RECORDING_DOC,
        )

    def render(self, text: str, voice: str | None = None) -> bytes:
        """Speak one German sentence, as WAV bytes."""
        option = self.chosen(voice)
        response = self._request(
            "POST",
            "/text:synthesize",
            json={
                "input": {"text": text},
                "voice": {"languageCode": LANGUAGE, "name": option.id},
                "audioConfig": {
                    "audioEncoding": "LINEAR16",
                    "sampleRateHertz": RATE,
                    "speakingRate": SPEAKING_RATE,
                },
            },
        )
        content = base64.b64decode((response.json() or {}).get("audioContent") or "")
        if not content:
            raise GoogleTTSError("the API answered without any audio.")
        return wav_bytes(*samples(content))
