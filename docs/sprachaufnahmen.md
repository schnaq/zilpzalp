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
- **a pack's species sentences** — „Super gemacht! Amsel gesammelt!" and the
  bare name „Amsel", one clip per species per sentence. The bare name is what
  game 1 asks with as well since #220, so it is recorded once and heard in two
  places.

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

Name a take so that it says which sentence it is — `amsel-3.wav`,
`roundEnd.title-1.wav`. The name never reaches the repository: the tool puts
the clip where the manifest expects it, and only that copy is committed.

## Importing a take

```
mise run fetch-media speech import --pack deutschland --species amsel \
    --sentence collection.name --file amsel-3.wav \
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

## Rendering with ElevenLabs

The other way to produce a clip is to render it. ElevenLabs is the vendor
decision 1 of the plan settled on, for one reason: it is the only one whose
terms were read at the source and found to grant both commercial use and
**ownership of the output** (EEA ToS §1(c) and §4(c)(ii)). Ownership is what
lets this project publish a clip under CC BY 4.0 at all.

Three conditions come with that grant, and none of them is code:

- the account is **schnaq GmbH's**, not a personal one;
- the clips are rendered **while the paid subscription is active** — the free
  tier is non-commercial, and content generated outside a paid period is not
  covered. **Starter ($5–6 per month)** is enough: everything the app says is
  a few thousand characters, which is one month;
- the **Sound Effects** product is never used for a shipped asset (its
  Prohibited Use Policy §9(c) forbids exactly the "isolated files" pattern
  this pipeline is). Text to speech is unaffected.

### The key

`ELEVENLABS_API_KEY`, in Infisical under environment `dev`, path `/` — beside
`XENO_CANTO_API_KEY`. It never enters the repository and never a log; the tool
takes its key in a header and removes it from every message it prints
(`fetch_media.keys`). Every command below is wrapped:

```
infisical run --env=dev --path=/ -- mise run fetch-media speech …
```

### Choosing a voice

There is no default voice, on purpose: which voice a child hears is a decision,
not a fallback. List what the account offers, listen to them in the ElevenLabs
dashboard, and pass one to `--voice` — by id or by name.

```
infisical run --env=dev --path=/ -- mise run fetch-media speech voices \
    --provider elevenlabs
```

The chosen voice becomes the manifest's `voice` block: „Stimme: <name>
(ElevenLabs)", CC BY 4.0, this document as the source. One manifest carries one
voice, so rendering a pack a second time with a different `--voice` is refused
rather than merged — a change of voice means re-rendering everything in that
manifest (decision 7: the app does not mix voices).

### Rendering

One sentence for one bird:

```
infisical run --env=dev --path=/ -- mise run fetch-media speech render \
    --provider elevenlabs --voice "<name>" \
    --pack deutschland --species amsel --sentence collection.name
```

Every species' name line of a pack — no `--species`, so every bird in it:

```
infisical run --env=dev --path=/ -- mise run fetch-media speech render \
    --provider elevenlabs --voice "<name>" \
    --pack deutschland --sentence collection.name
```

Everything a pack says, all three species sentences, is the same command
without `--sentence`; the fixed set is `--set fixed --sentence …`, which names
its sentences explicitly. Every run prints the number of characters it is about
to render before it renders them, and refuses to go over `--max-chars` (30000
by default): a paid provider bills characters, so the count is the price, and
the cap is there for the run that was meant to be one bird.

The model is `eleven_multilingual_v2` with a fixed seed and fixed voice
settings. Determinism is best effort — ElevenLabs says so — so two renders of
one sentence may differ slightly. Re-render one clip rather than a pack.

### The audio

`pcm_24000` is the best format the Starter tier serves: 44.1 kHz PCM needs Pro
and 192 kbps MP3 needs Creator. It arrives as raw samples, the tool puts a WAV
header on them, and from there a rendered clip goes through exactly the same
trim, normalisation and AAC encoding as an imported take.

**Listen to every clip before you commit it**, exactly as with a take. A
synthetic voice mispronounces bird names — `pronunciation` in the pack manifest
is how that is fixed, and the tool speaks it where it is set.

## The licence line

A recording made for this project is published under **CC BY 4.0**, like the
photos and the calls, and `--attribution` is how the credits screen names the
voice. On a render the adapter names it instead of `--attribution` — „Stimme:
<name> (ElevenLabs)" — under the same licence, which the vendor's terms leave
ours to give. The gate accepts CC0, CC BY and CC BY-SA and nothing else — a
voice that cannot be published under one of them cannot ship.
