# Difficulty levels — design

**Date:** 2026-11-13
**Status:** Approved by Christian on 2026-11-13
**Extends:** [2026-08-01-zilpzalp-v1-design.md](2026-08-01-zilpzalp-v1-design.md), §4 (game flow)
**Plan:** [../plans/2026-11-13-difficulty-levels.md](../plans/2026-11-13-difficulty-levels.md)

## Why

Today every question draws its three distractors from genera other than the
answer's (`Round.make`). That keeps a question from turning into a coin toss,
but it also makes many questions trivial: an owl among three garden songbirds is
found by its shape alone, without knowing the owl. Children who already know
their garden birds want more; children who are four want less. The game should
get harder step by step, stay fun, and never feel like a test.

## The four levels

| Level | Stored as | What a round deals |
|---|---|---|
| **Leicht** | `easy` | Distractors never look like the answer. |
| **Mittel** | `medium` | Like Klassisch, but **3 of 10** questions are *tricky*: exactly **one** look-alike beside the answer. |
| **Schwer** | `hard` | Like Klassisch, but **5 of 10** questions are tricky: **two** look-alikes beside the answer. |
| **Klassisch** | `classic` | Exactly today's rule, unchanged: distractors from another genus first. |

Effective order of difficulty: Leicht < Klassisch < Mittel < Schwer. The names
are the product owner's; Klassisch is "the game as it always was", which is why
it is the default for every existing and every new profile.

Rules that hold for every level:

- **Klassisch is byte-identical to today.** Same seed, same pool, same round —
  the existing engine tests keep passing untouched.
- **The first question is never tricky.** A round starts with one a child gets.
- **Tricky only where the pool allows it.** A question can be tricky only if its
  answer has at least one look-alike in the pool. With fewer eligible questions
  the round has fewer tricky ones; it never fails for lack of look-alikes.
- **Hard asks for two look-alikes, takes what is there.** One look-alike in the
  pool means one on screen; the remaining slots fill with unlike birds, then —
  only if the pool is too small — with further look-alikes.
- **Leicht falls back** to look-alikes only when the pool holds too few unlike
  species to fill a question (the same fallback the genus rule has today).
- Scoring is untouched: stars still count first-try answers, stickers still
  count recognitions. A harder level makes both harder to earn by itself, and a
  bird recognised in a tricky question has earned its count.

## What "looks alike" means

Two species look alike when they share a **look-alike group**, or — failing
that, or for a pack that has no groups yet — when they share a **genus**.

The group is curated by hand per species, in the pack manifest:

```json
{ "id": "waldkauz", "name": "Waldkauz", "scientificName": "Strix aluco",
  "lookalike": "owl", … }
```

- Optional key on `Bird`, decoded with `decodeIfPresent`. A pack on a device
  without it keeps working; its species fall back to the genus.
- A fixed vocabulary of group slugs, defined and documented in
  `tools/lookalike_gate.py`. The gate fails the build when a bird in
  `data/packs` has no group, a group outside the vocabulary, or a different
  group than the same species id in another pack.
- Groups describe what a child confuses at a glance (silhouette, size, colour),
  not phylogeny: vultures are not raptors, geese and swans are one group, the
  starlings sit with the thrushes because a Star next to an Amsel is the classic
  mix-up.
- Taxonomy (iNaturalist family/order) is deliberately not used as the signal:
  it over-groups (Anatidae is swans and mergansers) and under-groups (waders
  span four families). The app never talks to iNaturalist at runtime anyway.

The ten packs in the bucket are re-uploaded with `fetch-media` after the merge;
until a device updates a pack, that pack plays with the genus fallback.

## Who chooses, and where

**The child**, on the home screen — like its collection, the level is a taste
of the child, stored per profile (`Profile.difficulty`, a raw string, default
`"classic"`). Siblings on one iPad keep their own level.

- **Home screen:** a second 64 pt pill beside the collection pill. It shows the
  level's *mosaic* — the quartet below as a bare 48 pt square, 2 pt gutters,
  outer radius 20, no frame — and, on an iPad, the level's name. On a phone
  the name is dropped rather than wrapping the pills onto two rows: a row
  costs tile height, a word does not. Gap between the pills 12 pt on a phone
  (with „Alle Vögel" the pair fits the 343 pt of a 375 pt iPhone), 16 on an
  iPad. Only where the collection's own title would not fit beside the level
  pill at full size — „Vögel Deutschlands" on a phone — do the two pills
  stack: shrinking that title under the 20 pt floor of a kid screen is not an
  option, a few points of tile are.
- **Picker:** tapping the pill opens „Wie schwer?" as a card over the dimmed
  home screen, the same shape as „Welche Vögel?" (max width 720, padding 32 on
  iPad and 24 on a phone): a speaker button for the question, a tap chooses at
  once and says the level's name, „Los!" or a tap beside the card closes it.
  Single choice. Where the height runs short — an iPad mini in landscape, a
  short Stage Manager window — the rungs shrink from 200 to 160 pt first and
  the levels scroll only after that, as „Welche Vögel?" does.
