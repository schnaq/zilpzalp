"""Turn a downloaded recording — or a spoken sentence — into what the game plays.

One shape for every sound, the way `images.py` gives every photo one shape:
mono, AAC-LC in an `.m4a` container at roughly 64 kbit/s. Six seconds are
about 50 KB, small enough to bundle ten of them and to download a pack over a
phone connection, and AVAudioPlayer plays the container natively.

A call and a recorded sentence differ in one thing only — a call is a window
cut out of a two-minute recording, a sentence is the whole take — so `trim`
serves both and `duration=None` means "to the end".

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
import dataclasses
import math
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

# What xeno-canto serves and what a microphone produces, as far as afconvert
# reads it. The suffix decides the reader, so an unknown one is an error rather
# than a guess.
SOURCE_SUFFIXES = frozenset({".mp3", ".wav", ".flac", ".aiff", ".aif", ".m4a"})

# 16-bit signed PCM, the format `wave` and `array('h')` agree on.
SAMPLE_WIDTH = 2
SAMPLE_TYPE = "h"

# What a sample of 1.0 would be. 16-bit PCM runs from -32768 to 32767, so the
# negative end is the honest full scale and the positive one is clamped to it.
FULL_SCALE = 32768.0
LOUDEST = 32767

# Loudness, and why it is measured this way (#148).
#
# The ten calls of the base pack span 17 dB: a Buntspecht drumming sits at
# -35 dBFS while an Amsel sings at -17, and in a quiz one follows the other.
# A plain RMS over the whole clip is the wrong ruler for that — it averages a
# drum roll with the silence between its beats and reads far quieter than the
# child hears. The measure here is therefore the *gated* RMS EBU R128 uses for
# its integrated loudness: 400 ms blocks, an absolute gate at -70 dBFS to drop
# digital silence, then a relative gate 10 dB below the mean of what is left.
# What it does not do is K-weighting — that filter is a biquad over every
# sample, and this module deliberately has no numpy.
#
# The target is -24 dBFS with a ceiling of -1, which leaves 23 dB for a clip's
# crest factor. R128's own -23 was measured first and misses: the Buntspecht
# drumming has a crest of 24 dB, so the ceiling holds it at -25.7 whatever the
# target says, and the ten calls then span 3.0 dB — exactly the number #148
# asks them to stay under. One decibel lower costs nothing audible and brings
# the spread to 1.8 dB. A clip the ceiling holds back lands below target rather
# than clipping, and `Clip.limited` says so instead of hiding it.
BLOCK = 0.4
ABSOLUTE_GATE = -70.0
RELATIVE_GATE = -10.0
TARGET = -24.0
CEILING = -1.0

# Below this the target counts as missed — a tenth of a decibel is rounding,
# not a quiet clip.
TOLERANCE = 0.1

# Silence at the ends, and what "silence" means: 40 dB below the clip's own
# peak. Relative rather than absolute, because a field recording with wind in
# it has no absolute silence and must not be trimmed at all, while a rendered
# sentence begins and ends in digital zero.
SILENCE = -40.0
SILENCE_BLOCK = 0.01

# Kept at each end so that no attack is cut off and the fade has quiet to work
# in. A sentence that starts the instant it is played sounds clipped.
KEEP = 0.08


@dataclasses.dataclass(frozen=True)
class Clip:
    """The encoded sound, and what it measured on the way out.

    The numbers are what a human needs after a `pick` or a `render`: how long
    the clip is and how loud it came out.
    """

    data: bytes
    seconds: float
    loudness: float

    @property
    def limited(self) -> bool:
        """Whether the peak ceiling stopped it from reaching the target.

        The one case where two clips still sound unequally loud, and where the
        answer is another recording rather than another gain.
        """
        return self.loudness < TARGET - TOLERANCE


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


def window(
    samples: array.array, rate: int, start: float, duration: float | None, channels: int = 1
) -> array.array:
    """The `duration` seconds from `start`, clamped to what the recording has.

    `duration=None` keeps everything from `start` — a spoken sentence is as
    long as it is, and only a call is cut to a fixed length.

    Takes the samples still interleaved, so that it runs before `to_mono` and
    the averaging touches six seconds rather than the two minutes a raw
    xeno-canto recording can be.

    Raises `ValueError` when `start` lies past the end, naming the length the
    recording really has — the API's `length` field is rounded to seconds and
    a human works from it.
    """
    if start < 0 or (duration is not None and duration <= 0):
        raise ValueError(f"--start must be at least 0 and --duration above 0, got {start}/{duration}")

    length = len(samples) / channels / rate
    if start >= length:
        raise ValueError(f"--start {start} lies past the end of the recording ({length:.1f} s)")

    first = int(start * rate) * channels
    if duration is None:
        return samples[first:]
    return samples[first : first + int(duration * rate) * channels]


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


def decibels(ratio: float) -> float:
    """A linear amplitude as dBFS. Silence is minus infinity, not an error."""
    return -math.inf if ratio <= 0 else 20 * math.log10(ratio)


def peak(samples: array.array) -> float:
    """The loudest sample as a fraction of full scale."""
    return max((abs(sample) for sample in samples), default=0) / FULL_SCALE


def loudness(samples: array.array, rate: int) -> float:
    """The gated RMS of a mono clip in dBFS — see the constants above.

    Blocks quieter than the absolute gate are dropped, then blocks more than
    `RELATIVE_GATE` below the mean of the rest. What survives is what a
    listener hears as the clip's level: the drum beats, not the pauses.
    """
    if not samples:
        return -math.inf

    # A clip shorter than one block is measured whole rather than dropped for
    # having no complete block in it.
    size = min(max(1, int(BLOCK * rate)), len(samples))
    powers = [
        sum(sample * sample for sample in samples[first : first + size])
        / size
        / (FULL_SCALE * FULL_SCALE)
        for first in range(0, len(samples) - size + 1, size)
    ]

    def mean(kept: list[float]) -> float:
        return decibels(math.sqrt(sum(kept) / len(kept)))

    above_floor = [power for power in powers if decibels(math.sqrt(power)) > ABSOLUTE_GATE]
    if not above_floor:
        return -math.inf

    threshold = mean(above_floor) + RELATIVE_GATE
    loud = [power for power in above_floor if decibels(math.sqrt(power)) > threshold]
    return mean(loud or above_floor)


def amplify(samples: array.array, factor: float) -> array.array:
    """Scale every sample in place, clamped to what 16 bits hold."""
    for index, sample in enumerate(samples):
        samples[index] = max(-LOUDEST - 1, min(LOUDEST, int(sample * factor)))
    return samples


def normalise(
    samples: array.array, rate: int, target: float = TARGET, ceiling: float = CEILING
) -> float:
    """Bring a mono clip to `target`, never letting its peak pass `ceiling`.

    Returns the loudness actually reached. It is below the target exactly when
    the ceiling got in the way — a clip whose crest factor exceeds
    `ceiling - target` — and the caller reports that rather than swallowing it:
    it is the one case where #148's spread survives the normalisation.

    One gain for the whole clip. Nothing here compresses or limits: a quiz
    sound that has been squashed flat is a different recording, and the
    decision to use another one belongs to the human who listens.
    """
    level = loudness(samples, rate)
    if level == -math.inf:
        return level

    headroom = ceiling - decibels(peak(samples))
    gain = min(target - level, headroom)
    amplify(samples, 10 ** (gain / 20))
    return level + gain


def strip_silence(samples: array.array, rate: int, keep: float = KEEP) -> array.array:
    """Drop the silence before the first sound and after the last one.

    Ends only: the pause between two drum rolls is part of the call, and a
    pause inside a sentence is part of the sentence. A clip that is silent
    throughout is handed back whole — there is nothing to find, and returning
    nothing would encode an empty file.
    """
    loudest = max((abs(sample) for sample in samples), default=0)
    threshold = loudest * 10 ** (SILENCE / 20)
    size = max(1, int(SILENCE_BLOCK * rate))
    active = [
        first
        for first in range(0, len(samples), size)
        if max((abs(sample) for sample in samples[first : first + size]), default=0) >= threshold
    ]
    if not active:
        return samples

    padding = int(keep * rate)
    return samples[max(0, active[0] - padding) : min(len(samples), active[-1] + size + padding)]


def read_wave(path: Path) -> tuple[array.array, int, int]:
    """The samples, the sample rate and the channel count of a PCM WAV.

    `wave.Error` inherits from `Exception` and nothing else, so it would walk
    past `cli.main`'s except clause and print a traceback where the tool
    promises one `::error::` line. A WAV afconvert wrote and `wave` cannot read
    is a broken recording, so `ValueError` is what it is.
    """
    try:
        with wave.open(str(path), "rb") as source:
            if source.getsampwidth() != SAMPLE_WIDTH:
                raise ValueError(
                    f"{path.name}: expected 16-bit PCM, got {source.getsampwidth() * 8}-bit"
                )
            samples = array.array(SAMPLE_TYPE)
            samples.frombytes(source.readframes(source.getnframes()))
            return samples, source.getframerate(), source.getnchannels()
    except (wave.Error, EOFError) as error:
        raise ValueError(f"{path.name}: is not a readable WAV ({error})") from error


def write_wave(path: Path, samples: array.array, rate: int) -> None:
    """Write mono 16-bit PCM."""
    with wave.open(str(path), "wb") as sink:
        sink.setnchannels(1)
        sink.setsampwidth(SAMPLE_WIDTH)
        sink.setframerate(rate)
        sink.writeframes(samples.tobytes())


def trim(
    data: bytes, file_name: str, start: float = 0.0, duration: float | None = DURATION
) -> Clip:
    """Decode, cut, normalise, fade and re-encode one recording.

    The order matters. The window comes first so that everything after it works
    on seconds rather than minutes; the silence at the ends goes before the
    measurement, or a clip that begins with two quiet seconds would be measured
    against them; the fade comes last, because it is the only step allowed to
    touch the very first and last sample.

    `duration=None` keeps the recording whole, which is what a spoken sentence
    needs. Note for `calls pick`: the clip is now *up to* `duration` seconds —
    silence at either end is dropped, so the `--start` values documented in
    #147 still name the same moment but no longer promise six full seconds.

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
        kept = strip_silence(to_mono(window(samples, rate, start, duration, channels), channels), rate)
        level = normalise(kept, rate)
        write_wave(cut, fade(kept, rate), rate)

        afconvert(
            ["-f", FILE_FORMAT, "-d", DATA_FORMAT, "-b", BITRATE, str(cut), str(encoded)]
        )
        return Clip(data=encoded.read_bytes(), seconds=len(kept) / rate, loudness=level)
