"""The German a clip says, taken from where the app takes it.

Nothing here spells a sentence out. The words come from the String Catalog —
`apps/ZilpZalp/Resources/Localizable.xcstrings`, the one place German product
copy lives — and the species come from the pack manifest, so a sentence
reworded in Xcode is rendered as it now reads instead of as it once did. What
this module does spell out is *how* each sentence is filled, and that is
tool knowledge: it mirrors the eight call sites the app speaks through.

Two sentences are species-dependent and therefore one clip per species:

| Sentence key                  | German                     | Filled with          |
|-------------------------------|----------------------------|----------------------|
| `roundEnd.sticker.new.spoken` | „Super gemacht! %@ …!"     | spoken name          |
| `collection.name`             | „Amsel"                    | spoken name alone    |

`collection.name` is the one key that is not in the catalog: the sentence *is*
the name, so there is nothing to translate and nothing to fill. The album says
it when a sticker is tapped, and since #220 it is also the question of game 1
— one clip per species, heard in two places. `SpeechKey.speciesName` in
`ZilpZalpData` is this key on the Swift side.

There were three until #220. „Wo ist die Amsel?" — `quiz.prompt.whereIs` — was
the question of game 1, and it is gone from the catalog with the sentence: the
game asks with the bare name now, so the sentence has neither words to render
nor a screen to say it.

Every fixed sentence — „Super gemacht!", the eight rank ascents, the parental
gate, the two profile screens — is whatever the catalog says under its key, and
must carry no placeholder at all. The one sentence that does, the star count,
is decision 4 of the plan: it is to be reworded so that nothing numeric is
spoken, and until it is, this tool refuses it rather than recording „Heute hast
du %lld Sterne gesammelt".
"""

from __future__ import annotations

import json
import re

from fetch_media.manifest import REPO_ROOT

CATALOG = REPO_ROOT / "apps" / "ZilpZalp" / "Resources" / "Localizable.xcstrings"

# The app ships German and is only built to be translatable; a clip is a
# recording of one language, and this is that language.
LANGUAGE = "de"

# The species sentences, in the order `--sentence` lists and defaults to.
SPECIES_SENTENCES = ("roundEnd.sticker.new.spoken", "collection.name")

# `%1$@`, `%2$@` and the unpositional `%@`, which is what Swift's
# `String(format:)` is given at the call sites this mirrors.
PLACEHOLDER = re.compile(r"%(?:(\d+)\$)?@")


def german(key: str) -> str:
    """The German value of one String Catalog key.

    Read from disk on every call rather than cached: twenty times for a whole
    pack, of a file the size of a photograph's thumbnail, against a command a
    human is waiting for anyway. A cache would save milliseconds and cost an
    invalidation rule.
    """
    catalog = json.loads(CATALOG.read_text(encoding="utf-8"))
    entry = (catalog.get("strings") or {}).get(key)
    if not isinstance(entry, dict):
        raise LookupError(f"'{key}' is not a key in {CATALOG.name}")

    localised = (entry.get("localizations") or {}).get(LANGUAGE) or {}
    if "variations" in localised:
        raise ValueError(
            f"'{key}' varies by a plural: a clip says one sentence, not one per count. "
            "Reword it so that nothing numeric is spoken — decision 4 of the plan."
        )

    value = (localised.get("stringUnit") or {}).get("value")
    if not value:
        raise LookupError(f"'{key}' has no {LANGUAGE} value in {CATALOG.name}")
    return str(value)


def fill(template: str, *arguments: str) -> str:
    """Resolve the placeholders the way `String(format:)` does.

    A placeholder this tool cannot fill — `%lld` above all — is an error and
    not a sentence with a hole in it: the clip would say the wrong thing and
    nobody would notice until a child heard it.
    """
    unpositional = 0

    def resolve(match: re.Match) -> str:
        nonlocal unpositional
        if match.group(1):
            index = int(match.group(1)) - 1
        else:
            index = unpositional
            unpositional += 1
        # Both ends: `String(format:)` counts from 1, so `%0$@` is not an
        # argument this can fill — and a negative index would quietly hand back
        # the last one instead of saying so.
        if not 0 <= index < len(arguments):
            raise ValueError(
                f"{template!r} names an argument outside the {len(arguments)} it was given"
            )
        return arguments[index]

    filled = PLACEHOLDER.sub(resolve, template)
    if "%" in filled:
        raise ValueError(f"{template!r} carries a placeholder this tool cannot fill")
    return filled


def spoken_name(bird: dict) -> str:
    """What the bird is called out loud.

    `pronunciation` overrides the name where a voice would mangle it — that is
    the field's whole purpose, and it belongs in the pack data rather than in
    any code. `RoundEndScreen` passes the display name today where this passes
    the spoken one; with every `pronunciation` in the base pack still null,
    there is nothing between the two to hear.
    """
    return str(bird.get("pronunciation") or bird["name"])


def species_text(bird: dict, sentence: str) -> str:
    """What one species sentence says for one bird."""
    name = spoken_name(bird)
    if sentence == "collection.name":
        return name
    if sentence == "roundEnd.sticker.new.spoken":
        return fill(german(sentence), name)

    known = ", ".join(SPECIES_SENTENCES)
    raise LookupError(f"'{sentence}' is not a species sentence (expected one of {known})")


def fixed_text(sentence: str) -> str:
    """What one of the sentences that belong to no species says."""
    return fill(german(sentence))
