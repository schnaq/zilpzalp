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

## Rendering with Google Cloud Text-to-Speech

The other way to produce a clip is to render it, and **Google Cloud
Text-to-Speech is the renderer this project uses** (issue #234). Chirp 3 HD
speaks native German at the current top tier, everything the app says is a few
thousand characters a month against a free tier of a million, and the grant is
the plainest of the three that were read at the source:

> "You can use the audio data files you create using Cloud Text-to-Speech to
> power your applications […]"
> — <https://docs.cloud.google.com/text-to-speech/docs/basics>

No attribution is owed and no disclosure — Azure would have required one, and
that is part of why it did not win. What Google's terms do **not** say in
writing is that the output is ours; section 2.1 of the plan records that no
ownership clause could be read at the source, and no prohibition either.
Publishing the clips under CC BY 4.0 is therefore a decision (#234), not a
quotation. It changes nothing downstream: the gate, the credits screen and the
`License` enum all take CC BY 4.0 as they stand.

**ElevenLabs stays in the tree as `speech/elevenlabs.py` and is not used.** It
was built first (#221, decision 1 of the plan) and its terms are the clearest
of all — commercial use and ownership of the output on any paid tier — but the
account is on the free tier, which is non-commercial and does not serve library
voices through the API. If that ever changes, the adapter is `--provider
elevenlabs` and needs no work; nothing else in the pipeline knows the
difference.

### Setting the project up, once

This is Christian's, and it is done once:

1. A **Google Cloud project** for it — `zilpzalp-speech` is a good name — with
   **billing attached**. The free tier is a million characters a month for
   Chirp 3 HD, but no project renders anything without a billing account.
2. Enable **`texttospeech.googleapis.com`** (Cloud Text-to-Speech API) in that
   project. This is the single commonest first-day failure, and it comes back
   as a 403 that names the API.
3. A **service account** in the same project — `zilpzalp-speech-render` — with
   the **Cloud Text-to-Speech User** role (`roles/cloudtts.user`). If the role
   picker does not offer it, the API is not enabled yet (step 2); a project
   whose API is enabled also grants it through
   `roles/serviceusage.serviceUsageConsumer` plus billing, but the narrow role
   is the right one. Nothing here needs Editor or Owner.
4. **Keys → Add key → Create new key → JSON.** Download it once; Google keeps
   no copy. A newer organisation may refuse this with a policy error
   (`iam.disableServiceAccountKeyCreation`) — the constraint has to be lifted
   for that project before a key can be created at all.

### The key

`GOOGLE_TTS_SERVICE_ACCOUNT_JSON`, in Infisical under environment `dev`, path
`/` — beside `XENO_CANTO_API_KEY`. It holds the **whole downloaded JSON file**
as one value, newlines in the private key and all; nothing is extracted from it
by hand.

The tool signs a JWT with the private key inside it, exchanges that at
`https://oauth2.googleapis.com/token` for an access token good for an hour, and
sends the token as a bearer. Four things therefore exist that must never reach a
log — the JSON, the private key inside it, the assertion and the token — and the
adapter removes all four from every message it prints (`fetch_media.keys` and
`speech/google.py`). The key never enters the repository. Every command below is
wrapped:

```
infisical run --env=dev --path=/ -- mise run fetch-media speech …
```

### Choosing a voice

There is no default voice, on purpose: which voice a child hears is a decision,
not a fallback. List the German Chirp 3 HD voices, listen to them in the Google
Cloud console's Text-to-Speech demo, and pass one to `--voice` — by its whole
name or by the short one after the last dash.

```
infisical run --env=dev --path=/ -- mise run fetch-media speech voices \
    --provider google
```

Each line is the voice's full name, its short name, its gender and its natural
sample rate — `de-DE-Chirp3-HD-Aoede  Aoede  female, 24000 Hz`. Only de-DE
Chirp 3 HD voices are listed; the endpoint answers with every family in every
language, and a list nobody can read is not a list.

The chosen voice becomes the manifest's `voice` block: „Stimme: <name> (Google
Cloud Text-to-Speech)", CC BY 4.0, this document as the source. One manifest
carries one voice, so rendering a pack a second time with a different `--voice`
is refused rather than merged — a change of voice means re-rendering everything
in that manifest (decision 7: the app does not mix voices).

### Rendering

One sentence for one bird:

```
infisical run --env=dev --path=/ -- mise run fetch-media speech render \
    --provider google --voice de-DE-Chirp3-HD-Aoede \
    --pack deutschland --species amsel --sentence collection.name
```

Every species' name line of a pack — no `--species`, so every bird in it:

```
infisical run --env=dev --path=/ -- mise run fetch-media speech render \
    --provider google --voice de-DE-Chirp3-HD-Aoede \
    --pack deutschland --sentence collection.name
```

Everything a pack says, all three species sentences, is the same command
without `--sentence`; the fixed set is `--set fixed --sentence …`, which names
its sentences explicitly. Every run prints the number of characters it is about
to render before it renders them, and refuses to go over `--max-chars` (30000
by default): a provider bills characters, so the count is the price, and the cap
is there for the run that was meant to be one bird.

The request is deterministic as far as the API allows — `speakingRate` 1.0,
spelled out rather than defaulted. There is no seed, so two renders of one
sentence may differ slightly. Re-render one clip rather than a pack. `pitch` is
deliberately not sent: Chirp 3 HD documents no such field, and 0 would mean
"unchanged" in any case.

### The audio

`LINEAR16` at 24 kHz, which is what Chirp 3 HD reports as its natural rate. It
arrives base64-encoded as a whole WAV; the tool unwraps it, and from there a
rendered clip goes through exactly the same trim, normalisation and AAC
encoding as an imported take.

**Listen to every clip before you commit it**, exactly as with a take. A
synthetic voice mispronounces bird names — `pronunciation` in the pack manifest
is how that is fixed, and the tool speaks it where it is set.

## The licence line

A recording made for this project is published under **CC BY 4.0**, like the
photos and the calls, and `--attribution` is how the credits screen names the
voice. On a render the adapter names it instead of `--attribution` — „Stimme:
<name> (Google Cloud Text-to-Speech)" — under the same licence. The gate accepts
CC0, CC BY and CC BY-SA and nothing else — a voice that cannot be published
under one of them cannot ship.
