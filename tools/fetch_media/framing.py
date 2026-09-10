"""Find the bird in a photo and turn its box into the square tile crop.

A centred square is the wrong crop for a bird photo. Photographers frame for
the picture, not for a 220 pt tile: the bird sits off centre, sometimes at the
top edge, and the centre of the frame is a branch. Three of the tiles the first
playtest complained about (issue #195) are exactly that — a cut-off head, a
road, a monument at night.

So the crop is derived from where the bird is. Two sources produce the box, and
both hand over the same thing: a `Rect` in normalised 0–1 coordinates with the
origin at the top left.

* `saliency_rect` asks Apple Vision for the salient objects of the photo and
  takes the largest. Deterministic, offline, no credential, macOS only — which
  is acceptable because curation runs on a Mac.
* `parse_box` takes the same rectangle from a human or from a vision model that
  looked at the downscaled preview `photos frame` writes. That is the fallback
  for the photos where saliency locks onto the wrong thing.

`square_crop` then does the geometry, and it is the part that has to be right:
the bird plus a margin, squared, inside the photo, and — when the square cannot
hold the padded box — anchored to its top, because that is where the head is.
"""

from __future__ import annotations

import io
from dataclasses import dataclass

from PIL import Image

from fetch_media import images

# Fraction of the box's longer side added on every side before squaring. Enough
# air that the bird does not touch the tile's edge, little enough that it still
# fills the tile. Below roughly 0.1 the crop looks like a mistake; above 0.25
# the bird is small again, which is the very complaint this module answers.
MARGIN = 0.18

# A photo is downscaled to this before Vision looks at it. Saliency is computed
# on a coarse grid anyway and returns normalised coordinates, so the box is the
# same as on the original while the request costs a fraction of the time.
SALIENCY_SIDE = 1024


class FramingError(RuntimeError):
    """The box could not be found — say what the human should do instead."""


@dataclass(frozen=True)
class Rect:
    """A box in normalised 0–1 coordinates, origin top left.

    One convention for every source and every reader: `--box`, the prompt a
    vision model answers, and Vision's own output converted into it. Vision
    measures from the bottom left, which is the one place the flip happens
    (`from_vision`).
    """

    x0: float
    y0: float
    x1: float
    y1: float

    def __post_init__(self) -> None:
        if not 0.0 <= self.x0 < self.x1 <= 1.0 or not 0.0 <= self.y0 < self.y1 <= 1.0:
            raise ValueError(
                f"the box {self.x0},{self.y0},{self.x1},{self.y1} is not a rectangle "
                "inside 0–1 (expected x0 < x1 and y0 < y1)"
            )

    @classmethod
    def from_vision(cls, x: float, y: float, width: float, height: float) -> Rect:
        """A `CGRect` from Vision, whose origin is the bottom left, flipped.

        Clamped on the way in: Vision returns floating point and a box that
        touches an edge comes back a hair outside 0–1, which `__post_init__`
        would reject over a rounding error.
        """

        def clamp(value: float) -> float:
            return min(max(value, 0.0), 1.0)

        return cls(clamp(x), clamp(1.0 - (y + height)), clamp(x + width), clamp(1.0 - y))

    @property
    def area(self) -> float:
        return (self.x1 - self.x0) * (self.y1 - self.y0)


def parse_box(text: str) -> Rect:
    """Parse `--box`: `x0,y0,x1,y1`, normalised, origin top left.

    Raises `ValueError`, which argparse renders as a usage error — before the
    photo is downloaded rather than after.
    """
    parts = text.split(",")
    if len(parts) != 4:
        raise ValueError(f"expected 'x0,y0,x1,y1' in 0–1, got '{text}'")
    return Rect(*(float(part.strip()) for part in parts))


def saliency_rect(image: Image.Image) -> Rect | None:
    """The largest object Apple Vision finds salient, or `None` if it finds none.

    The import is deliberately here and not at module scope: `pyobjc-framework-
    Vision` is a macOS-only dependency (tools/pyproject.toml), and every other
    subcommand has to keep working on a machine without it.
    """
    try:
        import Vision
        from Foundation import NSData
    except ImportError as error:  # pragma: no cover - macOS-only dependency
        raise FramingError(
            f"Apple Vision is not available ({error}), so this machine cannot find the "
            "box — it has to be passed in instead"
        ) from error

    # A PNG of the already-oriented image, never the original bytes: Vision
    # would apply the EXIF orientation a second time and the box would then
    # address a different image than `images.square_photo` crops.
    # RGB before PNG: a few iNaturalist originals are CMYK JPEGs, and Pillow's
    # PNG encoder refuses that mode outright — the same conversion every other
    # reader of a photo in this project does.
    small = image.convert("RGB")
    small.thumbnail((SALIENCY_SIDE, SALIENCY_SIDE), Image.LANCZOS)
    buffer = io.BytesIO()
    small.save(buffer, format="PNG")

    data = NSData.dataWithBytes_length_(buffer.getvalue(), buffer.tell())
    handler = Vision.VNImageRequestHandler.alloc().initWithData_options_(data, {})
    request = Vision.VNGenerateObjectnessBasedSaliencyImageRequest.alloc().init()

    performed, error = handler.performRequests_error_([request], None)
    if not performed:
        raise FramingError(f"Vision could not read the photo ({error})")

    results = request.results() or []
    objects = [box for result in results for box in (result.salientObjects() or [])]
    if not objects:
        return None

    rects = []
    for observation in objects:
        (x, y), (box_width, box_height) = observation.boundingBox()
        rects.append(Rect.from_vision(x, y, box_width, box_height))

    # The largest by normalised area. Every box is measured in the same image,
    # so that is the largest in pixels as well — and a bird photographed on
    # purpose is the biggest thing in the frame far more often than not.
    return max(rects, key=lambda rect: rect.area)


def square_crop(
    rect: Rect, width: int, height: int, margin: float = MARGIN
) -> tuple[images.Box, float]:
    """The square `--crop x,y,w,h` for that box, and how much of it the bird fills.

    Four rules, in this order:

    1. The bird gets `margin` of its longer side as air on every side.
    2. The square holds that padded box, and it is at least `images.SIDE` —
       a smaller square would have to be upscaled and `square_photo` refuses.
    3. It stays inside the photo, which is what caps it at the short side.
    4. It is centred on the padded box horizontally. Vertically too, unless the
       square is too small to hold the padded box — then it is anchored to the
       padded box's top, because a bird's head is at the top and a cut-off head
       is the one mistake this whole path exists to prevent.

    The second return value is the bird's longer side as a fraction of the
    square's. It says nothing about the crop's correctness and everything about
    whether the photo is worth keeping: below roughly a third the bird is a
    speck, and the answer is another photo (issue #194), not another crop.
    """
    box_x0, box_y0 = rect.x0 * width, rect.y0 * height
    box_x1, box_y1 = rect.x1 * width, rect.y1 * height
    longer = max(box_x1 - box_x0, box_y1 - box_y0)

    pad = margin * longer
    padded_x0, padded_y0 = box_x0 - pad, box_y0 - pad
    padded_x1, padded_y1 = box_x1 + pad, box_y1 + pad

    side = max(padded_x1 - padded_x0, padded_y1 - padded_y0, min(images.SIDE, width, height))
    side = int(min(side, width, height))

    x = round((padded_x0 + padded_x1) / 2 - side / 2)
    if side >= padded_y1 - padded_y0:
        y = round((padded_y0 + padded_y1) / 2 - side / 2)
    else:
        y = round(padded_y0)

    x = min(max(x, 0), width - side)
    y = min(max(y, 0), height - side)
    return (x, y, side, side), longer / side
