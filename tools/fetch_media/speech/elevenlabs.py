"""ElevenLabs, the renderer this project uses (Christian, 2026-10-20, #221).

Why this one, in one paragraph: it is the only vendor whose terms were read at
the source and found to grant both commercial use and **ownership of the
output** — EEA Terms of Service §1(c) and §4(c)(ii), quoted in section 2 of
docs/superpowers/plans/2026-09-08-recorded-speech.md. Ownership is what makes
`CC-BY-4.0` in the manifest a claim this project may make; a grant of mere
*use* would not. Three conditions come with it and none of them is code:
the account is **schnaq GmbH's**, the clips are rendered **while the paid
subscription is active** (the free tier is non-commercial), and the Sound
Effects product is never used for a shipped asset.

Six findings that would otherwise be rediscovered against a paid meter:

- **A bare bird name needs `eleven_v3` with `language_code` "de".**
  `eleven_multilingual_v2` guesses the language from the text, and one word is
  too little to guess from: it said „Amsel" and „Zilpzalp" in English. It also
  rejects `language_code`; v3 takes it and then speaks German. v3 accepted
  every field of `VOICE_SETTINGS` and the `seed` as they stand (tried
  2026-10-20); it ignores `speed`, which is why none is sent.
- **v3 cuts a short text off at the end** (#310, tried 2026-10-21): „Welche
  Vögel?" came back as 0.64 s, in PCM and in MP3 alike, and several bare
  names lost their last sound — „Uhu" lasted 0.4 s. Every text is therefore
  sent as `[ruhig] <text> ...`: an audio tag in front, an ellipsis behind.
  Christian listened to the variants and chose this one — „Welche Vögel?",
  „Amsel" and „Zilpzalp" came out whole and calm. The tag alone or the
  ellipsis alone also saved the sentence; both together are what was heard
  and approved, for every text. The wrapping is this adapter's business: the
  manifest's `text` stays the plain sentence the clip says, and the length
  check in `cli.py` still catches a clip that comes back cut. „Uhu" needed
  more than the wrapping — its `pronunciation` „Der Uhu" in the pack data.
- **A library voice is not in the account's `/voices`.** Ava, the voice
  Christian chose, renders by id without being added to the account, but no
  listing names her — and the schnaq key lacks `voices_read`, so the listing
  is refused outright. `--voice <id>=<name>` therefore names both and asks
  nobody: the id is what speaks, the name is for the humans running it — the
  credits say only `AI_VOICE` (#338).
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
product decision, and a voice id baked in here would outlive it. The choice
lives in docs/sprachaufnahmen.md; `--voice` names it on every run, by id, by
name, or as `<id>=<name>` for a voice the account does not list.
"""

from __future__ import annotations

import json

import httpx

from fetch_media import keys
from fetch_media.speech.provider import AI_VOICE, RECORDING_DOC, Voice, VoiceOption, wav_bytes
from fetch_media.speech.sentences import LANGUAGE

API_ROOT = "https://api.elevenlabs.io/v1"

# v3, because it is the model that takes `language_code` — see the first
# finding above. Flash and Turbo are faster and cheaper and sound it; a clip is
# rendered once and heard for years, so latency is worth nothing here.
MODEL = "eleven_v3"

# 24 kHz signed 16-bit little-endian, the best the Starter tier serves. The
# pipeline encodes to mono AAC afterwards, so anything above this would be
# thrown away by the encoder rather than heard by a child.
OUTPUT_FORMAT = "pcm_24000"
RATE = 24000

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

# What every text is wrapped in — see the finding on cut-off texts above.
PREFIX = "[ruhig] "
SUFFIX = " ..."

# What a sentence costs at the meter is what a sentence is worth waiting for.
TIMEOUT = 120.0

# The licence the clips are published under, and it is ours to give: §4(c)(ii)
# leaves every right in the output with us. The same value `speech.__init__`
# uses for a take somebody recorded — one voice line, whoever spoke it.
LICENCE = "CC-BY-4.0"


class ElevenLabsError(RuntimeError):
    """A refused request, with the API key removed from the message."""


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
            "fallback is mp3_44100_128, which this adapter would then have to "
            "decode before it returns: a render is WAV, see speech/provider.py."
        )

    return keys.redact(f"{response.status_code}: {said}{hint}")


class ElevenLabsProvider:
    """The provider `--provider elevenlabs` selects."""

    name = "elevenlabs"

    def __init__(self, transport: httpx.BaseTransport | None = None) -> None:
        # The key comes from the environment and from nowhere else: `redact`
        # blanks what the environment holds, so a key handed in by another
        # route would be the one that reaches a log. Read at construction
        # rather than at the first request, because a missing key is a missing
        # Infisical wrapper and that is worth hearing before a hundred
        # sentences have been resolved.
        self._http = httpx.Client(
            base_url=API_ROOT,
            headers={"xi-api-key": keys.api_key(keys.ELEVENLABS)},
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
        would carry it for good. `<id>=<name>` asks nobody — the way to a
        library voice the account does not list.
        """
        if not voice:
            raise ValueError(
                "--voice names the voice to speak with: an id or a name from "
                "'fetch-media speech voices --provider elevenlabs', or <id>=<name>."
            )

        voice_id, given, name = voice.partition("=")
        if given:
            if not (voice_id and name):
                raise ValueError(f"--voice '{voice}': <id>=<name> needs both an id and a name")
            return VoiceOption(id=voice_id, name=name, description="")

        offered = self.voices()
        for option in offered:
            if voice in (option.id, option.name):
                return option

        known = ", ".join(f"{option.name} ({option.id})" for option in offered) or "none"
        raise LookupError(f"no voice '{voice}' on this account (offered: {known})")

    def voice(self, voice: str | None = None) -> Voice:
        """Who is heard, and under which licence the clips are published."""
        self.chosen(voice)  # refuses a run that names no voice, or an unknown one
        return Voice(license=LICENCE, attribution=AI_VOICE, source_url=RECORDING_DOC)

    def render(self, text: str, voice: str | None = None, take: int = 0) -> bytes:
        """Speak one German sentence, as WAV bytes. A later `take` gets the next seed."""
        option = self.chosen(voice)
        response = self._request(
            "POST",
            f"/text-to-speech/{option.id}",
            params={"output_format": OUTPUT_FORMAT},
            json={
                "text": f"{PREFIX}{text}{SUFFIX}",
                "model_id": MODEL,
                "language_code": LANGUAGE,
                "voice_settings": dict(VOICE_SETTINGS),
                "seed": SEED + take,
            },
        )
        return wav_bytes(response.content, RATE)
