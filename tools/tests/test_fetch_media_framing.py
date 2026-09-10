"""Tests for the crop geometry that frames the bird.

Only the geometry and the parsing. Apple Vision's own output is deliberately
not asserted on: it is a model, it is macOS-only, and a generated test image is
not salient in any interesting way. What the tests do pin down is the rule the
tile depends on — the head stays inside the square.

Run from the repository root:
uv run --locked --project tools python -m unittest discover -s tools/tests -t tools
"""

from __future__ import annotations

import dataclasses
import unittest

from fetch_media import framing, images


class ParseBoxTests(unittest.TestCase):
    def test_reads_four_normalised_numbers(self) -> None:
        self.assertEqual(
            framing.parse_box("0.1, 0.2,0.5,0.75"), framing.Rect(0.1, 0.2, 0.5, 0.75)
        )

    def test_refuses_a_box_that_is_not_a_rectangle(self) -> None:
        with self.assertRaises(ValueError):
            framing.parse_box("0.5,0.2,0.5,0.75")

    def test_refuses_a_box_outside_the_photo(self) -> None:
        with self.assertRaises(ValueError):
            framing.parse_box("0.1,0.2,1.5,0.75")

    def test_refuses_the_wrong_number_of_values(self) -> None:
        with self.assertRaises(ValueError):
            framing.parse_box("0.1,0.2,0.5")


class VisionRectTests(unittest.TestCase):
    def assertRect(self, rect: framing.Rect, expected: tuple[float, float, float, float]) -> None:
        """Compare a rectangle field by field — the flip is floating point."""
        for value, want in zip(dataclasses.astuple(rect), expected, strict=True):
            self.assertAlmostEqual(value, want, places=9)

    def test_flips_the_origin_to_the_top_left(self) -> None:
        # A box in the upper half for Vision — y from 0.6 upwards — is a box in
        # the upper half for us: y0 = 1 - (0.6 + 0.3).
        self.assertRect(framing.Rect.from_vision(0.25, 0.6, 0.5, 0.3), (0.25, 0.1, 0.75, 0.4))

    def test_clamps_a_box_that_rounds_past_the_edge(self) -> None:
        self.assertRect(framing.Rect.from_vision(-1e-9, -1e-9, 1.0 + 2e-9, 1.0 + 2e-9), (0, 0, 1, 1))


class SquareCropTests(unittest.TestCase):
    def test_squares_the_padded_box_around_the_bird(self) -> None:
        # A 1200×1200 bird in the middle of a 4000×3000 photo: 18 % of 1200 is
        # 216 px of air on every side, and the square is the padded box itself.
        rect = framing.Rect(1400 / 4000, 900 / 3000, 2600 / 4000, 2100 / 3000)
        (x, y, width, height), fill = framing.square_crop(rect, 4000, 3000)

        self.assertEqual((width, height), (1632, 1632))
        self.assertEqual((x, y), (1184, 684))
        self.assertAlmostEqual(fill, 1200 / 1632, places=3)

    def test_anchors_the_top_when_the_square_cannot_hold_the_bird(self) -> None:
        # A heron standing in a portrait photo, 200 × 2500 px in a 2000 × 4000
        # one. The square is capped at the width and cannot hold the padded
        # box, so it starts at the padded box's top — y 550 — instead of
        # centring on it, which would have started at 1250 and cut the head
        # (the box begins at 1000) off. That crop is the whole point.
        rect = framing.Rect(900 / 2000, 1000 / 4000, 1100 / 2000, 3500 / 4000)
        (x, y, width, height), _ = framing.square_crop(rect, 2000, 4000)

        self.assertEqual((width, height), (2000, 2000))
        self.assertEqual((x, y), (0, 550))

    def test_grows_a_small_bird_to_the_tile_size(self) -> None:
        # A 200 px bird would give a 272 px square, which square_photo refuses
        # to upscale. The square grows to 1024 px and stays centred on the bird.
        rect = framing.Rect(0.5, 0.5, 0.55, 0.5 + 200 / 3000)
        (x, y, side, _), fill = framing.square_crop(rect, 4000, 3000)

        self.assertEqual(side, images.SIDE)
        self.assertEqual((x, y), (1588, 1088))
        self.assertAlmostEqual(fill, 200 / images.SIDE, places=3)

    def test_clamps_a_bird_in_the_corner_into_the_photo(self) -> None:
        rect = framing.Rect(0.0, 0.0, 0.1, 0.1)
        (x, y, side, _), _ = framing.square_crop(rect, 4000, 3000)

        self.assertEqual((x, y), (0, 0))
        self.assertEqual(side, images.SIDE)

    def test_caps_the_square_at_the_short_side(self) -> None:
        rect = framing.Rect(0.0, 0.0, 1.0, 1.0)
        (x, y, side, _), _ = framing.square_crop(rect, 4000, 3000)

        self.assertEqual(side, 3000)
        self.assertEqual((x, y), (500, 0))

    def test_never_leaves_the_photo(self) -> None:
        # Every corner and edge, with the margin pushing outwards: the crop
        # square_photo receives has to be inside the image in all of them.
        for x0, y0, x1, y1 in (
            (0.0, 0.0, 0.4, 0.4),
            (0.6, 0.0, 1.0, 0.4),
            (0.0, 0.6, 0.4, 1.0),
            (0.6, 0.6, 1.0, 1.0),
            (0.45, 0.0, 0.55, 0.1),
            (0.9, 0.45, 1.0, 0.55),
        ):
            with self.subTest(box=(x0, y0, x1, y1)):
                rect = framing.Rect(x0, y0, x1, y1)
                x, y, width, height = framing.square_crop(rect, 4000, 3000)[0]
                self.assertGreaterEqual(x, 0)
                self.assertGreaterEqual(y, 0)
                self.assertLessEqual(x + width, 4000)
                self.assertLessEqual(y + height, 3000)
                self.assertEqual(width, height)


if __name__ == "__main__":
    unittest.main()
