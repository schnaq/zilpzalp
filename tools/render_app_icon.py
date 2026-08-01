#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.11"
# dependencies = [
#   "resvg-py==0.3.3",
#   "pillow==12.3.0",
# ]
# ///
"""Render the ZilpZalp App Icon from assets/logo.svg.

`assets/logo.svg` is the brand mark: a hoopoe in front of an open olive ring,
on a *transparent* background. App icons must not carry any transparency —
that is an App Store Connect rejection, not a stylistic nicety — so this
script composites the vector art onto an opaque background at build time
instead of baking a colour into the source SVG.

Produces the "single size" App Icon asset (Xcode 16+ / iOS 18+): one
1024x1024 PNG per appearance (Any/Light, Dark, Tinted), written straight into
the app target's asset catalog. iOS derives every smaller icon size from this
one master at install time; we do not hand-author per-size PNGs.

Rendering uses resvg (via the resvg-py bindings) rather than a
globally-installed rsvg-convert/ImageMagick, so the pipeline stays
reproducible on any machine and on CI: `uv run tools/render_app_icon.py`
resolves and caches the exact pinned dependencies above, no Homebrew, no
system libraries.

Colour choice (see assets/README.md and docs/superpowers/plans/
2026-08-02-m1-design-system.md, Task 8):

- Any/Light: cream-50 (#FFFCF3). ink-900, the near-black used for the tail
  stripes, the beak outline and the eye, contrasts 15.3:1 against cream-50 —
  the fine plumage linework stays crisp even once iOS downsamples this
  master to the smallest home-screen size.
- Dark: olive-500 (#6E7A21), the app's primary brand colour and — not
  coincidentally — the exact fill already used by the "Hintergrund" ring
  layer inside the SVG, so the ring disappears seamlessly into the
  background instead of leaving a visible seam. ink-900 only contrasts
  3.3:1 against olive-500 (checked: still legible in the render), and drops
  to ~1.5:1 or below against any darker olive shade or near-black — so this
  is the darkest background that keeps the ink-900 parts of the bird
  legible, not an arbitrary pick.
- Tinted: iOS applies the user's chosen tint colour itself, so this
  appearance ships as a plain grayscale desaturation of the Any/Light
  render (opaque, no colour information for the system to fight with).

Beak/crop check: the beak tip and the crest tips are the parts of the
artwork that reach closest to the edges of the square. Both sit within a
percent or two of the square's horizontal/vertical *centre* line — exactly
where a rounded-corner/superellipse icon mask keeps its full width/height —
so neither is clipped by the mask and no recentring/rescaling was needed.
See task-8-report.md for the numeric check.
"""

from __future__ import annotations

import io
import sys
from pathlib import Path

import resvg_py
from PIL import Image

REPO_ROOT = Path(__file__).resolve().parent.parent
SOURCE_SVG = REPO_ROOT / "assets" / "logo.svg"
OUTPUT_DIR = (
    REPO_ROOT
    / "apps"
    / "ZilpZalp"
    / "Resources"
    / "Assets.xcassets"
    / "AppIcon.appiconset"
)

ICON_SIZE = 1024

# design/tokens/colors.css
CREAM_50 = "#FFFCF3"
OLIVE_500 = "#6E7A21"


def render_opaque(svg_path: Path, background: str, size: int) -> Image.Image:
    """Rasterise `svg_path` onto an opaque `background`, dropping any alpha."""
    png_bytes = resvg_py.svg_to_bytes(
        svg_path=str(svg_path),
        width=size,
        height=size,
        background=background,
    )
    image = Image.open(io.BytesIO(bytes(png_bytes)))
    # resvg always returns RGBA; the background param makes every pixel
    # opaque (alpha=255) but the alpha channel itself is still present. App
    # Store Connect rejects icons that carry an alpha channel at all, even a
    # fully opaque one, so it must be dropped, not just filled in.
    return image.convert("RGB")


def to_tinted(light: Image.Image) -> Image.Image:
    """Desaturate the light render for the Tinted appearance.

    iOS re-tints this image with the colour the person picked for their
    home screen; shipping it in colour would fight that, so this is a
    mechanical grayscale conversion, not a hand-redrawn variant.
    """
    return light.convert("L").convert("RGB")


def assert_opaque(image: Image.Image, label: str) -> None:
    if image.mode != "RGB":
        raise SystemExit(f"{label}: expected RGB (no alpha channel), got {image.mode}")


def main() -> None:
    if not SOURCE_SVG.exists():
        raise SystemExit(f"Source SVG not found: {SOURCE_SVG}")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    light = render_opaque(SOURCE_SVG, CREAM_50, ICON_SIZE)
    dark = render_opaque(SOURCE_SVG, OLIVE_500, ICON_SIZE)
    tinted = to_tinted(light)

    renders = (
        (light, "AppIcon-1024.png", "Any/Light"),
        (dark, "AppIcon-1024-dark.png", "Dark"),
        (tinted, "AppIcon-1024-tinted.png", "Tinted"),
    )

    for image, filename, label in renders:
        assert_opaque(image, label)
        out_path = OUTPUT_DIR / filename
        image.save(out_path)
        print(f"wrote {out_path.relative_to(REPO_ROOT)} ({label}, {image.mode}, {image.size[0]}x{image.size[1]})")


if __name__ == "__main__":
    sys.exit(main())
