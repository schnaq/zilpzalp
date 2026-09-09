"""Where one recorded sentence lives.

Two layouts, because the sentences fall into two groups with different owners
(section 3.1 of the plan):

    data/packs/<pack>/speech/<sentence>/<bird>.m4a   a species sentence
    data/speech/<sentence>.m4a                       a sentence of the fixed set

A `Target` is the answer to "which manifest, which directory, whose sentence" —
the one thing the two `speech` commands do not share. Everything after it, from
the encoder to the manifest write, is the same for both.
"""

from __future__ import annotations

import dataclasses
from pathlib import Path

from fetch_media import audio, manifest


@dataclasses.dataclass(frozen=True)
class Target:
    """The manifest a sentence belongs to, and the directory beside it."""

    directory: Path
    path: Path
    # The bird whose sentence this is; `None` is the fixed set, which has none.
    bird_id: str | None

    @property
    def label(self) -> str:
        """What to call this in a line a human reads."""
        return self.bird_id or "fixed"

    def file(self, sentence: str) -> str:
        """The clip's path relative to the manifest."""
        if self.bird_id is None:
            return f"{sentence}{audio.EXTENSION}"
        return f"{manifest.SPEECH_KIND}/{sentence}/{self.bird_id}{audio.EXTENSION}"


def for_species(pack_id: str, bird_id: str) -> Target:
    """The clips of one bird of one pack."""
    return Target(
        directory=manifest.pack_dir(pack_id),
        path=manifest.manifest_path(pack_id),
        bird_id=bird_id,
    )


def for_fixed_set() -> Target:
    """The clips that belong to no pack."""
    return Target(
        directory=manifest.SPEECH_DIR,
        path=manifest.speech_manifest_path(),
        bird_id=None,
    )
