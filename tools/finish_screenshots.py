#!/usr/bin/env python3
"""Hold the App Store screenshots to what App Store Connect accepts.

`mise run screenshots` writes raw simulator captures. This reads them back and
insists on the two things a screenshot is refused for at upload: the exact
pixel size of the device family it was taken for, and a PNG without an alpha
channel.

The alpha is dropped rather than only reported, the way the other checks in
this directory heal what they find. On the Xcode pinned in mise.toml (26.6)
`XCUIScreen.screenshot().pngRepresentation` already hands back 8-bit RGB, so
today it never has to; the requirement belongs to App Store Connect and not to
the simulator, and an Xcode that starts returning RGBA should be noticed here
rather than in the upload dialog.

The size is not healed. A picture of the wrong size is a picture of the wrong
screen — a rotated iPad, or a simulator that is not the one the task names —
and scaling it up to fit would only hide that.

Usage: python3 tools/finish_screenshots.py <directory> <width> <height>
Exit code 0 if every PNG was the expected size, 1 if one was not.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from PIL import Image


def finish(directory: Path, width: int, height: int) -> bool:
    """Flatten and measure every PNG in `directory`. True if all were right."""
    screenshots = sorted(directory.glob("*.png"))
    if not screenshots:
        print(f"No screenshot in {directory}", file=sys.stderr)
        return False

    correct = True
    for screenshot in screenshots:
        # Opened once: the size is read and the mode judged in the same pass,
        # and the flattened copy is written only after the handle on the file
        # it overwrites has closed.
        with Image.open(screenshot) as image:
            size = image.size
            flattened = None if image.mode == "RGB" else image.convert("RGB")
        if flattened is not None:
            flattened.save(screenshot)
            print(f"{screenshot.name}: alpha channel dropped")

        found = f"{size[0]}x{size[1]}"
        if size == (width, height):
            print(f"{screenshot.name}: {found} RGB")
        else:
            print(
                f"{screenshot.name}: {found}, expected {width}x{height}",
                file=sys.stderr,
            )
            correct = False

    return correct


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("directory", type=Path, help="where the PNGs are")
    parser.add_argument("width", type=int, help="expected pixel width")
    parser.add_argument("height", type=int, help="expected pixel height")
    arguments = parser.parse_args(argv)

    return 0 if finish(arguments.directory, arguments.width, arguments.height) else 1


if __name__ == "__main__":
    sys.exit(main())
