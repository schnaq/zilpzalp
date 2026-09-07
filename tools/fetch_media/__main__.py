"""Entry point: `uv run --project tools python -m fetch_media …`."""

from __future__ import annotations

import sys

from fetch_media.cli import main

if __name__ == "__main__":
    sys.exit(main())
