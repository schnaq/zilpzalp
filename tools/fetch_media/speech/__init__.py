"""Recorded speech: the sentences the app says out loud.

`fetch-media speech render` asks a provider for a sentence; `fetch-media speech
import` takes a take somebody recorded. Both end in the same place — a mono
AAC clip beside the manifest, normalised to the loudness every other sound in
the game sits at, and one entry in the manifest that names it.

The core knows no vendor. `provider.py` is the whole interface, `fake.py` the
adapter the tests use, and the first real one is a small module beside them
once decisions 1 and 2 of the plan are answered
(docs/superpowers/plans/2026-09-08-recorded-speech.md).
"""

from __future__ import annotations

from fetch_media.speech.fake import FakeProvider
from fetch_media.speech.provider import Provider, Voice

# Every adapter this tool can be pointed at. `--provider` takes its choices
# from here, so a new adapter is one entry and no change to the command line.
PROVIDERS: dict[str, type] = {FakeProvider.name: FakeProvider}

__all__ = ["PROVIDERS", "Provider", "Voice", "provider"]


def provider(name: str) -> Provider:
    """The adapter of that name, ready to speak."""
    if name not in PROVIDERS:
        known = ", ".join(sorted(PROVIDERS))
        raise LookupError(f"no speech provider '{name}' (have: {known})")
    return PROVIDERS[name]()
