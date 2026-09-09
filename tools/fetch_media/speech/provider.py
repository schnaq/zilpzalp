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

A real adapter therefore implements three things: `name`, `voice()` and
`render()`. It reads its key from the environment where
`infisical run --env=dev --path=/ --` puts it — see `fetch_media.keys` — and it
never puts that key into a message. Which vendor gets written first is
decisions 1 and 2 of docs/superpowers/plans/2026-09-08-recorded-speech.md.
"""

from __future__ import annotations

import dataclasses
from typing import ClassVar, Protocol, runtime_checkable


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


@runtime_checkable
class Provider(Protocol):
    """A source of spoken German."""

    name: ClassVar[str]

    def voice(self) -> Voice:
        """Who this provider speaks as, for the manifest and the credits."""

    def render(self, text: str, voice: str | None = None) -> bytes:
        """Speak `text`, as WAV bytes. `voice` names one the provider offers."""
