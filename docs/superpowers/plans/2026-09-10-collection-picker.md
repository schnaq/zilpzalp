# Plan: choosing a collection on the home screen

Status: proposed 2026-09-10, for #187. Since #184 every installed pack is merged
into one library and a round draws from all of it — 131 species with
Deutschland, Welt and Afrika installed. A child who wants „die Vögel aus
Afrika" cannot ask for them. The choice belongs to the player, on the home
screen, and it must work for somebody who cannot read. Spec §4 is the contract.

Naming: „collection" here is Christian's *Kollektion* — which birds a round
asks about. It is **not** the sticker album, which owns `CollectionScreen` and
the `collection.*` catalog keys. Every new type says so in its first line.

## The model

`Profile.collection: String?` — the pack id a child chose, `nil` for every
bird. Schema stays 1: `decodeIfPresent`, so a file written before this build
decodes as `nil`, and the synthesised encoder omits the key while it is `nil`.
Switching profiles switches the collection, because it is a field of the child.

`PackLibrary.narrowed(toPack:)` (in `PackLibrary.swift`, where `catalogs` and
`owners` are visible) is the query: the same library with `birds` and `packs`
narrowed to one pack, `nil` when no pack here carries that id. **Not a fresh
`PackLibrary([thatCatalog])`** — the merge keeps a duplicate species in the
first pack that declared it, and a rebuilt single-pack library would answer
with different media than the album and the round end, which read the merged
one. `packs` becomes a stored property so a narrowed library names one pack.

`PackCollection` and `PackCollections` (new, `ZilpZalpData`) are what the shell
reads. One collection is its pack id (`nil` for everything), its manifest
`title` (`nil` for everything — „Alle Vögel" is product copy and lives in the
app), its `library`, its `cover` bird and whether it `offersCalls`.
`PackCollections(library)` builds them: everything first, then one per pack in
library order.

Two rules, in one place so they cannot disagree:

- **A collection needs four species** (`speciesForARound`) — the four choices
  one question offers, `Round.make`'s `choiceCount`. Below that a pack is not
  offered at all, and choosing one falls back to everything. Every shipped pack
  has ten or more; this is a guard, not a screen.
- **Game 2 needs four species carrying a call** on disk (#31, moved out of
  `AppModel.callsForGameTwo`), counted inside the collection rather than across
  every pack.

`chosen(_:)` resolves a stored id: the everything entry for `nil`, for a pack a
grown-up has deleted, and for one too small to play. **Silently, and without
writing** — a read must not edit a profile, and the choice comes back if the
pack is downloaded again. The picker's selected state is the *resolved* id, so
the screen and the round always agree. A single playable pack is nothing to
choose between: `entries` is then the everything entry alone and no picker
appears.

`PackModel.rebuild()` builds `PackCollections` once per change, replacing
`speciesWithCalls`; `AppModel.games` reads it on every layout pass and must
never make it count files again.

## The UI: a chip on the home screen, a card over it

A **row of entries above the game tiles does not fit a phone.** Five entries at
the 96 pt the discs need are 480 pt wide; a 390 pt phone leaves 294 pt after
its gutters (`HomeScreen` line 104), so the row would either scroll — hidden
content for a child who cannot read — or shrink the discs under the 64 pt touch
floor. So the home screen shows **one chip** with the chosen collection's photo
and title, and tapping it opens a **card over the dimmed screen**, the pattern
`QuitConfirmation` established: the games stay visible behind it, so the child
sees what the choice is for, and every way out of the card is safe because a
tap has already taken effect.

The chip is 64 pt tall around a 48 pt disc. Measured against the tokens
(`TopBar` 96, album door 88, `step6` padding, `step7`/`step4` gaps, headline
28 pt × 1.2 over two lines):

| Screen | Game tiles today | With the chip |
|---|---|---|
| iPhone 390×844 | 188 stacked | 148 stacked |
| iPhone 375×667 (#145) | 129 stacked | 127 side by side |
| iPad 13" portrait | 240 | 240 |

Both games stay on screen everywhere, well above the 64 pt floor, because
`tiles(in:)` already measures the space it is left and picks the arrangement
the tiles come out bigger in. The iPad pays nothing.

In the card: the spoken question „Welche Vögel?", then a grid of round
sticker-style entries — `RewardSticker` at 96 pt (compact) / 128 pt, the
manifest photo of the pack's first bird, the title beneath in the album's
`StickerCaption`. The chosen entry carries an olive ring **and** a check badge,
so it is not colour alone. A tap chooses, says the collection's name and leaves
the card standing, so a child can hear one after another; the primary „Los!"
pill and a tap beside the card both close it. One announcer for question and
taps, so the two cannot talk over each other — which is why the card does not
use `ReadAloudOnce`, whose announcer is its own.

Nine entries is where the grid would run past the shortest supported phone. The
bucket offers four packs; more than that wants a scroll view and its own issue.

## Which bird stands for a pack

The first bird of the manifest — Amsel, Haussperling, Kaiserpinguin, Strauß,
all four distinctive. **„Alle Vögel" gets no photo but the bird glyph on its
sun disc**: the first bird of the whole library is the first bird of the
bundled pack, so on the simulator the two left-hand entries came out as the
same Amsel, and every bird is not one bird. **No `cover` key**: the issue allows it only if the
schema, `tools/fetch_media/manifest.py`, `license_gate.py` and the sync tool
learn it in the same pull request, and that is a second change wearing this
one's clothes.

## Tests

Swift Testing in `ZilpZalpData`, no simulator test:

- narrowing to a pack: its species only, media still resolved through the pack
  that owns them; a duplicate id stays with the pack that declared it first.
- a pack that is not installed narrows to nothing.
- entries: everything first, then one per pack, titles from the manifests.
- one playable pack is no choice at all.
- a pack with three species is not offered, and choosing it falls back to
  everything; so does an id no pack carries.
- `offersCalls`: four calls in the collection yes, three no — for a pack and
  for everything.
- `Profile`: a file without `collection` decodes as `nil`, one with it keeps it,
  and a `nil` choice is not written.

## Commits

1. this plan
2. `Profile.collection` + tests
3. `narrowed(toPack:)`, `PackCollection(s)`, the two rules + tests
4. `PackModel` collections, `SpokenLine`, the three catalog keys
5. the chip and the card
6. the wiring: `AppModel.choose(collection:)`, `HomeScreen`, `RootView`
7. spec §4: one dated paragraph
