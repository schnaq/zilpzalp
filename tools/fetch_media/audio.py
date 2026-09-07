"""Turn a downloaded recording into the few seconds the game plays.

One shape for every call, the way `images.py` gives every photo one shape:
mono, AAC-LC in an `.m4a` container at roughly 64 kbit/s. Six seconds are
about 50 KB, small enough to bundle ten of them and to download a pack over a
phone connection, and AVAudioPlayer plays the container natively.

**No ffmpeg, no Homebrew.** The decoder and the encoder are `afconvert`, which
is part of macOS, and everything between them is the standard library: `wave`
reads and writes the PCM, `array` trims it. That is why this module adds no
dependency to `tools/pyproject.toml`.

Two things `afconvert` does that are not obvious:

- **It picks its reader by file extension.** A perfectly good WAV named
  `.mp3` fails with `Couldn't open input file ('dta?')`, and xeno-canto serves
  both. The extension therefore comes from the recording's `file-name`.
- **It resamples above 48 kHz by itself.** A 96 kHz source comes out at
  48 kHz, so no rate needs to be forced — and forcing 44.1 kHz on a 48 kHz
  source measurably enlarges the file for nothing.

Trimming is a derivative work. That is the act ShareAlike governs and
NoDerivatives would forbid, which is why the project takes neither ND nor NC
(docs/medien-und-lizenzen.md).
"""

from __future__ import annotations

import array
import shutil
import subprocess
import tempfile
import wave
from pathlib import Path

BINARY = "afconvert"

EXTENSION = ".m4a"
FILE_FORMAT = "m4af"
DATA_FORMAT = "aac"
BITRATE = "64000"

# Raw recordings run from five seconds to over two minutes. Six is long enough
# to recognise a song and short enough that a child does not wait for the next
# question.
DURATION = 6.0

# Long enough that no cut clicks, short enough that the first note survives.
FADE = 0.04

# What xeno-canto serves, and what afconvert reads. The suffix decides the
# reader, so an unknown one is an error rather than a guess.
SOURCE_SUFFIXES = frozenset({".mp3", ".wav", ".flac"})

# 16-bit signed PCM, the format `wave` and `array('h')` agree on.
SAMPLE_WIDTH = 2
SAMPLE_TYPE = "h"


def source_suffix(file_name: str) -> str:
    """The suffix afconvert should see, taken from the recording's file name."""
    suffix = Path(file_name).suffix.lower()
    if suffix not in SOURCE_SUFFIXES:
        allowed = ", ".join(sorted(SOURCE_SUFFIXES))
        raise ValueError(f"'{file_name}': cannot decode '{suffix}' (allowed: {allowed})")
    return suffix


def afconvert(arguments: list[str]) -> None:
    """Run afconvert, or explain why it cannot run.

    Raises `RuntimeError` when macOS' own converter is missing — that is a
    broken machine, not a bad recording — and `ValueError` when it refuses the
    file, which is a reason to pick another candidate.
    """
    if shutil.which(BINARY) is None:
        raise RuntimeError(
            f"'{BINARY}' is not on the path. It ships with macOS; this tool runs nowhere else."
        )

    result = subprocess.run([BINARY, *arguments], capture_output=True, text=True, check=False)
    if result.returncode != 0:
        message = (result.stderr or result.stdout).strip().splitlines()
        raise ValueError(f"{BINARY} failed: {message[-1] if message else 'no output'}")


def to_mono(samples: array.array, channels: int) -> array.array:
    """Average the channels. A quiz sound needs no stereo image."""
    if channels <= 1:
        return samples
    return array.array(
        SAMPLE_TYPE,
        [
            sum(samples[index : index + channels]) // channels
            for index in range(0, len(samples) - channels + 1, channels)
        ],
    )


def window(samples: array.array, rate: int, start: float, duration: float) -> array.array:
    """The `duration` seconds from `start`, clamped to what the recording has.

    Raises `ValueError` when `start` lies past the end, naming the length the
    recording really has — the API's `length` field is rounded to seconds and
    a human works from it.
    """
    if start < 0 or duration <= 0:
        raise ValueError(f"--start must be at least 0 and --duration above 0, got {start}/{duration}")

    length = len(samples) / rate
    if start >= length:
        raise ValueError(f"--start {start} lies past the end of the recording ({length:.1f} s)")

    first = int(start * rate)
    return samples[first : first + int(duration * rate)]


def fade(samples: array.array, rate: int, seconds: float = FADE) -> array.array:
    """Fade the first and the last `seconds` in and out, in place.

    Without it a cut through a waveform clicks. A window shorter than two fades
    is faded over half its length each way rather than not at all.
    """
    steps = min(int(seconds * rate), len(samples) // 2)
    for index in range(steps):
        factor = index / steps
        samples[index] = int(samples[index] * factor)
        samples[-1 - index] = int(samples[-1 - index] * factor)
    return samples


def read_wave(path: Path) -> tuple[array.array, int, int]:
    """The samples, the sample rate and the channel count of a PCM WAV."""
    with wave.open(str(path), "rb") as source:
        if source.getsampwidth() != SAMPLE_WIDTH:
            raise ValueError(f"{path.name}: expected 16-bit PCM, got {source.getsampwidth() * 8}-bit")
        samples = array.array(SAMPLE_TYPE)
        samples.frombytes(source.readframes(source.getnframes()))
        return samples, source.getframerate(), source.getnchannels()


def write_wave(path: Path, samples: array.array, rate: int) -> None:
    """Write mono 16-bit PCM."""
    with wave.open(str(path), "wb") as sink:
        sink.setnchannels(1)
        sink.setsampwidth(SAMPLE_WIDTH)
        sink.setframerate(rate)
        sink.writeframes(samples.tobytes())


def trim(data: bytes, file_name: str, start: float = 0.0, duration: float = DURATION) -> bytes:
    """Decode, cut, fade and re-encode one recording. Returns the `.m4a` bytes.

    Three temporary files rather than pipes: afconvert takes paths, and both
    ends of the chain need a suffix it recognises.
    """
    suffix = source_suffix(file_name)

    with tempfile.TemporaryDirectory(prefix="zilpzalp-audio-") as directory:
        workspace = Path(directory)
        source = workspace / f"source{suffix}"
        decoded = workspace / "decoded.wav"
        cut = workspace / "cut.wav"
        encoded = workspace / f"call{EXTENSION}"

        source.write_bytes(data)
        afconvert(["-f", "WAVE", "-d", "LEI16", str(source), str(decoded)])

        samples, rate, channels = read_wave(decoded)
        write_wave(cut, fade(window(to_mono(samples, channels), rate, start, duration), rate), rate)

        afconvert(
            ["-f", FILE_FORMAT, "-d", DATA_FORMAT, "-b", BITRATE, str(cut), str(encoded)]
        )
        return encoded.read_bytes()
