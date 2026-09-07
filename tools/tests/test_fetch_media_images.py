"""Tests for the crop and resize step.

Every image here is generated, so the geometry can be asserted by reading a
pixel back out of the result.

Run from the repository root:
uv run --locked --project tools python -m unittest discover -s tools/tests -t tools
"""

from __future__ import annotations

import io
import unittest

from PIL import Image

from fetch_media import images

RED = (220, 40, 40)
BLUE = (40, 60, 220)


def photo(width: int, height: int, orientation: int | None = None, split: str = "vertical") -> bytes:
    """A JPEG of that size, one half red and one half blue.

    `split="vertical"` puts red on the left, `"horizontal"` puts it on top —
    which half comes back tells the tests what the crop and the EXIF
    orientation did.
    """
    image = Image.new("RGB", (width, height), BLUE)
    box = (0, 0, width // 2, height) if split == "vertical" else (0, 0, width, height // 2)
    image.paste(Image.new("RGB", (box[2] - box[0], box[3] - box[1]), RED), box)

    buffer = io.BytesIO()
    if orientation is None:
        image.save(buffer, format="JPEG", quality=95)
    else:
        exif = Image.Exif()
        exif[0x0112] = orientation
        image.save(buffer, format="JPEG", quality=95, exif=exif)
    return buffer.getvalue()


def opened(data: bytes) -> Image.Image:
    return Image.open(io.BytesIO(data))


def near(pixel: tuple[int, ...], expected: tuple[int, int, int]) -> bool:
    """Whether a colour survived a JPEG round trip close enough to be that one."""
    return all(abs(actual - wanted) < 40 for actual, wanted in zip(pixel[:3], expected, strict=True))


class CropParsingTests(unittest.TestCase):
    def test_center_is_the_default_and_parses_to_none(self) -> None:
        self.assertIsNone(images.parse_crop("center"))

    def test_parses_a_box(self) -> None:
        self.assertEqual(images.parse_crop("10,20,1500,1500"), (10, 20, 1500, 1500))

    def test_rejects_a_box_that_is_not_square(self) -> None:
        with self.assertRaises(ValueError):
            images.parse_crop("0,0,1500,1200")

    def test_rejects_nonsense(self) -> None:
        for text in ("", "1,2,3", "left", "a,b,c,d"):
            with self.subTest(text=text), self.assertRaises(ValueError):
                images.parse_crop(text)

    def test_centres_the_largest_square(self) -> None:
        self.assertEqual(images.centre_box(2000, 1500), (250, 0, 1500, 1500))
        self.assertEqual(images.centre_box(1500, 2000), (0, 250, 1500, 1500))
        self.assertEqual(images.centre_box(1200, 1200), (0, 0, 1200, 1200))


class SquarePhotoTests(unittest.TestCase):
    def test_produces_a_1024_pixel_srgb_jpeg(self) -> None:
        result = opened(images.square_photo(photo(2048, 1538)))

        self.assertEqual(result.size, (images.SIDE, images.SIDE))
        self.assertEqual(result.format, "JPEG")
        self.assertEqual(result.mode, "RGB")

    def test_drops_the_metadata(self) -> None:
        """No camera model, and above all no GPS position of somebody's garden."""
        result = opened(images.square_photo(photo(2048, 1538, orientation=1)))

        self.assertEqual(len(result.getexif()), 0)
        self.assertIsNone(result.info.get("icc_profile"))

    def test_takes_the_centre_by_default(self) -> None:
        """A 2048×1200 photo, red on the left: the centre keeps both halves."""
        result = opened(images.square_photo(photo(2048, 1200)))

        self.assertTrue(near(result.getpixel((100, 512)), RED))
        self.assertTrue(near(result.getpixel((images.SIDE - 100, 512)), BLUE))

    def test_takes_the_given_box(self) -> None:
        """The right half of the same photo is blue all through."""
        result = opened(images.square_photo(photo(2400, 1200), crop=(1200, 0, 1200, 1200)))

        self.assertTrue(near(result.getpixel((100, 512)), BLUE))
        self.assertTrue(near(result.getpixel((images.SIDE - 100, 512)), BLUE))

    def test_applies_the_exif_orientation_before_cropping(self) -> None:
        """Orientation 6 means "rotate 90° clockwise": the left half moves up.

        Without this the crop box would address a different image than the one
        iNaturalist showed the human, and a phone photo would land sideways.
        """
        result = opened(images.square_photo(photo(1200, 1200, orientation=6)))

        self.assertTrue(near(result.getpixel((512, 100)), RED))
        self.assertTrue(near(result.getpixel((512, images.SIDE - 100)), BLUE))

    def test_refuses_to_upscale(self) -> None:
        with self.assertRaises(ValueError) as error:
            images.square_photo(photo(1000, 800))

        self.assertIn("upscaled", str(error.exception))

    def test_refuses_a_box_outside_the_photo(self) -> None:
        for box in ((-1, 0, 1200, 1200), (0, 0, 2000, 2000), (1000, 0, 1200, 1200)):
            with self.subTest(box=box), self.assertRaises(ValueError):
                images.square_photo(photo(2048, 1538), crop=box)

    def test_refuses_a_box_that_is_not_square(self) -> None:
        with self.assertRaises(ValueError):
            images.square_photo(photo(2048, 1538), crop=(0, 0, 1500, 1400))


if __name__ == "__main__":
    unittest.main()
