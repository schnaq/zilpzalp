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
  level's *quartet* (below) and, where the width allows, its name. On a phone
  the name is dropped rather than wrapping the pills onto two rows — a row
  costs tile height, a word does not.
- **Picker:** tapping the pill opens „Wie schwer?" as a card over the dimmed
  home screen, the same shape as „Welche Vögel?": a speaker button for the
  question, one card per level, a tap chooses at once and says the level's
  name, the chosen card carries the olive rim **and** the check and grows to
  1.06, „Los!" or a tap beside the card closes it. Single choice.
- **The quartet** is each level's picture: a 2×2 of real photos from the bundled
  Deutschland pack showing what that level's questions look like. Leicht shows
  four birds nothing alike, Mittel one look-alike pair, Schwer three tits and one
  other. Klassisch shows a single photo of the Zilpzalp — the app's namesake,
  "the game as always" — so it reads as the usual rather than as another rung.
  Level tones: sun (Leicht), clay (Mittel), bark (Schwer), sand (Klassisch);
  olive stays reserved for "chosen", berry for "rare".
- Under each level name, one short line for the grown-up looking over the
  shoulder: „Ganz verschiedene Vögel", „Ab und zu ähnliche", „Oft sehr
  ähnliche", „Wie immer".
- New profiles start at Klassisch; profile creation stays name and avatar.

The iCloud merge needs no new rule: like name, avatar, collections and sticker
threshold, the level comes from the copy changed last (`modifiedAt`).

## The cue in a round

A tricky question announces itself, playfully, never as a warning:

- A sun-coloured **binoculars badge** sits on the sound button for as long as
  the question is tricky (Lucide 1.28.0 `binoculars`, vendored like every other
  glyph). It pops in with the bounce curve; nothing where the system asks for
  reduced motion.
- **Game 1** says „Schau genau hin!" before the bird's name when it asks the
  question by itself. A tap on the sound button repeats the name only.
- **Game 2** shows the badge only: there the call *is* the question and nothing
  is spoken over it.

## Copy (String Catalog, German)

| Key | German |
|---|---|
| `home.difficulty.title` | Wie schwer? |
| `home.difficulty.easy` / `.medium` / `.hard` / `.classic` | Leicht / Mittel / Schwer / Klassisch |
| `home.difficulty.easy.hint` … `.classic.hint` | Ganz verschiedene Vögel / Ab und zu ähnliche / Oft sehr ähnliche / Wie immer |
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
