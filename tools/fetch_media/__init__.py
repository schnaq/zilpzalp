"""Curate media for the ZilpZalp packs.

The app never talks to iNaturalist or xeno-canto (AGENTS.md). This package is
the only thing that does, and only while a human curates a pack: it lists
candidates, a human picks one, and the tool crops it, writes the manifest
entry and uploads the result to our own bucket.
"""

__all__ = ["images", "inaturalist", "manifest", "s3"]
