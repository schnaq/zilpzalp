"""The German a clip says, taken from where the app takes it.

Nothing here spells a sentence out. The words come from the String Catalog —
`apps/ZilpZalp/Resources/Localizable.xcstrings`, the one place German product
copy lives — and the species come from the pack manifest, so a sentence
reworded in Xcode is rendered as it now reads instead of as it once did. What
this module does spell out is *how* each sentence is filled, and that is
tool knowledge: it mirrors the eight call sites the app speaks through.

Two sentences are species-dependent and therefore one clip per species:
`collection.name`, „Amsel" — the spoken name alone — and `species.fact`, the
one short sentence the manifest's `fact` holds about the bird.

Neither is in the catalog. `collection.name` is not: the sentence *is* the
name, so there is nothing to translate and nothing to fill. The album says it when a
sticker is tapped, since #220 it is the question of game 1, and since #264 it
is what the round end says right after „Super gemacht!" for a sticker just
earned — one clip per species, heard in three places.
`SpeechKey.speciesName` in `ZilpZalpData` is this key on the Swift side.

`species.fact` is not either, because the fact is species content written per
pack, like the name, and not screen copy. It is named like `pack.title` —
whose data it is, then the manifest field it is read from — rather than after
a screen, so the key stays true wherever the app ends up saying it. A bird
without a `fact` has no such sentence, and naming it for one is refused.

„Super gemacht! Amsel gesammelt!" — `roundEnd.sticker.new.spoken` — is still
in the catalog, but for VoiceOver only: the round end plays the fixed praise
and the name one after the other, so nothing renders it.

Every fixed sentence — „Super gemacht!", the eight rank ascents, the parental
gate, the two profile screens — is whatever the catalog says under its key, and
must carry no placeholder at all. The one sentence that does, the star count on
„Zeit fürs Nest", is recorded once per count (decision 4 of the plan, answered
2026-11-14): `timeBudget.starsToday.spoken.7` is the catalog's plural entry
`timeBudget.starsToday.spoken` with 7 filled in, „Heute hast du 7 Sterne
gesammelt." `SpokenLine.counted` in the app forms the same key. The bare plural
key is still refused rather than recorded with a hole in it.
"""

from __future__ import annotations

import json
import re

from fetch_media.manifest import REPO_ROOT

CATALOG = REPO_ROOT / "apps" / "ZilpZalp" / "Resources" / "Localizable.xcstrings"

# The app ships German and is only built to be translatable; a clip is a
# recording of one language, and this is that language.
LANGUAGE = "de"

# The species sentences, in the order `--sentence` lists them.
SPECIES_SENTENCES = ("collection.name", "species.fact")

# What a pack render produces per bird when no `--sentence` is named: the name
# alone. A fact is rendered only on request, so a run meant for the facts never
# pays for every name again, and a run meant for the names never for the facts.
DEFAULT_SPECIES_SENTENCES = ("collection.name",)

# The sentences about a pack itself, one clip per pack: `pack.title`, the
# manifest's title spoken — what the collection picker says when a child taps
# the pack (#306). `SpeechKey.packTitle` in `ZilpZalpData` is this key on the
# Swift side. Not in the catalog either: the title is the pack's data.
PACK_SENTENCES = ("pack.title",)

# `%1$@`, `%2$@` and the unpositional `%@`, which is what Swift's
# `String(format:)` is given at the call sites this mirrors.
PLACEHOLDER = re.compile(r"%(?:(\d+)\$)?@")

# `<plural key>.<count>`: one clip per count of a sentence that varies by one.
COUNTED = re.compile(r"(?P<key>.+)\.(?P<count>0|[1-9][0-9]*)")


def german(key: str, count: int | None = None) -> str:
    """The German value of one String Catalog key, for `count` where it varies by one.

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
    variations = localised.get("variations") or {}
    plural = variations.get("plural")
    if variations and plural is None:
        raise ValueError(f"'{key}' varies by something other than a count: {', '.join(variations)}")
    if plural is None and count is not None:
        raise ValueError(f"'{key}' does not vary by a count, so '{key}.{count}' says nothing")
    if plural is not None:
        if count is None:
            raise ValueError(
                f"'{key}' varies by a plural: a clip says one sentence, not one per count. "
                f"Name the count — '{key}.7' — to record one clip per count."
            )
        # German's integer rule: `one` for 1 and nothing else, `other` for every
        # other count — what `String(format:)` picks for `%lld`. An explicit
        # `zero` wins for 0, as it does in the app.
        category = "zero" if count == 0 and "zero" in plural else "one" if count == 1 else "other"
        localised = plural.get(category) or plural.get("other") or {}

    value = (localised.get("stringUnit") or {}).get("value")
    if not value:
        raise LookupError(f"'{key}' has no {LANGUAGE} value in {CATALOG.name}")
    return str(value) if count is None else str(value).replace("%lld", str(count))


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
    any code. `SpokenLine.name` in the app is this rule on the other side.
    """
    return str(bird.get("pronunciation") or bird["name"])


def species_text(bird: dict, sentence: str) -> str:
    """What one species sentence says for one bird."""
    if sentence == "collection.name":
        return spoken_name(bird)
    if sentence == "species.fact":
        fact = bird.get("fact")
        if not fact:
            raise LookupError(f"'{bird['id']}' has no `fact` in its manifest to say")
        return str(fact)

    known = ", ".join(SPECIES_SENTENCES)
    raise LookupError(f"'{sentence}' is not a species sentence (expected one of {known})")


def pack_text(document: dict, sentence: str) -> str:
    """What one sentence about a pack says."""
    if sentence == "pack.title":
        return str(document["title"])

    known = ", ".join(PACK_SENTENCES)
    raise LookupError(f"'{sentence}' is not a pack sentence (expected one of {known})")


def fixed_text(sentence: str) -> str:
    """What one of the sentences that belong to no species says.

    A catalog key as it stands, or `<plural key>.<count>` — the key itself
    first, so a catalog key that happens to end in digits is never split.
    """
    try:
        return fill(german(sentence))
    except LookupError:
        counted = COUNTED.fullmatch(sentence)
        if counted is None:
            raise
    return fill(german(counted["key"], int(counted["count"])))
