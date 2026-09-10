# Recording the spoken sentences

Everything ZilpZalp says out loud is a clip shipped as an asset. This document
is what the manifest's `voice.sourceURL` points at: it says how a take is made,
so that a sentence recorded next year sounds like one recorded today.

The plan behind it is
[docs/superpowers/plans/2026-09-08-recorded-speech.md](superpowers/plans/2026-09-08-recorded-speech.md);
the licence rules for every asset are in
[docs/medien-und-lizenzen.md](medien-und-lizenzen.md).

## What is recorded

Two groups of sentence, and they are produced separately:

- **the fixed set** — „Super gemacht!", the eight rank ascents, the parental
  gate, the two profile screens. One clip each, valid for the whole app.
- **a pack's species sentences** — „Wo ist die Amsel?", „Super gemacht! Amsel
  gesammelt!" and the bare name, one clip per species per sentence.

The exact wording never comes from memory. `fetch-media speech` takes it from
the String Catalog and prints it before it records, and the manifest keeps it
in the clip's `text`. Read what the tool prints, not what you remember.

## The session

- **One room, one session, one microphone.** Loudness is evened out afterwards;
  a room is not. Two takes recorded in different rooms sound like two people
  even when they are not.
- **A quiet room with soft furniture.** No bathroom, no empty hallway, no fan,
  no fridge, no traffic. Listen to the room for ten seconds before starting —
  what you stop hearing after a minute, the microphone does not.
- **Roughly a hand's width from the mouth**, slightly off to the side so that
  a `P` does not thump. Keep that distance for the whole session.
- **One sentence per take**, and leave a second of silence before and after it.
  The tool trims that silence away; without it, it has nothing to trim to.
- **Speak to a five-year-old in the room**, not to a microphone: warm, clear,
  a little slower than normal, and the same energy in the last sentence as in
  the first. A question ends as a question.
- **Repeat a sentence rather than repairing it.** Takes are cheap, and one
  clip is one take from beginning to end.

## The files

Any format `afconvert` reads: WAV, AIFF, M4A, FLAC, MP3. Uncompressed if the
recorder offers it.

Name a take so that it says which sentence it is — `whereIs-amsel-3.wav`,
`roundEnd.title-1.wav`. The name never reaches the repository: the tool puts
the clip where the manifest expects it, and only that copy is committed.

## Importing a take

```
mise run fetch-media speech import --pack deutschland --species amsel \
    --sentence quiz.prompt.whereIs --file whereIs-amsel-3.wav \
    --attribution "Stimme: <name>"

mise run fetch-media speech import --set fixed --sentence roundEnd.title \
    --file roundEnd.title-1.wav --attribution "Stimme: <name>"
```

The tool decodes the take, drops the silence at both ends, brings it to the
loudness every other sound in the game sits at, encodes it as mono AAC and
writes the manifest entry. It also records the voice, once per manifest —
which is why every clip of one pack has to be spoken by the same person. A
second voice in the same manifest is refused rather than merged.

**Listen to every clip before you commit it.** The tool measures loudness; it
cannot hear whether a sentence is friendly, and nothing audible goes into this
repository unheard.

## The licence line

A recording made for this project is published under **CC BY 4.0**, like the
photos and the calls, and `--attribution` is how the credits screen names the
voice. The gate accepts CC0, CC BY and CC BY-SA and nothing else — a voice that
cannot be published under one of them cannot ship.
