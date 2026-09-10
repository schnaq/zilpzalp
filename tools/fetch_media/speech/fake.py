"""A provider that says nothing, and says it the same way every time.

It exists so that the command line, the manifest write and the encoding can be
run and tested without a vendor, a key or a network — the rule
`tools/tests/` already follows for iNaturalist and xeno-canto. What comes out
is a short tone per word: no speech, but the right shape — a rhythm, silence at
both ends for the trim to find, and a level well below full scale for the
normaliser to lift.

Deterministic on purpose: the same sentence produces the same samples, so a
test can re-render a clip and ask whether anything changed. Nothing it produces
is meant to be heard by a child, and nothing it produces belongs in
`data/packs/` — the rule "nothing audible is committed unheard" applies to the
silence too.
"""

from __future__ import annotations

import array
import hashlib
import math
import wave
from io import BytesIO

from fetch_media.speech.provider import Voice, VoiceOption

RATE = 22050

# A word is a quarter of a second of tone, with a breath between two of them
# and silence at either end that the silence trim has to find and drop.
WORD = 0.24
GAP = 0.06
EDGE = 0.15

# About -21 dBFS, deliberately not near full scale: a clip that already sat at
# the target would not prove that the normaliser did anything.
AMPLITUDE = 3000

# The range a voice roughly moves in, so that a sentence has a shape rather
# than one note.
LOWEST = 180.0
HIGHEST = 320.0


def pitch(word: str) -> float:
    """A frequency for one word — the same one every time, from its digest."""
    digest = int(hashlib.sha256(word.encode("utf-8")).hexdigest()[:8], 16)
    return LOWEST + (digest % 1000) / 1000 * (HIGHEST - LOWEST)


def samples(text: str) -> array.array:
    """One tone burst per word, faded at both ends so that nothing clicks."""
    frames = array.array("h", [0] * int(EDGE * RATE))

    for word in text.split() or [text]:
        length = int(WORD * RATE)
        frequency = pitch(word)
        for index in range(length):
            # A raised cosine over the whole burst: the burst is short enough
            # that an envelope of its own length is the simplest one that does
            # not click at either end.
            envelope = 0.5 - 0.5 * math.cos(2 * math.pi * index / length)
            frames.append(
                int(AMPLITUDE * envelope * math.sin(2 * math.pi * frequency * index / RATE))
            )
        frames.extend([0] * int(GAP * RATE))

    frames.extend([0] * int(EDGE * RATE))
    return frames


class FakeProvider:
    """The provider `--provider fake` selects."""

    name = "fake"

    def voices(self) -> list[VoiceOption]:
        """None: there is one set of tones and `--voice` does not change it."""
        return []

    def voice(self, voice: str | None = None) -> Voice:
        """Nobody, in the public domain — there is no performance to license."""
        return Voice(
            license="CC0-1.0",
            attribution="Synthetic test tones (fetch-media speech, provider 'fake')",
            source_url=(
                "https://github.com/schnaq/zilpzalp/blob/main/tools/fetch_media/speech/fake.py"
            ),
        )

    def render(self, text: str, voice: str | None = None) -> bytes:
        """The sentence as tones, in a WAV container. `voice` changes nothing."""
        buffer = BytesIO()
        with wave.open(buffer, "wb") as sink:
            sink.setnchannels(1)
            sink.setsampwidth(2)
            sink.setframerate(RATE)
            sink.writeframes(samples(text).tobytes())
        return buffer.getvalue()
