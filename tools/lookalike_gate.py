#!/usr/bin/env python3
"""Check that every bird in the pack manifests carries a known look-alike group.

A look-alike group is curated by hand: it holds the birds a child confuses at a
glance, which is not the same as a phylogenetic family. A stork and a heron look
alike to a child though they are not close relatives, while a vulture does not
look like an eagle. The difficulty levels draw distractors from these groups
(see docs/superpowers/specs/2026-11-13-difficulty-levels-design.md), so a bird
without one would never be offered as a look-alike and a misspelled group would
quietly match nothing.

Every bird in data/packs must carry a "lookalike" key naming one of the GROUPS
below. The same bird id may appear in more than one pack, but only with the
same group in each.

Manifest shape: the one license_gate.py checks — a JSON object whose "birds"
key holds the list of birds. Each bird carries the group beside its other
fields:

    {"id": "amsel", "name": "Amsel", "lookalike": "thrush", …}

Usage: python3 tools/lookalike_gate.py [packs_dir]
       (default: data/packs)
Exit code 0 if every bird passes, 1 if any problem is found — the gate reports
all problems before it exits.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

# The vocabulary: slug → what belongs in it. The descriptions are part of the
# documentation; the keys are what manifests may name.
GROUPS = {
    "owl": "owls",
    "raptor": "eagles, hawks, buzzards, kites, harriers, falcons, caracaras, osprey, secretarybird",
    "vulture": "Old and New World vultures, condors, the bearded vulture",
    "heron": "long-legged waders: herons, egrets, bitterns, storks, cranes, ibises, spoonbills, flamingos, shoebill, hamerkop",
    "shorebird": "sandpipers, plovers, lapwings, curlews, godwits, snipes, woodcocks, oystercatchers, avocets, turnstones, jacanas",
    "gull": "gulls, terns, kittiwakes, skuas",
    "seabird": "albatrosses, fulmars, petrels, gannets, boobies, frigatebirds, tropicbirds, cormorants, anhingas, pelicans",
    "diver": "auks, puffins, guillemots, loons, grebes",
    "penguin": "penguins",
    "duck": "ducks, mergansers, eiders, shelducks, goldeneyes",
    "goose": "geese, swans, screamers",
    "rail": "rails, coots, moorhens, gallinules, swamphens",
    "gamebird": "pheasants, grouse, partridges, peafowl, junglefowl, guineafowl, turkeys, bustards",
    "ratite": "ostrich, emu, cassowaries, rheas",
    "pigeon": "pigeons and doves",
    "parrot": "parrots, cockatoos, macaws, lorikeets, budgerigars, keas",
    "woodpecker": "woodpeckers and wrynecks",
    "kingfisher": "kingfishers, kookaburras, bee-eaters, rollers, hoopoes",
    "hornbill": "hornbills, toucans, aracaris",
    "hummingbird": "hummingbirds and sunbirds",
    "swallow": "swallows, martins, swifts",
    "corvid": "crows, ravens, jackdaws, choughs, magpies, jays, nutcrackers, the Australian magpie",
    "tit": "tits, chickadees, titmice, nuthatches, treecreepers, wallcreepers, long-tailed tits",
    "finch": "finches, sparrows, buntings, cardinals, grosbeaks, crossbills, weavers, larks, tanagers",
    "thrush": "thrushes, robins, chats, redstarts, nightingales, bluebirds, wheatears, starlings, mynas, orioles, New World blackbirds",
    "warbler": "warblers, wrens, kinglets, white-eyes, bulbuls, fantails, fairywrens, flycatchers, waxwings, wagtails, shrikes, dippers",
    "cuckoo": "cuckoos, roadrunners, turacos, hoatzin",
}

# Anchored on the repository, not on the working directory, so the gate finds
# the manifests no matter where it is called from.
REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_PACKS_DIR = REPO_ROOT / "data" / "packs"


def escape_data(message: str) -> str:
    """Escape data for a GitHub workflow command — % first, then the line breaks."""
    return message.replace("%", "%25").replace("\r", "%0D").replace("\n", "%0A")


def load_document(path: Path) -> tuple[object, str]:
    """Read one manifest. Returns the document, or the reason it is unusable."""
    try:
        return json.loads(path.read_text(encoding="utf-8")), ""
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as error:
        return None, f"cannot be read: {error}"


def check_group(entry: dict, label: str) -> tuple[str, list[str]]:
    """Return the group of one bird and its problems. The group is "" if unusable."""
    group = entry.get("lookalike")
    if group is None or (isinstance(group, str) and not group.strip()):
        return "", [f"{label}: field 'lookalike' is missing or empty"]

    if not isinstance(group, str) or group not in GROUPS:
        return "", [f"{label}: 'lookalike' '{group}' is not a known group"]

    return group, []


def check(packs_dir: Path) -> list[str]:
    """Return the problems of every pack manifest below `packs_dir`, empty when fine."""
    problems = []

    # bird id → (group, pack) of the first manifest that names it, so a
    # conflicting group in a later pack can say where the first one sits.
    seen: dict[str, tuple[str, str]] = {}

    # rglob, not glob: a pack may grow its own directory, as license_gate allows.
    for path in sorted(packs_dir.rglob("*.json")):
        pack = path.relative_to(packs_dir).as_posix()
        document, error = load_document(path)
        if error:
            problems.append(f"{pack}: {error}")
            continue

        # A manifest without birds is the licence gate's to report, not ours.
        birds = document.get("birds") if isinstance(document, dict) else None
        if not isinstance(birds, list):
            continue

        for index, entry in enumerate(birds, start=1):
            # Not an object is the licence gate's to report, too.
            if not isinstance(entry, dict):
                continue

            identifier = entry.get("id")
            if isinstance(identifier, str) and identifier:
                name = identifier
            else:
                name = f"bird #{index}"

            group, group_problems = check_group(entry, f"{pack} / {name}")
            if group_problems:
                problems.extend(group_problems)
                continue

            # Without an id there is nothing to match the bird against elsewhere.
            if name != identifier:
                continue

            first_group, first_pack = seen.setdefault(identifier, (group, pack))
            if group != first_group:
                problems.append(
                    f"{identifier}: look-alike group '{group}' in {pack} "
                    f"contradicts '{first_group}' in {first_pack}"
                )

    return problems


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument(
        "packs_dir",
        nargs="?",
        default=DEFAULT_PACKS_DIR,
        type=Path,
        help=f"directory holding the pack manifests (default: {DEFAULT_PACKS_DIR})",
    )
    args = parser.parse_args(argv)

    if not args.packs_dir.is_dir():
        print(f"::error::{escape_data(f'Pack directory not found: {args.packs_dir}')}")
        return 1

    problems = check(args.packs_dir)
    for problem in problems:
        print(f"::error::{escape_data(problem)}")

    if problems:
        print(f"Look-alike gate failed: {len(problems)} problem(s)")
        return 1

    print("Look-alike gate passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