- **The ramp:** Leicht, Mittel and Schwer stand as three square tiles in **one
  row** on every device, so the order reads left to right as easy to hard.
  **Klassisch is not a rung:** it is a full-width row underneath (photo, name,
  „Bunt gemischt"), so it never reads as "harder than Schwer".
- **The quartet** is each rung's picture: a 2×2 of real photos from the bundled
  Deutschland pack showing what that level's questions look like, the
  look-alikes side by side in the top row. Leicht: Steinkauz, Stockente,
  Eisvogel, Buntspecht (nothing alike). Mittel: Amsel next to Star, then
  Höckerschwan and Gimpel. Schwer: Kohlmeise next to Blaumeise, then Kleiber
  and Rotkehlchen. Klassisch: the Zilpzalp alone — the app's namesake. No
  species appears twice; every photo is the species' curated portrait, so the
  picture comes from the same cache as every other one.
- **Binoculars stickers count the look-alikes:** none on Leicht, one on
  Mittel, two (overlapping, the second tilted +6°) on Schwer, on the tile's top
  edge near the right corner and never over a bird. A child who cannot read
  can count them, and meets the quiz's badge before it appears in a round.
- **Neutral tiles:** every tile and the Klassisch row use `ChoiceTile`'s
  papier tone — sand-200 field, 5 pt sand-400 rim and ledge (10 pt on iPad,
  6 on a phone), radius 40 on iPad and 28 on a phone. Sun means reward and
  "try again", clay is info, bark is a rubric, so none of them may mean a level;
  olive stays the one colour signal, and it means "chosen".
- **Chosen** is `RewardSticker`'s chosen state: the rim turns olive-500 at the
  same 5 pt (nothing shifts), the ledge olive-700, a check badge sits on the
  bottom-right corner, and the whole cell — tile and name — grows to 1.06.
- **Words:** level names in Baloo 800, 28 pt on iPad, 22 on a phone. One line
  for the grown-up under the ramp, „Je schwerer, desto ähnlicher die Vögel",
  Nunito 600, 20 pt, ink-700.
- New profiles start at Klassisch; profile creation stays name and avatar.

The iCloud merge needs no new rule: like name, avatar, collections and sticker
threshold, the level comes from the copy changed last (`modifiedAt`).

## The cue in a round

A tricky question announces itself, playfully, never as a warning:

- A **binoculars sticker** sits on the sound button's top-right for as long as
  the question is tricky (Lucide 1.28.0 `binoculars`, vendored like every other
  glyph): sun-300 disc, sun-600 edge, a cream cut-out ring, the medium shadow,
  tilted −8°, glyph in bark-700 at 60 % (RewardSticker's own sun pair) — a
  sticker, not a button: no ledge, because a ledge says "press me", and not
  black on yellow, which is the hazard-sign palette. 56 pt on the iPad's
  160 pt button, 44 pt on the phone's 120 pt one, overhanging by 8 pt at most;
  taps pass through to the button. It pops in with the bounce curve when the
  question appears and does nothing after — the sound button's rings already
  move; nothing at all where the system asks for reduced motion.
- **Game 1** says „Schau genau hin!" before the bird's name when it asks the
  question by itself. A tap on the sound button repeats the name only.
- **Game 2** shows the badge only: there the call *is* the question and nothing
  is spoken over it.

## Copy (String Catalog, German)

| Key | German |
|---|---|
| `home.difficulty.title` | Wie schwer? |
| `home.difficulty.easy` / `.medium` / `.hard` / `.classic` | Leicht / Mittel / Schwer / Klassisch |
| `home.difficulty.hint` | Je schwerer, desto ähnlicher die Vögel |
| `home.difficulty.classic.hint` | Bunt gemischt |
| `home.difficulty.change.accessibility` | Schwierigkeit: %@. Ändern |
| `quiz.tricky` | Schau genau hin! |
| `quiz.tricky.accessibility` | Knifflige Frage |

Spoken lines (`home.difficulty.title`, the four level names, `quiz.tricky`) use
the synthesiser until clips are rendered with
`fetch-media speech render --sentence <key>`.

## Boundaries

- `ZilpZalpCore` owns `Difficulty` and every rule above; it stays free of
  SwiftUI, I/O and product strings.
- `ZilpZalpData` stores strings (`Bird.lookalike`, `Profile.difficulty`) and does
  not depend on Core, as with `stickerThreshold`.
- `ZilpZalpUI` gets the picture-only parts (the quartet, the badge); it knows no
  levels.
- The app target maps profile → `Difficulty`, levels → pictures and words.

## Out of scope

Adaptive difficulty (the app raising the level by itself), a timer, more or fewer
than four choices, per-level scoring, and a level for game 2 that differs from
game 1.
