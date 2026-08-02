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
on a *transparent* background. Apple's three App Icon appearances do not all
want the same treatment of that transparency (see "Configuring your app
icon" in Apple's Human Interface Guidelines / Xcode docs, checked
2026-08-02):

- **Any/Light** is the App Store Connect slot: it must be fully opaque, no
  alpha channel at all — that is a hard rejection, not a stylistic nicety.
  This script composites it onto an opaque background at build time.
- **Dark** ships *with* a transparent background, so the system-provided
  dark background/gradient can show through around the artwork.
- **Tinted** ships as a grayscale image, also with alpha — the system
  re-tints it and composites it over its own background too.

So only the Any/Light render is flattened to opaque RGB; Dark and Tinted
keep their alpha channel.

Produces the "single size" App Icon asset (Xcode 16+ / iOS 18+): one
1024x1024 PNG per appearance, written straight into the app target's asset
catalog. iOS derives every smaller icon size from this one master at
install time; we do not hand-author per-size PNGs.

Rendering uses resvg (via the resvg-py bindings) rather than a
globally-installed rsvg-convert/ImageMagick, so the pipeline stays
reproducible on any machine and on CI: `uv run tools/render_app_icon.py`
resolves and caches the exact pinned dependencies above, no Homebrew, no
system libraries.

Colour choice (see assets/README.md and docs/superpowers/plans/
2026-08-02-m1-design-system.md, Task 8):

- Any/Light: cream-50 (#FFFCF3) background. ink-900, the near-black used for
  the tail stripes, the beak outline and the eye, contrasts 15.3:1 against
  cream-50 — the fine plumage linework stays crisp even once iOS
  downsamples this master to the smallest home-screen size.
- Dark: no background fill — the SVG's own transparency is kept as-is, so
  the olive "Hintergrund" ring layer stays a visible ring (rather than
  merging into a same-coloured fill) and the system's own dark background
  shows through around it.
- Tinted: a grayscale desaturation of the transparent Dark render, alpha
  preserved. The system applies the user's chosen tint colour itself, so
  shipping this in colour (or opaque) would fight that.

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


def render(svg_path: Path, size: int, background: str | None = None) -> Image.Image:
    """Rasterise `svg_path` at `size`.

    Without `background`, resvg renders on a transparent canvas — the SVG's
    own transparency, unmodified. With it, every pixel becomes opaque
    (alpha=255), though the alpha *channel* is still present in the
    returned image; callers that need a true no-alpha PNG (Any/Light only)
    must still `.convert("RGB")` themselves.
    """
    png_bytes = resvg_py.svg_to_bytes(
        svg_path=str(svg_path),
        width=size,
        height=size,
        background=background,
    )
    return Image.open(io.BytesIO(bytes(png_bytes)))


def to_tinted(source: Image.Image) -> Image.Image:
    """Desaturate `source` for the Tinted appearance, keeping its alpha.

    The system applies the tint colour the person picked and composites
    this over its own background, so this stays grayscale-with-alpha
    (`LA`), not a hand-redrawn or flattened variant.
    """
    return source.convert("LA")


def main() -> None:
    if not SOURCE_SVG.exists():
        raise SystemExit(f"Source SVG not found: {SOURCE_SVG}")

    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

    # Any/Light: App Store Connect slot — must be fully opaque, no alpha.
    light = render(SOURCE_SVG, ICON_SIZE, background=CREAM_50).convert("RGB")
    # Dark: transparent by design, so the system's own dark background
    # shows through and the olive ring stays a visible ring.
    dark = render(SOURCE_SVG, ICON_SIZE)
    # Tinted: grayscale of the transparent Dark render, alpha preserved.
    tinted = to_tinted(dark)

    renders = (
        (light, "AppIcon-1024.png", "Any/Light"),
        (dark, "AppIcon-1024-dark.png", "Dark"),
        (tinted, "AppIcon-1024-tinted.png", "Tinted"),
    )

    for image, filename, label in renders:
        out_path = OUTPUT_DIR / filename
        image.save(out_path)
        print(f"wrote {out_path.relative_to(REPO_ROOT)} ({label}, {image.mode}, {image.size[0]}x{image.size[1]})")


if __name__ == "__main__":
    sys.exit(main())
