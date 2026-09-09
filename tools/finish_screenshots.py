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
screen — a rotated iPad, a simulator that is not the one the task names — and
scaling it up to fit would only hide that.

Usage: python3 tools/finish_screenshots.py <directory> <width> <height>
Exit code 0 if every PNG was the expected size, 1 if one was not.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image


def finish(directory: Path, size: tuple[int, int]) -> bool:
    """Flatten and check every PNG in `directory`. True if all were right."""
    screenshots = sorted(directory.glob("*.png"))
    if not screenshots:
        print(f"No screenshot in {directory}", file=sys.stderr)
        return False

    correct = True
    for screenshot in screenshots:
        with Image.open(screenshot) as image:
            found = image.size
            flattened = image.convert("RGB") if image.mode != "RGB" else None
        if flattened is not None:
            flattened.save(screenshot)
            print(f"{screenshot.name}: alpha channel dropped")

        if found != size:
            print(
                f"{screenshot.name}: {found[0]}x{found[1]}, expected "
                f"{size[0]}x{size[1]}",
                file=sys.stderr,
            )
            correct = False
        else:
            print(f"{screenshot.name}: {found[0]}x{found[1]} RGB")

    return correct


def main(argv: list[str]) -> int:
    if len(argv) != 4:
        print(__doc__, file=sys.stderr)
        return 2

    directory = Path(argv[1])
    size = (int(argv[2]), int(argv[3]))
    return 0 if finish(directory, size) else 1


if __name__ == "__main__":
    sys.exit(main(sys.argv))
