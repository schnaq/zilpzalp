"""What a voice provider has to be — and nothing about any particular one.

The core of `fetch-media speech` knows no vendor. It hands a provider a German
sentence and gets audio back, and it asks the provider who spoke and under
which licence so that the manifest can say it. Everything else — an API key, a
model name, a rate limit, a price — lives inside the adapter.

**A `render` returns 16-bit PCM in a WAV container.** Not MP3, not raw samples:
`audio.trim` hands the bytes to `afconvert`, which picks its reader by file
extension, and a WAV is the one format every provider can serve and the tool
can name without guessing. An adapter whose vendor speaks MP3 converts before
it returns.

A real adapter therefore implements four things: `name`, `voices()`, `voice()`
and `render()`. `voices()` is what `speech voices` lists — a provider that
offers no choice returns nothing and the command says so. An adapter reads its
key from the environment where `infisical run --env=dev --path=/ --` puts it —
see `fetch_media.keys` — and it never puts that key into a message. The first
real one is `elevenlabs.py`, decisions 1 and 2 of
docs/superpowers/plans/2026-09-08-recorded-speech.md.
"""

from __future__ import annotations

import dataclasses
import wave
from io import BytesIO
from typing import ClassVar, Protocol

# What a provider hands back is named for afconvert, which picks its reader by
# file extension: the name is how the WAV contract above is enforced.
RENDERED_FILE = "speech.wav"

# The document behind every `voice.sourceURL` this tool writes: how a sentence
# is produced, so that a clip made next year sounds like one made today. It
# lives here rather than in the package's `__init__` because an adapter needs
# it and the `__init__` imports the adapters.
RECORDING_DOC = "https://github.com/schnaq/zilpzalp/blob/main/docs/sprachaufnahmen.md"


def wav_bytes(samples: bytes, rate: int, channels: int = 1, sample_width: int = 2) -> bytes:
    """Raw 16-bit PCM as the WAV container every adapter owes `audio.trim`.

    Here rather than in an adapter because it is the contract above rather
    than a vendor's business: `fake` synthesises the samples and ElevenLabs
    fetches them, and both hand back the same kind of file.
    """
    buffer = BytesIO()
    with wave.open(buffer, "wb") as sink:
        sink.setnchannels(channels)
        sink.setsampwidth(sample_width)
        sink.setframerate(rate)
        sink.writeframes(samples)
    return buffer.getvalue()


@dataclasses.dataclass(frozen=True)
class Voice:
    """Who speaks, under which licence — the manifest's `voice` without its date.

    One voice per manifest, so this is what every clip in a pack shares. The
    licence has to be one the gate allows (`CC0-1.0`, `CC-BY-4.0`,
    `CC-BY-SA-4.0`); a provider whose terms fit none of them cannot be used
    here, whatever it sounds like.
    """

    license: str
    attribution: str
    source_url: str


@dataclasses.dataclass(frozen=True)
class VoiceOption:
    """One voice a provider offers — what `speech voices` puts on a line."""

    id: str
    name: str
    description: str


class Provider(Protocol):
    """A source of spoken German."""

    name: ClassVar[str]

    def voices(self) -> list[VoiceOption]:
        """Every voice a `--voice` may name. Empty where there is no choice."""

    def voice(self, voice: str | None = None) -> Voice:
        """Who this provider speaks as, for the manifest and the credits.

        Takes the same `voice` as `render` does, and for the same reason: with
        a vendor that offers a hundred of them, who is heard — and therefore
        what the credits say — is decided by the command line, not by the
        adapter.
        """

    def render(self, text: str, voice: str | None = None) -> bytes:
        """Speak `text`, as WAV bytes. `voice` names one the provider offers."""
