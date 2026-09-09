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
from pathlib import Path
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

    def test_takes_what_a_microphone_produces_too(self) -> None:
        """`speech import` hands it a take, and a take is rarely an MP3."""
        self.assertEqual(audio.source_suffix("take3.aiff"), ".aiff")
        self.assertEqual(audio.source_suffix("Sprachmemo.m4a"), ".m4a")

    def test_refuses_what_it_cannot_decode(self) -> None:
        for name in ("recording.ogg", "recording", ""):
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
        rate = 100
        stereo = array.array(audio.SAMPLE_TYPE, range(rate * 10 * 2))

        cut = audio.window(stereo, rate, 2.0, 6.0, channels=2)

        self.assertEqual(len(cut), rate * 6 * 2)
        # The start, not only the length: an offset that forgot the channels
        # would still hand back a slice of the right size.
        self.assertEqual(cut[0], stereo[rate * 2 * 2])

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


def level(value: int) -> float:
    """The dBFS a constant amplitude sits at."""
    return audio.decibels(value / audio.FULL_SCALE)


def burst(sound: float, silence: float, value: int = 10000, rate: int = RATE) -> array.array:
    """`sound` seconds at `value`, then `silence` seconds of nothing.

    A drum roll in miniature: what a plain RMS reads far too quietly and the
    gated measure reads as what a listener hears.
    """
    return array.array(
        audio.SAMPLE_TYPE, [value] * int(sound * rate) + [0] * int(silence * rate)
    )


