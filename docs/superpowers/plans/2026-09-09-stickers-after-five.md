# Plan: a sticker after five recognitions, and no more ranks

Status: proposed 2026-09-09. Christian and Johanna on #177: *"Wir würden gerne
die Ränge (Vogel-Leiter) abschaffen. Stattdessen bekommt man den Sticker vom
Vogel in sein Stickeralbum (so wie jetzt auch schon in der Sammlung), aber erst,
wenn man ihn 5 mal korrekt erkannt hat. Die Sterne dürfen bleiben."*

## The rule

- **Recognised** is a correct answer at the first attempt — `RoundPlay.Tap`'s
  `correct(firstTry: true)`. A tile found after a wrong tap does not count: with
  four choices the right one is always found in the end, and that is not
  recognition. Both games count; the bird was named or its call was known.
- **Five recognitions of one species earn its sticker**, per profile.
  `Scoring.recognitionsForSticker = 5` in `ZilpZalpCore` is the only place the
  number is written.
- Stars are untouched: three per round at most, `Scoring.stars(firstTryCorrect:)`
  as before, counted on the profile.
- **The celebrated bird** of a round, `RoundPlay.celebratedSpecies(recognisedBefore:)`,
  in this order: a species whose sticker was completed this round → else the
  species that came closest to five without reaching it, among those that made
  progress this round → else the first species recognised this round (its
  sticker was already there) → else the first question's answer, so a round with
  nothing right still shows the bird it began with.
- One ordered record answers all of it: `RoundPlay.firstTryRecognitions: [String]`,
  the species in the order their first-try answers happened, repeats included —
  a short pack asks for the same bird twice in a round. Counts, the fallback and
  every tie-break are read off that one list, so they cannot disagree.

## The data change

- `Profile.collectedSpecies: Set<String>` becomes
  `Profile.recognitions: [String: Int]`, species id → first-try answers ever.
- `PlayedRound.species: Set<String>` becomes `PlayedRound.recognitions: [String: Int]`;
  `ProfileStore.record` adds the counts up instead of `formUnion`. Merely meeting
  a bird no longer collects it.
- Profile's hand-written `encode(to:)` goes: it existed to sort a `Set`, and
  `.sortedKeys` already sorts a dictionary's keys, so the file stays byte-stable
  without it.

**Migration.** Schema version stays 1. `recognitions` decodes with
`decodeIfPresent ?? [:]`, exactly as `dailyStars` did in #36, and
`collectedSpecies` leaves `CodingKeys` — an old file's key is therefore ignored
on the way in and gone on the next write. **Existing test profiles lose their
stickers and keep their stars**: those stickers were handed out under the old
rule, this is pre-release data, and the honest reading of the new rule is that
five recognitions have not happened yet.

## Round end and album

- Under the celebrated sticker, five markers filled from the left to the
  profile's counter — a child who cannot count to five still sees "nearly" and
  "done". A new `ZilpZalpUI` component fed plain values (`count`, `of`,
  `markerSize`), no product text inside; the sticker's own sun palette, never
  stars, because the stars are the round's score.
- The fifth marker filling is the sticker being earned. It reuses the path the
  first find used: the pop, the caption, and the one sentence the screen says
  out loud.
- A round that could not be written down shows no markers, as it makes no other
  claim it cannot back up.
- Album: an unearned bird keeps its locked sticker and gains the markers under
  it — a bird at zero shows five empty ones, because what a child can see is
  what a child can want. An earned bird is the sticker it always was. The
  "Deine Vogel-Leiter" button and the rank line under a name in "Unser Schwarm"
  go.

## Removal

`RankLadder` and `Rank` in `ZilpZalpCore` (+ `RankLadderTests`),
`RankLadderScreen`, `RankAscentScreen`, `RankRung`, `RankNames`, `Route.ladder`,
`Route.rankAscent`, `RankAscent`, the ascent push and its delay in
`RoundEndScreen`, `RootView`'s ladder and ascent destinations, the ladder link
in `CollectionScreen`, the rank properties and `ascent` of `RoundOutcome`, the
rank line in `SwarmList`, every `rank.*` key in the String Catalog, the previews
of the deleted screens, and the prose that mentions any of it.

## Tests

- Core: first-try recognitions are recorded in order, repeats included, and a
  second-attempt answer is not among them; each of the four steps of the
  celebrated-bird rule, including a repeat and a round with nothing right; the
  threshold constant is 5.
- Data: a v1 file written before `recognitions` decodes with none and keeps its
  stars; a file with `recognitions` decodes them; booking a round adds the
  counts up over two rounds; the written file still sorts its keys.
- UI: the marker row clamps a count outside `0 ... of` and draws `of` markers.

## Commits

1. this plan
2. remove the ladder, the ranks and the ascent (Core and app together)
3. count recognitions and earn a sticker at five (Core, Data, app wiring)
4. draw the way to the next sticker (ZilpZalpUI, round end, album)
5. the spec

## Decisions taken while planning

- **The threshold lives in Core, the derivation in the app.** `ZilpZalpData`
  does not depend on `ZilpZalpCore` and should not start to for one integer, so
  `Profile` keeps the raw counters and the app target — which links both —
  derives `hasSticker(for:)` and `collectedSpecies` from
  `Scoring.recognitionsForSticker`. One source of truth, no new package edge.
- **The celebrated bird is settled where the round is played**, as before: the
  quiz asks the model for the counters at the moment the round finishes, through
  a closure rather than a stored snapshot, so a second round in the same sitting
  cannot be judged against the first round's counters.
- **„Neuer Sticker!" is said, not written twice.** The written caption stays
  "%@ gesammelt"; the spoken sentence carries the news, because that is the
  channel this audience actually receives.
- **The removal is committed first.** Every commit builds that way, and a pure
  deletion is the smallest possible merge surface against #165 and #175, which
  are editing the same two screens.
