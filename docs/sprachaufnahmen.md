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
- **a pack's species sentence** — the bare name „Amsel", one clip per
  species. It is recorded once and heard in three places: the album says it
  when a sticker is tapped, game 1 asks with it (#220), and the round end says
  it right after „Super gemacht!" when a sticker was just earned (#264). That
  praise is two clips played one after the other, never one recording per
  bird.

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

The other way to produce a clip is to render it, and **ElevenLabs is the
renderer this project uses** (Christian, 2026-10-20, issue #221). Two things
decided it, and both were heard rather than read:

- **German pronunciation.** Since #265 most of what the app says is a bare bird
  name, one word with no sentence around it. `eleven_multilingual_v2` guesses
  the language from the text, and one word is too little: it said „Amsel" and
  „Zilpzalp" in English. `eleven_v3` with `language_code` `de` says them in
  German. `multilingual_v2` refuses `language_code` outright, so the model and
  the field come together.
- **The voice.** Ava — library voice `AnvlJBAqSLDzEevYr9Ap`, German, listed as
  "Youthful, Authentic and Friendly" — is the one Christian chose after a
  probe. The account is on the paid Starter tier (40,000 characters a month,
  commercial use); every name of all three packs plus the fixed set is about
  1,500.

### The licence

The grant is read at the source, in the EEA Terms of Service (Last Updated
9 October 2026, <https://elevenlabs.io/terms-of-use-eu>). §1(c): a paid user
*"may use the Services for commercial purposes"*, a free one only for
non-commercial ones. §4(c): *"Except as expressly set forth herein, as between
you and ElevenLabs, you retain all rights in and to your Output."* That is
ownership, not a licence to use, so publishing the clips under CC BY 4.0 is a
claim this project may make. No attribution is owed on a paid tier.

Ava is a library voice, which brings in the Voice Library Addendum (Last
Updated 6 March 2026, <https://elevenlabs.io/vla>). It asks nothing of the
person using a shared voice: by sharing it, its owner agrees that
*"ElevenLabs and all other users of the Services have discharged any
obligations present or future, to pay royalties"*, and output generated before
the end of a withdrawn voice's notice period *"will continue to exist and
remain available for use thereafter"*. Three conditions hold, and none of them is code: the account is
**schnaq GmbH's**, the clips are rendered **while the subscription is active**,
and the Sound Effects product is never used for a shipped asset.

One thing the addendum does not cover for us: a withdrawn voice stays
renderable through its notice period only *"to users that added that User
Voice Model to their account prior to removal"*. Ava renders by id without
being added. Adding her in the dashboard keeps a later re-render possible.

### The key

`ELEVENLABS_API_KEY`, in Infisical under environment `dev`, path `/`. It
travels as the `xi-api-key` header, and the adapter removes it from every
message it prints (`fetch_media.keys`).

The key as issued has no `voices_read` permission, so `speech voices
--provider elevenlabs` is refused with a 401 that says so. That is why
`--voice` also takes the form `<id>=<name>`: the id is what speaks, the name is
what the credits say, and nothing has to be looked up. A library voice the
account has not added would not be in that listing anyway.

### Rendering

The fixed set, with every key the app speaks through `SpokenLine.fixed`:

```
infisical run --env=dev --path=/ -- mise run fetch-media speech render \
    --provider elevenlabs --voice AnvlJBAqSLDzEevYr9Ap=Ava --set fixed \
    --sentence roundEnd.title gate.spoken profile.picker.title \
    profile.create.title quiz.quit.question home.collection.title \
    home.collection.all
```

Every species' name of a pack, or one with `--species amsel`:

```
infisical run --env=dev --path=/ -- mise run fetch-media speech render \
    --provider elevenlabs --voice AnvlJBAqSLDzEevYr9Ap=Ava \
    --pack deutschland --sentence collection.name
```

Every run prints the number of characters it is about to render before it
renders them, and refuses to go over `--max-chars` (30000 by default): the
count is the price, and the cap is there for the run that was meant to be one
bird.

The voice becomes the manifest's `voice` block: „Stimme: Ava (ElevenLabs)",
CC BY 4.0, this document as the source. One manifest carries one voice, so
rendering it again with a different `--voice` is refused rather than merged — a
change of voice means re-rendering everything in that manifest (decision 7:
the app does not mix voices).

The request is as deterministic as the API allows: a fixed `seed`, stability
and similarity 0.8, style 0, speaker boost off. The seed is best effort, so two
renders of one sentence may differ — re-render one clip rather than a pack.
`speed` is not sent; v3 ignores it. The audio is `pcm_24000`, the best format
Starter serves, and from there a rendered clip goes through the same trim,
normalisation and AAC encoding as an imported take.

**Listen to every clip before you commit it**, exactly as with a take. A
synthetic voice mispronounces bird names — `pronunciation` in the pack manifest
is how that is fixed, and the tool speaks it where it is set.

## Google Cloud Text-to-Speech, not used

`speech/google.py` was the renderer from #234 until 2026-10-20 and stays in
the tree, unused. Its grant is plain — *"You can use the audio data files you
create using Cloud Text-to-Speech to power your applications […]"*
(<https://docs.cloud.google.com/text-to-speech/docs/basics>) — but no
ownership clause could be read at the source (section 2.1 of the plan), and
ElevenLabs won the listening. If it is ever needed again, it is `--provider
google` and the setup below.

### Setting the project up, once

This is Christian's, and it is done once:

1. A **Google Cloud project** for it — `zilpzalp-speech` is a good name — with
   **billing attached**. The free tier is a million characters a month for
   Chirp 3 HD, but no project renders anything without a billing account.
2. Enable **`texttospeech.googleapis.com`** (Cloud Text-to-Speech API) in that
   project. This is the single commonest first-day failure, and it comes back
   as a 403 that names the API.
3. A **service account** in the same project — `zilpzalp-speech-render` — with
   the narrowest role the picker offers for Text-to-Speech — **Cloud
   Text-to-Speech User**, `roles/cloudtts.user` as this was written. Take the
   name from the picker rather than from here; a wrong role shows up as a 403
   at the first render and nowhere earlier. If the picker offers nothing for
   Text-to-Speech at all, the API is not enabled yet (step 2). Nothing here
   needs Editor or Owner.
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

## The licence line

A recording made for this project is published under **CC BY 4.0**, like the
photos and the calls, and `--attribution` is how the credits screen names the
voice. On a render the adapter names it instead of `--attribution` — „Stimme:
Ava (ElevenLabs)" — under the same licence. The gate accepts
CC0, CC BY and CC BY-SA and nothing else — a voice that cannot be published
under one of them cannot ship.
