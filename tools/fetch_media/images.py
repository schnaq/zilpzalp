"""Turn a downloaded photo into the square tile the app shows.

One shape for every photo: 1024×1024, sRGB, HEIC, no metadata. The tiles are
220 pt in the design and are shown at up to 3× on an iPad, so 1024 px is the
size that still looks sharp without shipping a 2048 px original per species.

HEIC rather than JPEG because it carries the same tile in roughly half the
bytes — see docs/medien-und-lizenzen.md for the measurement and for why the
recordings stay AAC. iOS decodes it through ImageIO, so `UIImage` reads it
without the app knowing which format it got.

Cropping to a square is a derivative work. That is why NoDerivatives licences
are excluded project-wide (docs/medien-und-lizenzen.md) — the crop below is
exactly the act ND would forbid.
"""

from __future__ import annotations

import io

import pillow_heif
from PIL import Image, ImageCms, ImageOps

# Teaches Pillow to read and write HEIF. Called at import so that `save` below
# and every caller that opens a tile again see the same plugin.
pillow_heif.register_heif_opener()

SIDE = 1024

# 60 on the libheif scale. At that setting a tile is indistinguishable from the
# lossless original at the size it is shown, and still measurably better than
# the JPEG quality 88 this tool wrote before — which the same photos reach at
# HEIC quality ~51. Below 55 the fine feather speckle starts to smooth over.
QUALITY = 60

# 4:2:0, the subsampling every phone camera uses for photographs. Full chroma
# would only pay off for hard colour edges, which a bird photo does not have.
CHROMA = 420

Box = tuple[int, int, int, int]


def require_square(width: int, height: int) -> None:
    """Refuse a crop that is not square — resizing it would distort the bird."""
    if width != height:
        raise ValueError(f"the crop must be square, got {width}×{height}")


def parse_crop(text: str) -> Box | None:
    """Parse `--crop`: `center` (the default) or `x,y,w,h` in source pixels.

    Returns `None` for the centre crop, which only the image itself can
    compute. Raises `ValueError`, which argparse renders as a usage error —
    before the photo is downloaded rather than after.
    """
    if text == "center":
        return None

    parts = text.split(",")
    if len(parts) != 4:
        raise ValueError(f"expected 'center' or 'x,y,w,h', got '{text}'")

    x, y, width, height = (int(part.strip()) for part in parts)
    require_square(width, height)
    return (x, y, width, height)


def centre_box(width: int, height: int) -> Box:
    """The largest centred square of an image that size."""
    side = min(width, height)
    return ((width - side) // 2, (height - side) // 2, side, side)


def encode(image: Image.Image) -> bytes:
    """Encode a tile as HEIC — the single place the format settings live.

    `exif=None` explicitly, and no `icc_profile`, so the file carries no camera
    model and no GPS position of somebody's garden into the app. Pillow's JPEG
    encoder wrote metadata only when it was handed some; the HEIF one falls
    back to whatever `Image.info` still holds, which after `exif_transpose` is
    the original block minus its orientation tag.
    """
    output = io.BytesIO()
    image.save(output, format="HEIF", quality=QUALITY, chroma=CHROMA, exif=None)
    return output.getvalue()


def square_photo(data: bytes, crop: Box | None = None) -> bytes:
    """Crop `data` to a square, resize it to 1024×1024 and encode it as HEIC.

    Raises `ValueError` when the crop lies outside the image or when the
    square would have to be upscaled — a blurry tile is a curation decision, so
    the tool refuses and the human picks another candidate.
    """
    image = Image.open(io.BytesIO(data))

    # Before anything reads coordinates: a phone photo carries its rotation in
    # the EXIF orientation tag, and iNaturalist shows it rotated. Without this
    # the crop box would address a different image than the human saw, and the
    # bird would land sideways in the pack.
    image = ImageOps.exif_transpose(image)

    # Untagged data is sRGB by convention; a tagged photo is converted, so a
    # wide-gamut original does not reach the app with washed-out colours.
    profile = image.info.get("icc_profile")
    if profile:
        try:
            image = ImageCms.profileToProfile(
                image,
                ImageCms.ImageCmsProfile(io.BytesIO(profile)),
                ImageCms.createProfile("sRGB"),
                outputMode="RGB",
            )
        # OSError as well as PyCMSError: littlecms rejects a damaged profile
        # while it is still being read, before any conversion is attempted.
        except (ImageCms.PyCMSError, OSError) as error:
            raise ValueError(
                f"the colour profile cannot be converted ({error}) — pick another candidate"
            ) from error
    image = image.convert("RGB")

    x, y, width, height = crop if crop is not None else centre_box(*image.size)
    require_square(width, height)
    if x < 0 or y < 0 or x + width > image.width or y + height > image.height:
        raise ValueError(
            f"the crop {x},{y},{width},{height} lies outside the {image.width}×{image.height} photo"
        )
    if width < SIDE:
        raise ValueError(
            f"the square is {width} px, which would have to be upscaled to {SIDE} px — "
            "pick a candidate with a larger original"
        )

    image = image.crop((x, y, x + width, y + height))
    return encode(image.resize((SIDE, SIDE), Image.LANCZOS))
