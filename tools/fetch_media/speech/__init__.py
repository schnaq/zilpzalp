"""Recorded speech: the sentences the app says out loud.

`fetch-media speech render` asks a provider for a sentence; `fetch-media speech
import` takes a take somebody recorded. Both end in the same place — a mono
AAC clip beside the manifest, normalised to the loudness every other sound in
the game sits at, and one entry in the manifest that names it.

The core knows no vendor. `provider.py` is the whole interface, `fake.py` the
adapter the tests use, and `elevenlabs.py` the one that speaks — since
2026-10-20 (#221), when the schnaq account went on the paid Starter tier and
`eleven_v3` turned out to say a bare German bird name in German. `google.py`
(#234) stays as the alternative it replaced and is not used.
"""

from __future__ import annotations

from fetch_media.speech.elevenlabs import ElevenLabsProvider
from fetch_media.speech.fake import FakeProvider
from fetch_media.speech.google import GoogleProvider
from fetch_media.speech.provider import RECORDING_DOC, RENDERED_FILE, Provider, Voice, VoiceOption

# Every adapter this tool can be pointed at. `--provider` takes its choices
# from here, so a new adapter is one entry and no change to the command line.
PROVIDERS: dict[str, type] = {
    FakeProvider.name: FakeProvider,
    ElevenLabsProvider.name: ElevenLabsProvider,
    GoogleProvider.name: GoogleProvider,
}

# The licence a recording of our own carries. Decision 3 of the plan proposes
# CC BY 4.0 — the gate's `ALLOWED_LICENCES` takes it, and the attribution names
# whose voice it is. A different answer to that decision changes this line and
# nothing else. The document behind the `sourceURL` lives in `provider.py`,
# where the adapters can reach it without importing this module.
IMPORT_LICENCE = "CC-BY-4.0"

# How long a clip has to last before `render` believes the sentence was said to
# the end (#310): a cut clip is a valid file at the right loudness, so only its
# length gives it away. A heuristic, calibrated against every clip in the
# repository — the numbers and what they flag are in docs/sprachaufnahmen.md,
# "Short texts come back cut off". Tune these two, not the code.
SECONDS_PER_CHARACTER = 0.05
SHORTEST = 0.5

__all__ = [
    "IMPORT_LICENCE",
    "PROVIDERS",
    "RECORDING_DOC",
    "RENDERED_FILE",
    "Provider",
    "Voice",
    "VoiceOption",
    "imported_voice",
    "provider",
    "shortest",
]


def provider(name: str) -> Provider:
    """The adapter of that name, ready to speak."""
    if name not in PROVIDERS:
        known = ", ".join(sorted(PROVIDERS))
        raise LookupError(f"no speech provider '{name}' (have: {known})")
    return PROVIDERS[name]()


def imported_voice(attribution: str) -> Voice:
    """Who is heard on a take somebody recorded — `import`'s answer to `voice()`.

    A human with a microphone is a source like any other, so its licence lives
    beside the adapters' rather than in the command line that calls them.
    """
    return Voice(license=IMPORT_LICENCE, attribution=attribution, source_url=RECORDING_DOC)


def shortest(text: str) -> float:
    """The fewest seconds a clip of `text` may last without counting as cut off."""
    return max(SHORTEST, SECONDS_PER_CHARACTER * len(text))