class LoudnessTests(unittest.TestCase):
    def test_measures_a_steady_sound_at_its_own_level(self) -> None:
        self.assertAlmostEqual(audio.loudness(samples(RATE), RATE), level(10000), delta=0.2)

    def test_ignores_the_silence_between_the_beats(self) -> None:
        """#148: the Buntspecht drumming is quiet on average and loud to a child."""
        drumming = burst(sound=0.5, silence=2.0)

        measured = audio.loudness(drumming, RATE)
        averaged = audio.decibels(
            math.sqrt(sum(value * value for value in drumming) / len(drumming))
            / audio.FULL_SCALE
        )

        self.assertGreater(measured, averaged + 4)
        self.assertLess(measured, level(10000))

    def test_measures_a_clip_shorter_than_one_block(self) -> None:
        """„Amsel" is a third of a second, and it still has a loudness."""
        self.assertAlmostEqual(audio.loudness(samples(RATE // 5), RATE), level(10000), delta=0.2)

    def test_calls_silence_silence_rather_than_raising(self) -> None:
        self.assertEqual(audio.loudness(samples(RATE, value=0), RATE), -math.inf)
        self.assertEqual(audio.loudness(array.array(audio.SAMPLE_TYPE), RATE), -math.inf)


class NormaliseTests(unittest.TestCase):
    def test_brings_two_clips_of_different_level_together(self) -> None:
        """The whole of #148 in one assertion."""
        quiet = samples(RATE, value=400)
        loud = samples(RATE, value=20000)

        reached = [audio.normalise(clip, RATE) for clip in (quiet, loud)]

        self.assertAlmostEqual(reached[0], audio.TARGET, delta=0.2)
        self.assertAlmostEqual(reached[1], audio.TARGET, delta=0.2)
        self.assertLess(abs(reached[0] - reached[1]), 1.0)
        self.assertAlmostEqual(audio.loudness(quiet, RATE), audio.loudness(loud, RATE), delta=1.0)

    def test_never_lets_the_peak_pass_the_ceiling(self) -> None:
        """A clip with more crest than the ceiling allows lands below target.

        Quiet throughout with one short crack in it — the shape the Buntspecht
        drumming has, and the one case #148's spread survives.
        """
        spiky = samples(RATE * 2, value=200)
        for index in range(RATE, RATE + 10):
            spiky[index] = 30000

        reached = audio.normalise(spiky, RATE)

        self.assertLessEqual(audio.decibels(audio.peak(spiky)), audio.CEILING + 0.1)
        self.assertLess(reached, audio.TARGET)

    def test_leaves_silence_alone(self) -> None:
        silent = samples(RATE, value=0)

        self.assertEqual(audio.normalise(silent, RATE), -math.inf)
        self.assertEqual(max(silent), 0)


class SilenceTests(unittest.TestCase):
    def sound_at(self, first: float, last: float, length: float = 2.0) -> array.array:
        """Silence, then sound from `first` to `last` seconds, then silence."""
        clip = array.array(audio.SAMPLE_TYPE, [0] * int(length * RATE))
        for index in range(int(first * RATE), int(last * RATE)):
            clip[index] = 10000
        return clip

    def test_drops_the_silence_at_both_ends(self) -> None:
        stripped = audio.strip_silence(self.sound_at(0.5, 1.5), RATE)

        self.assertAlmostEqual(len(stripped) / RATE, 1.0 + 2 * audio.KEEP, delta=0.05)

    def test_keeps_a_little_of_it_so_that_nothing_is_clipped(self) -> None:
        stripped = audio.strip_silence(self.sound_at(0.5, 1.5), RATE)

        self.assertEqual(stripped[0], 0)
        self.assertEqual(stripped[-1], 0)

    def test_keeps_the_pause_inside_a_clip(self) -> None:
        """The gap between two drum rolls is the call, not silence around it."""
        clip = self.sound_at(0.1, 0.3)
        for index in range(int(1.5 * RATE), int(1.7 * RATE)):
            clip[index] = 10000

        stripped = audio.strip_silence(clip, RATE)

        self.assertAlmostEqual(len(stripped) / RATE, 1.6 + 2 * audio.KEEP, delta=0.05)

    def test_hands_back_a_clip_that_is_silent_throughout(self) -> None:
        """Returning nothing would encode an empty file."""
        silent = samples(RATE, value=0)

        self.assertEqual(len(audio.strip_silence(silent, RATE)), RATE)


class TrimTests(unittest.TestCase):
    def test_produces_an_m4a_smaller_than_the_source(self) -> None:
        source = tone(seconds=0.5)

        clip = audio.trim(source, "XC1-tone.wav", start=0.0, duration=0.3)

        self.assertIn(b"ftyp", clip.data[:12])
        self.assertLess(len(clip.data), len(source))

    def test_accepts_a_stereo_source(self) -> None:
        clip = audio.trim(tone(seconds=0.5, channels=2), "XC1-tone.wav", duration=0.3)

        self.assertIn(b"ftyp", clip.data[:12])

    def test_keeps_the_whole_recording_without_a_duration(self) -> None:
        """What a spoken sentence needs: it is as long as it is."""
        clip = audio.trim(tone(seconds=0.5), "sentence.wav", duration=None)

        self.assertAlmostEqual(clip.seconds, 0.5, places=1)

    def test_reports_the_loudness_it_reached(self) -> None:
        clip = audio.trim(tone(seconds=0.5), "XC1-tone.wav", duration=0.3)

        self.assertAlmostEqual(clip.loudness, audio.TARGET, delta=0.5)
        self.assertFalse(clip.limited)

    def test_reports_a_file_afconvert_cannot_read(self) -> None:
        """A WAV named .mp3 is the case that actually happens at xeno-canto."""
        with self.assertRaises(ValueError) as error:
            audio.trim(tone(seconds=0.2), "XC1-mislabelled.mp3")

        self.assertIn("afconvert failed", str(error.exception))

    def test_reports_a_wav_the_standard_library_cannot_read(self) -> None:
        """`wave.Error` would otherwise walk past cli.main and print a stack."""

        def decodes_to_rubbish(arguments: list[str]) -> None:
            Path(arguments[-1]).write_bytes(b"not a wav at all")

        with mock.patch.object(audio, "afconvert", decodes_to_rubbish):
            with self.assertRaises(ValueError) as error:
                audio.trim(tone(seconds=0.2), "XC1-tone.wav")

        self.assertIn("not a readable WAV", str(error.exception))

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
