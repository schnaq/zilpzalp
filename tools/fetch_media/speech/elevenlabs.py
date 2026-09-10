"""ElevenLabs, the vendor decision 1 of the plan settled on.

Why this one, in one paragraph: it is the only vendor whose terms were read at
the source and found to grant both commercial use and **ownership of the
output** — EEA Terms of Service §1(c) and §4(c)(ii), quoted in section 2 of
docs/superpowers/plans/2026-09-08-recorded-speech.md. Ownership is what makes
`CC-BY-4.0` in the manifest a claim this project may make; a grant of mere
*use* would not. Three conditions come with it and none of them is code:
the account is **schnaq GmbH's**, the clips are rendered **while the paid
subscription is active** (the free tier is non-commercial), and the Sound
Effects product is never used for a shipped asset.

Four findings that would otherwise be rediscovered against a paid meter:

- **`language_code` is not supported by `eleven_multilingual_v2`.** The API
  reference says so in as many words, and sending it anyway is an error rather
  than a hint. German is enforced by the German text and by a German voice, so
  nothing here sends it. Do not re-add it.
- **`seed` is best effort.** *"Determinism is not guaranteed"* — two renders of
  one sentence may differ. That is why `--species` and `--sentence` exist: a
  re-render is aimed at one clip rather than at a pack.
- **`pcm_44100` needs the Pro tier and `mp3_44100_192` the Creator tier.**
  `pcm_24000` is the best format Starter serves, and it arrives as raw
  headerless 16-bit little-endian samples — `wave` puts the header on, which is
  the whole conversion and keeps the WAV contract of `provider.py` intact.
- **The message is in `detail`**, which is sometimes an object with `status`
  and `message` and sometimes a bare string, and a tier or quota problem comes
  back as a 401 just as a wrong key does. Everything goes through
  `keys.redact`: the key travels as a header, and an error body can echo it.

There is deliberately **no default voice**. Which voice a child hears is a
product decision (with Johanna, per the issue), and a voice id baked in here
would be the one nobody chose. `speech voices --provider elevenlabs` lists what
the account offers; `--voice` then names one, by id or by name.
"""

from __future__ import annotations

import json
import wave
from io import BytesIO

import httpx

from fetch_media import keys
from fetch_media.speech.provider import RECORDING_DOC, Voice, VoiceOption

API_ROOT = "https://api.elevenlabs.io/v1"

# Multilingual v2 is the model the plan compared and priced. Flash and Turbo
# are faster and cheaper and sound it; a clip is rendered once and heard for
# years, so latency is worth nothing here and quality is worth everything.
MODEL = "eleven_multilingual_v2"

# 24 kHz signed 16-bit little-endian, the best the Starter tier serves. The
# pipeline encodes to mono AAC afterwards, so anything above this would be
# thrown away by the encoder rather than heard by a child.
OUTPUT_FORMAT = "pcm_24000"
RATE = 24000
SAMPLE_WIDTH = 2
CHANNELS = 1

# Deterministic as far as the vendor allows: a fixed seed, no style
# exaggeration, and a stability high enough that two renders of one sentence
# are the same performance rather than two moods. `speaker_boost` is off
# because it colours the voice, and a child hears the clip on a phone speaker
# where that colour is not an improvement.
SEED = 20260908
VOICE_SETTINGS = {
    "stability": 0.8,
    "similarity_boost": 0.8,
    "style": 0.0,
    "use_speaker_boost": False,
}

# What a sentence costs at the meter is what a sentence is worth waiting for.
TIMEOUT = 120.0

# The licence the clips are published under, and it is ours to give: §4(c)(ii)
# leaves every right in the output with us. The same value `speech.__init__`
# uses for a take somebody recorded — one voice line, whoever spoke it.
LICENCE = "CC-BY-4.0"


class ElevenLabsError(RuntimeError):
    """A refused request, with the API key removed from the message."""


def attribution(name: str) -> str:
    """How the credits screen names the voice."""
    return f"Stimme: {name} (ElevenLabs)"


def wrapped(samples: bytes) -> bytes:
    """Raw PCM as the WAV every adapter owes `audio.trim`."""
    buffer = BytesIO()
    with wave.open(buffer, "wb") as sink:
        sink.setnchannels(CHANNELS)
        sink.setsampwidth(SAMPLE_WIDTH)
        sink.setframerate(RATE)
        sink.writeframes(samples)
    return buffer.getvalue()


