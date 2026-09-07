"""Tests for the trimming of a recording.

Nothing here reaches the network. The one test that really runs `afconvert`
does so on half a second of a generated tone, which takes milliseconds — the
converter is macOS' own and is not worth mocking away entirely, because the
container it produces is exactly what the app has to play.

Run from the repository root:
uv run --locked --project tools python -m unittest discover -s tools/tests -t tools
"""

from __future__ import annotations

import array
import math
import unittest
import wave
from io import BytesIO
from unittest import mock

from fetch_media import audio, s3

RATE = 22050


def samples(count: int, value: int = 10000) -> array.array:
    return array.array(audio.SAMPLE_TYPE, [value] * count)


def tone(seconds: float = 0.5, rate: int = RATE, channels: int = 1) -> bytes:
    """A WAV of a 1 kHz tone — the smallest thing afconvert takes seriously."""
    frames = array.array(
        audio.SAMPLE_TYPE,
        [
            int(12000 * math.sin(2 * math.pi * 1000 * index / rate))
            for index in range(int(rate * seconds))
            for _ in range(channels)
        ],
    )
    buffer = BytesIO()
    with wave.open(buffer, "wb") as sink:
        sink.setnchannels(channels)
        sink.setsampwidth(audio.SAMPLE_WIDTH)
        sink.setframerate(rate)
        sink.writeframes(frames.tobytes())
    return buffer.getvalue()


class SourceSuffixTests(unittest.TestCase):
    def test_takes_the_suffix_from_the_recordings_file_name(self) -> None:
        """afconvert picks its reader by extension: a WAV named .mp3 fails."""
        self.assertEqual(audio.source_suffix("XC965144-Amsel.MP3"), ".mp3")
        self.assertEqual(audio.source_suffix("XC1166016-strakapoud.wav"), ".wav")
        self.assertEqual(audio.source_suffix("XC1-a.flac"), ".flac")

    def test_refuses_what_it_cannot_decode(self) -> None:
        for name in ("recording.aiff", "recording", ""):
            with self.subTest(name=name), self.assertRaises(ValueError) as error:
                audio.source_suffix(name)
            self.assertIn("cannot decode", str(error.exception))


class MonoTests(unittest.TestCase):
    def test_averages_the_channels(self) -> None:
        stereo = array.array(audio.SAMPLE_TYPE, [100, 200, -100, -200])

        self.assertEqual(list(audio.to_mono(stereo, 2)), [150, -150])

    def test_leaves_a_mono_recording_alone(self) -> None:
        mono = samples(4)

        self.assertIs(audio.to_mono(mono, 1), mono)


class WindowTests(unittest.TestCase):
    def test_cuts_the_requested_seconds(self) -> None:
        self.assertEqual(len(audio.window(samples(RATE * 10), RATE, 2.0, 6.0)), RATE * 6)

    def test_counts_seconds_in_frames_when_the_source_is_stereo(self) -> None:
        """It runs before the downmix, so six seconds must not become three."""
        stereo = samples(RATE * 10 * 2)

        self.assertEqual(len(audio.window(stereo, RATE, 2.0, 6.0, channels=2)), RATE * 6 * 2)

    def test_clamps_a_window_that_reaches_past_the_end(self) -> None:
        """A one-second drumming roll with the six-second default is normal."""
        self.assertEqual(len(audio.window(samples(RATE), RATE, 0.0, 6.0)), RATE)

    def test_refuses_a_start_past_the_end_and_names_the_length(self) -> None:
        with self.assertRaises(ValueError) as error:
            audio.window(samples(RATE * 3), RATE, 5.0, 6.0)

        self.assertIn("3.0 s", str(error.exception))

    def test_refuses_a_negative_start_or_an_empty_duration(self) -> None:
        for start, duration in ((-1.0, 6.0), (0.0, 0.0)):
            with self.subTest(start=start), self.assertRaises(ValueError):
                audio.window(samples(RATE * 3), RATE, start, duration)


class FadeTests(unittest.TestCase):
    def test_silences_both_ends_and_leaves_the_middle(self) -> None:
        faded = audio.fade(samples(RATE), RATE, seconds=0.04)

        self.assertEqual(faded[0], 0)
        self.assertEqual(faded[-1], 0)
        self.assertEqual(faded[RATE // 2], 10000)

    def test_rises_monotonically(self) -> None:
        faded = audio.fade(samples(RATE), RATE, seconds=0.04)
        ramp = faded[: int(0.04 * RATE)]

        self.assertEqual(list(ramp), sorted(ramp))

    def test_halves_the_fade_when_the_window_is_shorter_than_two(self) -> None:
        """A one-second clip must still not click, and must not fade to nothing."""
        faded = audio.fade(samples(10), RATE, seconds=0.04)

        self.assertEqual(faded[0], 0)
        self.assertEqual(faded[-1], 0)
        self.assertGreater(faded[5], 0)


class TrimTests(unittest.TestCase):
    def test_produces_an_m4a_smaller_than_the_source(self) -> None:
        source = tone(seconds=0.5)

        encoded = audio.trim(source, "XC1-tone.wav", start=0.0, duration=0.3)

        self.assertIn(b"ftyp", encoded[:12])
        self.assertLess(len(encoded), len(source))

    def test_accepts_a_stereo_source(self) -> None:
        encoded = audio.trim(tone(seconds=0.5, channels=2), "XC1-tone.wav", duration=0.3)

        self.assertIn(b"ftyp", encoded[:12])

    def test_reports_a_file_afconvert_cannot_read(self) -> None:
        """A WAV named .mp3 is the case that actually happens at xeno-canto."""
        with self.assertRaises(ValueError) as error:
            audio.trim(tone(seconds=0.2), "XC1-mislabelled.mp3")

        self.assertIn("afconvert failed", str(error.exception))

    def test_says_so_when_afconvert_is_missing(self) -> None:
        with mock.patch.object(audio.shutil, "which", return_value=None):
            with self.assertRaises(RuntimeError) as error:
                audio.trim(tone(seconds=0.2), "XC1-tone.wav")

        self.assertIn("afconvert", str(error.exception))


class BucketTests(unittest.TestCase):
    def test_the_upload_knows_the_content_type_of_a_call(self) -> None:
        """Without this the upload would raise on the first recording."""
        self.assertEqual(s3.CONTENT_TYPES[audio.EXTENSION], "audio/mp4")


if __name__ == "__main__":
    unittest.main()
