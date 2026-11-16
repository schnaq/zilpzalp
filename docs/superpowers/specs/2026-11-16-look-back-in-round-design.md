# Looking back at earlier questions inside a round

Status: draft, 2026-11-16.

## Intent

Christian, playing along: „Ich wollte nochmal zurück und die Bilder jemandem
zeigen, die da angefragt wurden." Mid-round, someone wants to look at the
questions already answered and show another person the birds that were asked
— then carry on exactly where the round stood.

## Goals

- In both games („Erkenne den Vogel", „Wer singt da?"), open any question
  already answered in this round and page through them all.
- An earlier question looks as it did the moment it was answered: the four
  tiles with the same photos, the answer marked correct, the other three
  dimmed.
- Always obvious whether one is looking back or playing.
- Nothing about the round changes by looking back: no score, no star, no
  sticker counter, no re-answering.

## Non-goals

- Looking back after the round (round end, album).
- Re-showing the wrong taps of an earlier question. They are not stored and
  need not be; an earlier question shows only correct + dimmed.
- Changing how the progress row looks. The leaves stay leaves — small photos
  in their place were considered and rejected by Christian („kleine Fotos
  erkennt man nicht").
- Feedback reports from inside the look-back card. A screenshot there does
  nothing new; reports stay a thing of the live question.

## Anti-goals (a failure even if it works)

- Looking back becomes a hidden state of the quiz screen itself — the first
  draft (swiping through the quiz) was dropped for exactly this: one could not
  tell an old question from the live one, the round stood still unseen, and the
  swipe fought tile taps and the quit gesture.
- The round moves on, finishes, or leaves for the round end while the card is
  open.
- A sentence, praise or call of the live question sounds over the card, or the
  card speaks on its own.
- A tap in the card is recorded as an answer.

## Constraints

- Kids Category and speech rules as everywhere: `SpeechMode.speaks(unprompted:)`
  holds; nothing new leaves the device.
- Anything about an earlier question that can be tested without a simulator
  belongs in a package (AGENTS.md).
- `ZilpZalpUI` knows no game logic: `QuizProgress` may report which leaf was
  tapped, nothing more.
- Product copy German, code and docs English.

## Approaches

- **A. A „Die Vögel der Runde" gallery at the round end.** *Rejected by
  Christian:* only after the round; he wants it at the moment.
- **B. Swipe back through the quiz itself.** Drafted first, *rejected by
  Christian* as fiddly and confusing (see anti-goals).
- **C. Tap the progress row, look back in a card (chosen).**
- **D. A „Zuletzt gesehen" row in the album.** *Rejected:* the album shows
  earned stickers with their sticker photo, often not the photo of the round.

## The behaviour

1. **Opening.** A tap on an answered leaf of the progress row opens a card
   over the quiz on that question. The live and upcoming leaves do nothing;
   with nothing answered yet, the row is not tappable at all. Each leaf's tap
   area is its whole slot in the row, at least 44 pt high — on an iPhone the
   leaves are 24 pt, too small to aim at one by one.
2. **The card.** One answered question per page: the sound button, the
   written name (game 1 only, as in the quiz), the tiles as answered. Swiping
   left and right pages through every answered question of the round, oldest
   first; the page opened on is the tapped one. Closing: a close button (✕)
   and the system's own dismissal (swipe down, tap beside it on iPad).
3. **Sound button in the card.** Asks *that* question again: game 1 says the
   name (a tap, so always — speech mode lets taps through), game 2 plays that
   question's call. Nothing is spoken when the card opens or a page turns.
   Tiles in the card do nothing.
4. **The round holds while the card is open.** Opening stops speech and the
   call and holds the pause after an answer — the final answer's pause too, so
   the round end never opens behind the card. The live question's state
   (wrong taps, answered or not) is untouched.
5. **Closing.** The round carries on as after the feedback sheet
   (`QuizSession.carryOn()`): an open question waits quietly for a tap or the
   sound button; an answered one finishes its move to the next question, or to
   the round end after the last.
6. **VoiceOver.** The progress row stays one element and gains an action
   „Frühere Fragen ansehen" (only once something is answered) opening the card
   on the latest answered question. In the card, the pages are reachable as
   the paging control VoiceOver already knows.

## Calls made while writing this up

- Looking back is open to everyone, not behind the parental gate — showing a
  bird to someone is exactly what a child does.
- Playtime for the daily budget keeps counting while the card is open.
- Every question behind the live one is answered: `RoundPlay.advance()` has
  one caller, `QuizSession.nextQuestion()`, reached only after a correct tap.
- The card is presented like the feedback sheet (a sheet over the round), so
  pausing and carrying on reuse one path.

## Left to the builder

- Sheet vs. custom overlay, detents, and how the page indicator looks (no
  digits — the audience cannot read).
- Where the „earlier question" read model lives — e.g. a Core function giving
  a tile's phase and dimming in an answered question, with tests.
- How `QuizProgress` reports a tap (an optional `onTap: (Int) -> Void` for
  done leaves is the obvious shape).
- The German copy of the VoiceOver action and the card's close label.