def message(response: httpx.Response) -> str:
    """What went wrong, as a line a human can act on.

    The body is read defensively because it arrives in three shapes — an
    object under `detail`, a string under `detail`, or no JSON at all — and a
    refusal that printed "unparseable body" instead of "quota exceeded" would
    send somebody to the dashboard for nothing.
    """
    try:
        detail = (response.json() or {}).get("detail")
    except (json.JSONDecodeError, ValueError, AttributeError):
        detail = None

    if isinstance(detail, dict):
        said = str(detail.get("message") or detail.get("status") or "").strip()
    elif isinstance(detail, str):
        said = detail.strip()
    else:
        said = ""

    if not said:
        said = response.text.strip()[:200] or response.reason_phrase

    hint = ""
    if response.status_code == 401:
        # A 401 is not only a wrong key here: an expired subscription and a
        # free account asked for commercial use both look like this.
        hint = (
            " — check ELEVENLABS_API_KEY, and that the schnaq subscription is "
            "still active (a free account may not render what we ship)."
        )
    elif response.status_code == 402:
        hint = " — the character quota of the plan is used up."
    elif response.status_code == 429:
        hint = " — too many requests at once; wait and render again."
    elif "output_format" in said:
        hint = (
            f" — {OUTPUT_FORMAT} needs a tier this account does not have. The "
            "Starter fallback is mp3_44100_128, and that also means naming the "
            "rendered file .mp3 in speech/provider.py."
        )

    return keys.redact(f"{response.status_code}: {said}{hint}")


class ElevenLabsProvider:
    """The provider `--provider elevenlabs` selects."""

    name = "elevenlabs"

    def __init__(self, key: str | None = None, transport: httpx.BaseTransport | None = None) -> None:
        # Read at construction, not at the first request: a missing key is a
        # missing Infisical wrapper, and finding that out before a hundred
        # sentences have been resolved is the friendlier order.
        self._key = key or keys.api_key(keys.ELEVENLABS)
        self._http = httpx.Client(
            base_url=API_ROOT,
            headers={"xi-api-key": self._key},
            timeout=TIMEOUT,
            transport=transport,
        )
        # One listing per run: `voice()` and every `render()` of a run resolve
        # the same `--voice`, and asking the vendor once per clip who that is
        # would be a request per sentence for an answer that cannot change.
        self._offered: list[VoiceOption] | None = None

    def _request(self, method: str, url: str, **kwargs: object) -> httpx.Response:
        """One call, with every failure named without naming the key."""
        try:
            response = self._http.request(method, url, **kwargs)
        except httpx.HTTPError as error:
            raise ElevenLabsError(keys.redact(f"{type(error).__name__}: {error}")) from None

        if response.is_error:
            raise ElevenLabsError(message(response))
        return response

    def voices(self) -> list[VoiceOption]:
        """Every voice the account may speak with, as the dashboard shows them."""
        if self._offered is None:
            payload = self._request("GET", "/voices").json()
            self._offered = [
                VoiceOption(
                    id=str(entry.get("voice_id") or ""),
                    name=str(entry.get("name") or ""),
                    description=str(entry.get("description") or entry.get("category") or ""),
                )
                for entry in (payload.get("voices") or [])
            ]
        return self._offered

    def chosen(self, voice: str | None) -> VoiceOption:
        """The voice `--voice` names, by id or by name.

        Refuses rather than picks: a run without `--voice` would otherwise
        record whichever voice the account happens to list first, and the pack
        would carry it for good.
        """
        if not voice:
            raise ValueError(
                "--voice names the voice to speak with: an id or a name from "
                "'fetch-media speech voices --provider elevenlabs'."
            )

        offered = self.voices()
        for option in offered:
            if voice in (option.id, option.name):
                return option

        known = ", ".join(f"{option.name} ({option.id})" for option in offered) or "none"
        raise LookupError(f"no voice '{voice}' on this account (offered: {known})")

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
            f"/text-to-speech/{option.id}",
            params={"output_format": OUTPUT_FORMAT},
            json={
                "text": text,
                "model_id": MODEL,
                "voice_settings": dict(VOICE_SETTINGS),
                "seed": SEED,
            },
        )
        return wrapped(response.content)
