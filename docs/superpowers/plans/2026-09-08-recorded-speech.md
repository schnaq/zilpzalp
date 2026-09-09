# Plan: recorded speech instead of on-device TTS

Status: proposed 2026-09-08, night session. Christian, after hearing the
options on #151: *"die sprachausgabe ist furchtbar"*, *"eigene stimme machen
wir vllt später mal, aber nun soll die bestmögliche Lösung her. der status quo
ist furchtbar"*.

**The decision.** Everything the app says out loud moves from
`AVSpeechSynthesizer` to pre-produced clips shipped as assets, exactly the way
the bird calls landed today in PR #147. `AVSpeechSynthesizer` stays as the
runtime fallback for anything that has no clip — that fallback is #151 step 1,
which another agent is building in parallel and which this plan does not
duplicate. Personal Voice is deferred.

This reverses the spec's *"Kein Audio-Asset, keine Lizenzfrage, keine
Netzabhängigkeit"* for speech. Section 5 of this plan drafts the replacement
paragraphs; no spec file is edited in this PR.

Two words are used throughout and never interchangeably:

- **Source fallback** — what produces a clip that nobody has recorded yet
  (a TTS render standing in for a human recording).
- **Runtime fallback** — what the app says when no clip exists on the device
  (#151's best installed German voice).

---

## Decisions for Christian

Nothing below Task 2 can start before 1–3 are answered. 4–7 can be answered
while the tooling is built.

1. **Voice source.** Which of section 2's options produces the clips —
   Johanna's own voice, a paid TTS, or a free offline model. This decides the
   budget, the licence line and Johanna's evening. Recommendation and the
   licence evidence are in section 2.
2. **Budget and account.** If a paid provider wins: which account, and the API
   key into Infisical `dev` under a name like `SPEECH_API_KEY`. If Johanna
   records: a quiet room, a phone or a USB microphone, and roughly an hour.
3. **Licence line for our own voice.** The manifest's `license` field only
   accepts `CC0-1.0`, `CC-BY-4.0`, `CC-BY-SA-4.0` — the licence gate and the
   `License` enum in `ZilpZalpData` enforce it. Recordings we make ourselves
   are not third-party media, so the cleanest answer is that schnaq releases
   them under `CC-BY-4.0` (or `CC0-1.0`) and everything downstream — gate,
   credits, enum — stays untouched. The alternative, a fourth "proprietary"
   licence value, touches the hard rule in `AGENTS.md`, the enum, the gate and
   `docs/medien-und-lizenzen.md`. **Proposal: `CC-BY-4.0`, attribution
   "Stimme: <name>".** This works as written for Johanna and for ElevenLabs,
   whose terms hand us the output in writing. For Google and Azure the
   ownership clause could not be read at the source (2.1), so either somebody
   verifies it or the fourth licence value becomes necessary after all.
4. **The one spoken number.** "Heute hast du 7 Sterne gesammelt" on the
   "Zeit fürs Nest" screen is the only sentence in the app that speaks a
   number. Three ways out, in section 1.3. **This is not a free choice:** the
   spec decided in #36 that this sentence is spoken *because* „ein Kind, das
   nicht liest, ihn sonst gar nicht bekäme". Rephrasing it away means the
   child sees the day's count in a badge and never hears it. **Proposal:
   rephrase anyway** — the badge already shows it, and it saves recording 0…N
   variants of a sentence a child hears once a day.
5. **Fixed sentences: once, or per pack.** "Super gemacht!", the eight rank
   sentences, the two profile questions, the parental-gate hint — these do not
   belong to any pack. **Proposal: record them once, ship them in
   `ZilpZalpData`, never per pack.** A downloaded pack then carries only its
   own species sentences.
6. **What happens to a species without clips.** A pack whose speech was never
   recorded still has to be playable. **Proposal: per sentence, not per pack —
   a missing clip falls back to the synthesiser silently, and nothing in the
   UI mentions it.**
7. **Johanna's voice yes/no even if a TTS wins.** The two are not exclusive:
   a TTS can fill the 180 Deutschland clips while Johanna speaks the 14 fixed
   sentences a child hears every single round. Mixing voices across screens is
   a product judgment, not a technical one. **Proposal: one voice everywhere;
   mixed only as a deliberate interim.**

---

## 1. What the app speaks today

Eight call sites, no more. `grep -rn "readAloudOnce\|announce(" apps/` finds
all of them; everything routes through `SpeechAnnouncer`
(`apps/ZilpZalp/Sources/Audio/SpeechAnnouncer.swift`) and its `ReadAloudOnce`
view modifier.

### 1.1 The table

| Key | German text | Spoken where | Kind | Placeholders | Per round |
|---|---|---|---|---|---|
| `quiz.prompt.whereIs` | „Wo ist %1$@ %2$@?" | `QuizSession.askQuestion` → `announce(_ bird:)` | **per species** | article + name (`pronunciation` override) | 10× plus every tap on the repeat button |
| — (no key) | „Amsel" | `CollectionScreen` sticker tap → `announce(bird.pronunciation ?? bird.name)` | **per species** | the bare name | 0–n, child-driven |
| `roundEnd.sticker.new.spoken` | „Super gemacht! %@ gesammelt!" | `RoundEndScreen.celebrate` | **per species** | bird name | 0 or 1 |
| `roundEnd.title` | „Super gemacht!" | `RoundEndScreen.celebrate`, when the round was no first find | static | — | 0 or 1 |
| `rank.amsel.ascent` … `rank.wiedehopf.ascent` (8) | „Du bist jetzt eine Amsel!" … | `RankAscentScreen` via `readAloudOnce` | static, 8 sentences | — | rarely |
| `gate.spoken` | „Frag bitte einen Erwachsenen." | `ParentalGate` via `readAloudOnce` | static | — | outside a round |
| `profile.picker.title` | „Wer spielt heute?" | `ProfilePickerScreen` via `readAloudOnce` | static | — | before a round |
| `profile.create.title` | „Wie heißt du?" | `ProfileCreationScreen` via `readAloudOnce` | static | — | once per profile |
| `timeBudget.title` + `timeBudget.starsToday.spoken` | „Zeit fürs Nest! Heute hast du %lld Sterne gesammelt." | `TimeForTheNestScreen.spoken` via `readAloudOnce` | static + **number** | star count | once a day |
| `quiz.quit.question` (#146, in progress) | „Willst du aufhören?" | quit-confirmation card | static | — | 0–n |

Not spoken, and this plan does not change that: `roundEnd.stars`,
`collection.stars`, `collection.birds`, `rank.*.missing`, every VoiceOver
label, and **every profile name**. VoiceOver reads names through the system
voice, which is a different mechanism and out of scope.

### 1.2 How many clips

Three sentence kinds are species-dependent, so each needs one clip per species:

```
per species:  quiz.prompt.whereIs        "Wo ist die Amsel?"
              roundEnd.sticker.new.spoken "Super gemacht! Amsel gesammelt!"
              collection.name             "Amsel"
```

| Set | Species | × 3 | Fixed sentences | Total |
|---|---|---|---|---|
| Fixed set (app-level, not per pack) | — | — | 13 today + 1 from #146 = **14** | 14 |
| Base pack `basis` | 10 | 30 | — | 30 |
| **Base pack + fixed set** | | | | **44** |
| Deutschland pack (#21) | ~60 | 180 | — | 180 |
| **Both packs** | | | | **224** |

The 14 fixed sentences: `roundEnd.title`, eight `rank.*.ascent`,
`gate.spoken`, `profile.picker.title`, `profile.create.title`, the reworded
"Zeit fürs Nest" sentence (decision 4), and `quiz.quit.question` once #146 has
settled its key.

The brief's "~300 for Deutschland" is reached only if games 3 and 4 add a
fourth and fifth per-species sentence (+60 each), or if the fixed set is
re-recorded per pack (decision 5 says no). The number to budget against today
is **224**, and **44** for the first shippable step.

### 1.3 Numbers and names

- **The star count** (`timeBudget.starsToday.spoken`) is the only number the
  app speaks. Options: (a) **rephrase** so nothing numeric is spoken —
  "Zeit fürs Nest! Für heute ist Schluss." — the badge "7 Sterne heute" stays
  and is the visual answer; (b) record 0…30 variants plus a singular, which
  is 31 clips for one sentence heard once a day; (c) leave this one sentence
  on the runtime fallback, which means one screen sounds different from the
  rest of the app. **Product decision → decision 4. Proposal: (a).**
  Say the cost out loud: (a) reverses a decision the spec took deliberately.
  §4 records for screen 1k that „der ganze Satz ‚Heute hast du 7 Sterne
  gesammelt' wird stattdessen **gesprochen**, weil ein Kind, das nicht liest,
  ihn sonst gar nicht bekäme und ein Satz in einem Badge nicht umbricht"
  (#36). Under (a) the count stays visible and stops being audible, for
  exactly the child that sentence was written for. It is once a day, on the
  screen that ends the day, and the alternative is 31 clips — but it is a
  loss, not a simplification.
  A second, technical reason for (a): `TimeForTheNestScreen.spoken`
  concatenates two sentences into one string. Two recorded clips would have to
  be played in sequence, and `announce(_:)` deliberately drops whatever is
  running rather than queueing. One sentence, one clip.
- **Profile names** are spoken nowhere today. They cannot be pre-recorded —
  a child types "Mäuschen" — so the rule is: **never speak a profile name.**
  Should a future screen want to, it takes the runtime fallback and says so.
- **`pronunciation`** in the manifest stays. Once a species has a recorded
  clip the field no longer changes what is heard; it only steers the runtime
  fallback. Its doc comment says so after Task 5.

---

## 2. Where the audio comes from

Every licence claim below was read at the source on 2026-09-08, not from
memory. Where a clause could not be read at the vendor's own page, this
section says "unverified" and treats the option accordingly. **This is a
documentation review, not legal advice.**

### 2.0 The one option that is dead

**Apple's own voices rendered offline with `say -v "Anna (Premium)"` are not
usable.** macOS Tahoe 26 SLA (EA1955, 07/11/2025), §2 "Permitted License Uses
and Restrictions", subsection F:

> **F. Voices; Live Captions.** Subject to the terms and conditions of this
> License, you may: (i) use the system voices included in the Apple Software
> ("System Voices") (1) while running the Apple Software and (2) to create
> your own original content and projects for your personal, non-commercial
> use; […] **No other creation or use of the System Voices, Live Captions or
> Personal Voice is permitted by this License, including but not limited to
> the use, reproduction, display, performance, recording, publishing or
> redistribution of any of the System Voices, Live Captions or Personal Voice
> in a profit, non-profit, public sharing or commercial context.**
> — <https://www.apple.com/legal/sla/docs/macOSTahoe.pdf>

The clause names *recording*, *publishing* and *redistribution*, and it
catches non-profit and public sharing too, so a free app would not escape it.
The identical wording is in the macOS Sequoia SLA and, in a shorter form, in
OS X El Capitan's — it has stood for a decade. The same subsection, limb
(iii), kills Personal Voice as a build-time asset for the same reason.

What *is* permitted is limb (1), "while running the Apple Software" — the
device speaking live. That is exactly what #151 does, and it is why the
runtime fallback stays legal while the render path is not. The iOS SLA has no
"System Voices" clause at all; the Apple Developer Program Licence Agreement
and the Xcode SDK agreement say nothing about voices either (checked by grep
over both full texts). Nothing rescues the render path.

### 2.1 The options that work

| Source | German quality | ~44 clips | ~224 clips | May we ship it | Attribution / disclosure | Re-render one clip |
|---|---|---|---|---|---|---|
| **Johanna (human)** | the best there is for a child | her time | her time | yes, it is ours | none owed; credit her by choice | she says it again |
| **Google Cloud TTS** (Chirp 3 HD, 30 de-DE voices) | native German, current top tier | **$0** | **$0** | yes, affirmative grant quoted below | none found | one API call, not byte-identical |
| **Azure Neural TTS** (17+ de-DE, incl. a child voice) | best inventory; `de-DE-GiselaNeural` is an actual child voice | **$0** (0.5M chars/month free) | **$0** | yes, but grant unverified | **disclosure required**, parent-facing | one API call |
| **ElevenLabs** (`eleven_multilingual_v2`) | German listed; no German-specific claim published | $6 (Starter) | $6–22 | yes, on any paid tier | none on paid tiers | `seed` is best-effort only |
| **Coqui VITS `tts_models/de/thorsten/vits`** | VITS-class, one voice | €0, offline | €0, offline | yes, Apache-2.0 weights on CC0 data | „Stimme: Thorsten Müller" — recommended, see 2.1 | deterministic, local |
| **OpenAI** `gpt-4o-mini-tts` | *"Voices are currently optimized for English"* | ~$0.15 | ~$1 | ownership clause **unverified** | **disclosure required** | no `seed` at all |

Character basis: a short German sentence is 45–60 characters; 224 clips with a
3× retake factor is well under 60k characters, which is inside Google's and
Azure's monthly free tiers. **Cost is not a decision factor here.** Quality,
licence clarity and who has to be in the room are.

**Google Cloud Text-to-Speech** — the only vendor with a plain affirmative
grant, read at the vendor's own page:

> "You can use the audio data files you create using Cloud Text-to-Speech to
> power your applications or augment media like videos or audio recordings (in
> compliance with the Google Cloud Platform Terms of Service including
> compliance with all applicable law)."
> — <https://docs.cloud.google.com/text-to-speech/docs/basics>

The Generative AI Prohibited Use Policy (effective 2024-12-17) forbids only
*"Misrepresenting the provenance of generated content by claiming it was
created solely by a human, in order to deceive"* — a negative duty we satisfy
by simply not claiming a human spoke. No attribution, no disclosure. Free
tier: 1M characters a month for Chirp 3 HD, 4M for Standard.
**Unverified:** Text-to-Speech has no service-specific terms section in
`cloud.google.com/terms/service-terms`, and §5.1 of the GCP ToS could not be
read in full. No prohibition was found; none was read either.

**Azure AI Speech** has the best German inventory of the three — native
talent, and `de-DE-GiselaNeural` is a documented child voice, which for this
audience is not nothing. It costs a condition:

> "Microsoft requires its customers to disclose the synthetic nature of text
> to speech voices to its users."
> — <https://learn.microsoft.com/en-us/azure/ai-foundry/responsible-ai/speech-service/text-to-speech/transparency-note>

and, specifically for us:

> "Consider proper disclosure to parents or other parties with use cases that
> are designed for or may be used in situations involving minors and children.
> If your use case is intended for minors or children, you'll need to ensure
> that your disclosure is clear and transparent so that parents or legal
> guardians can understand the role of synthetic media […]"

That is cheap for this app — one generated line on the credits screen, which
already sits behind a parental gate, and Microsoft's own recommended pattern
is exactly a gated parent-facing disclosure. **Unverified:** the affirmative
redistribution grant in the Microsoft Product Terms sits behind a
JS-rendered fwlink and could not be read. No prohibition was found.

**ElevenLabs** grants commercial use from the $6 Starter tier upward; the
free tier does not. EEA Terms of Service (Last Updated 31 March 2026), §1(c):

> "(i) if you access or use our Services free of charge […] you may only use
> the Services for non-commercial purposes; (ii) if you access or use our
> Services through a paid subscription plan (such a user, a "Paid User"), you
> may use the Services for commercial purposes […]"

and §4(c)(ii): *"Except as expressly set forth herein, as between you and
ElevenLabs, you retain all rights in and to your Output."* No attribution on
paid tiers — the "elevenlabs.io in the title" rule is free-tier only. Three
conditions if this wins: the account must be **schnaq GmbH's**, the clips must
be rendered **while the subscription is active** (content generated before or
after a paid period is explicitly not commercial), and the **Sound Effects
product must never be used** for a shipped asset — its Prohibited Use Policy
§9(c) forbids exactly the "isolated files" pattern this plan is built on. TTS
output is unaffected by §9(c).

**OpenAI is the weakest fit** and this plan does not recommend it: the docs
say *"Voices are currently optimized for English"*, the guide states *"Our
usage policies require you to provide a clear disclosure to end users that the
TTS voice they are hearing is AI-generated and not a human voice"* — an
end-user, not parent-facing, disclosure to a five-year-old — there is no
`seed` parameter, and the Output-ownership clause could not be read
(openai.com answers automated fetches with HTTP 403).

**Free and offline: Thorsten, but not through Piper.** The obvious candidate
has a lineage problem. The Thorsten *dataset* is genuinely CC0 and its speaker
is its own licensor — *"The speaker explicitly releases the voice recordings
and the underlying voice under CC0"* — but the rhasspy Piper Thorsten weights
are finetuned from English voices whose training data is not commercial:
`de_DE-thorsten-medium`'s MODEL_CARD says *"Finetuned from U.S. English lessac
voice (medium quality)"*, and the Blizzard 2013 Lessac licence excludes *"…
otherwise using the Materials for any commercial purpose, including the
development, marketing, commercialisation, sale or licencing of voice
synthesis or speech recognition products or services"*. The `low` voice
descends from RyanSpeech, `CC BY-NC-SA 4.0`. Whether a finetune inherits that
is unsettled, and unsettled is not what this project ships.

The clean free option is **`tts_models/de/thorsten/vits` through Coqui**
(`idiap/coqui-ai-TTS`, runtime MPL-2.0): weights declared `"license": "apache
2.0"` in `.models.json`, Thorsten's own model card `apache-2.0`, trained on
his CC0 data, no Blizzard or RyanSpeech ancestor. `Thorsten-Voice/Kokoro`
(Apache-2.0, German finetune of Kokoro-82M) is the second free option — note
that base Kokoro-82M itself has **no German**. Credit Thorsten Müller if
either is picked: the dataset cards say CC0, but both Zenodo records
(5525342, 7265581) carry a formal licence field of CC BY 4.0. An attribution
line costs nothing and satisfies the stricter reading.

Excluded, with the reason: **Coqui XTTS-v2** — the Coqui Public Model Licence
permits use *"for any non-commercial purpose"*, *"only so far as you do not
receive any direct or indirect payment arising from the use"*. **F5-TTS** —
*"The pre-trained models are licensed under the CC-BY-NC license due to the
training data Emilia"* (the MIT applies to the code only). **Fish-Speech /
OpenAudio** — *"Any use of the Fish Audio Materials or Derivative Works for a
Commercial Purpose requires a separate written license agreement from Fish
Audio."* **facebook/mms-tts-deu** — `cc-by-nc-4.0`. **Chatterbox** is MIT and
speaks German but stamps every output with Resemble AI's Perth neural
watermark, which is a vendor fingerprint inside audio we would ship; not
worth it when free alternatives exist.

### 2.2 Johanna

Zero licence questions — the recording is ours, which is the only option that
resolves decision 3 without touching the licence enum, the gate or the hard
rule in `AGENTS.md`. It is also the only one that sounds like a person a child
knows rather than like a very good machine, which for an app whose whole
premise is a grown-up reading to a child who cannot read is the point rather
than a nicety.

What it needs: a quiet room, a phone or a USB microphone, and the
`speech import` path from Task 3 (WAV in, normalised `.m4a` out). Estimate,
at three takes per sentence and a pause to breathe: **44 clips ≈ 30–45
minutes** for the fixed set and the base pack, plus the import run;
**180 clips ≈ 2–3 hours** for the Deutschland pack, which is an afternoon and
should not be booked before the base pack has been heard in TestFlight.

The cost is not the recording, it is the *re-recording*: a sentence that
changes wording, or a species added to a pack, needs her again. A TTS
re-renders in a second. That is the whole trade.

### 2.3 Recommendation

**Primary: Johanna.** Best for the audience, unambiguously ours, no vendor
terms, no disclosure duty, and it keeps the manifest inside the three CC
licences the project already enforces. 44 clips is one evening.

**Fallback: Google Cloud TTS, Chirp 3 HD, a German voice.** The only vendor
with an affirmative grant that could be read at the source
(<https://docs.cloud.google.com/text-to-speech/docs/basics>), no attribution,
no disclosure, free at our volume, 30 de-DE voices to choose from. If
Johanna's time is not available, or when the Deutschland pack's 180 clips are
due, this renders them — and then the **whole** app switches to that voice
rather than mixing (decision 7).

**Second fallback, if Christian prefers a designed synthetic voice over a
free one: ElevenLabs Starter, $6.** Cleanest paid grant, explicit ownership of
output, no attribution. Worth an A/B against Google before paying.

**Before deciding, listen.** The ranking between a human, Google and
ElevenLabs cannot be settled from licence texts. One sentence — "Wo ist die
Amsel?" — rendered by each, played on a phone speaker, decides it in two
minutes. A free offline baseline is already rendered and its path is in the PR
body — Piper with `de_DE-thorsten-medium`, **as a reference for how good free
sounds, not as a shipping path**, for the lineage reason in 2.1.

**What Christian must provide** if a vendor wins: for Google, a Cloud project
and a service-account key in Infisical `dev` (`GOOGLE_TTS_*`), billing
enabled even though the volume is free; for ElevenLabs, a subscription on a
**schnaq GmbH** account and `ELEVENLABS_API_KEY` in the same place. For
Johanna: an hour and a quiet room. In every case the key never enters the
repository and never enters a log — see 3.5.

**One consequence that outlives the choice:** a vendor's TTS output arrives
under a contract, not under a CC licence, and the manifest has no field for
"under contract". The way out is ownership — whoever owns the clip may release
it under `CC-BY-4.0`, which is decision 3's proposal — but only two of the
three vendors were shown to grant it. ElevenLabs does, in writing: *"you
retain all rights in and to your Output"* (§4(c)(ii)). Google's page grants
**use** — *"You can use the audio data files you create … to power your
applications"* — which is not the same thing, and GCP ToS §5.1 could not be
read; Azure's affirmative grant could not be read either. So: releasing a
Google or Azure render under CC would be a claim about rights nobody in this
project has verified. Johanna's voice avoids the question entirely, because
the clip is ours from the start.

---

## 3. Data model and tooling

### 3.1 Where the clips live

Two places, because the clips fall into two groups with different owners:

```
data/packs/<pack>/speech/<sentenceKey>/<birdID>.m4a   species sentences, per pack
data/speech/<sentenceKey>.m4a                         fixed sentences, app-level
```

The fixed set gets **its own manifest outside `data/packs/`**. That is not
taste: `tools/license_gate.py` does `rglob("*.json")` over `data/packs/` and
fails every document that has no `birds` list. A fixed-sentence manifest below
that directory would fail the gate on its first run. So:

```
data/speech/manifest.json          the fixed sentences and their voice
```

and `tools/sync_bundled_packs.py` copies `data/speech/` into
`packages/ZilpZalpData/Sources/ZilpZalpData/Resources/Speech/`, with a
matching `.copy("Resources/Speech")` in `Package.swift`, exactly the way the
base pack is copied today. The same drift check then covers both.

### 3.2 The JSON

**One voice block per manifest, not per clip.** Thirty clips of one voice do
not want thirty identical attribution strings — the credits screen would list
the same line thirty times, and the diff of a re-render would be noise. The
licence lives once, at the top:

```json
{
  "id": "basis",
  "title": "Unsere ersten Vögel",
  "voice": {
    "name": "Johanna",
    "license": "CC-BY-4.0",
    "attribution": "Stimme: Johanna …",
    "sourceURL": "https://…/zilpzalp/blob/main/docs/sprachaufnahmen.md",
    "retrieved": "2026-09-12"
  },
  "birds": [
    {
      "id": "amsel",
      "…": "…",
      "speech": {
        "quiz.prompt.whereIs": {
          "file": "speech/quiz.prompt.whereIs/amsel.m4a",
          "sha256": "…",
          "text": "Wo ist die Amsel?"
        },
        "roundEnd.sticker.new.spoken": { "…": "…" },
        "collection.name": { "…": "…" }
      }
    }
  ]
}
```

`data/speech/manifest.json` is the same shape without birds:

```json
{
  "id": "speech",
  "voice": { "…": "…" },
  "lines": {
    "roundEnd.title": {
      "file": "roundEnd.title.m4a",
      "sha256": "…",
      "text": "Super gemacht!"
    }
  }
}
```

Three fields per clip and no more. `sourceURL` and `retrieved` belong to the
voice, not to the sentence; `license` and `attribution` likewise.

**`text` is load-bearing.** It records what was actually said when the clip was
produced. A test compares it against the String Catalog's German value, so a
sentence edited in Xcode without a re-render fails `mise run check` instead of
shipping a clip that says something else than the screen shows. It is also
what a re-render reads, so nobody retypes a sentence by hand.

Sentence keys are the String Catalog keys, verbatim, with one invention:
`collection.name` for the bare species name, which has no key today because
`CollectionScreen` speaks `bird.name` directly. Task 5 adds the key.

### 3.3 The licence gate

`tools/license_gate.py` learns three things:

- A manifest that carries `speech` (or `lines`) must carry `voice`. The voice
  is checked exactly as a medium is today: `license` inside
  `ALLOWED_LICENCES`, `attribution` non-empty, `sourceURL` non-empty.
- Each clip needs `file`, `sha256` and `text`; the hash is verified where the
  file is on disk and skipped where it only lives in the bucket — the rule
  photos and calls already follow.
- A second entry point for `data/speech/manifest.json`, whose top level has
  `lines` instead of `birds`. `mise run license-gate` runs both directories.

Everything else stays: only CC0, CC BY and CC BY-SA, no NC, no ND.

### 3.4 Credits

`tools/generate_credits.py` and `Credits` in `ZilpZalpData` gain a **voices**
section, not a `Kind.speech`. One row per distinct voice per pack plus the
app-level one:

```
Stimmen
Johanna · CC BY · Unsere ersten Vögel, Ansagen
```

modelled on the existing `fonts` and `icons` lists, which already are "one
credit for many files". `CREDITS.md` gets the same section. Per-clip rows
would be 224 lines of the same name.

### 3.5 `fetch-media speech`

Two new commands under one noun, next to `photos` and `calls`:

```
fetch-media speech render --pack basis [--species amsel …] [--sentence quiz.prompt.whereIs]
fetch-media speech render --fixed [--sentence roundEnd.title]
fetch-media speech import --pack basis --species amsel --sentence quiz.prompt.whereIs --file take3.wav
fetch-media speech import --fixed --sentence roundEnd.title --file take1.wav
```

- **`render`** builds the sentence from the String Catalog and the manifest
  (article, name, `pronunciation` where set), asks the provider, and records
  the result. Idempotent per clip, so re-rendering one sentence for one
  species is one command — which is the answer to "the Amsel sounds wrong".
- **`import`** is Johanna's path: WAV in, normalised `.m4a` out, the same
  encode a call gets. No provider, no key, no network.
- Both go through the existing `record_medium` machinery — file beside the
  manifest, SHA-256, manifest write, `regenerate_derived()` — extended with a
  `set_speech(document, bird_id, sentence_key, block)` beside
  `manifest.set_media`, because `set_media` rejects any kind outside
  `MEDIA_KINDS` and speech nests one level deeper (kind → sentence → bird).
- `manifest.media_files()` must list the speech clips too. That one function
  is what makes `fetch-media upload` put them in the bucket and what
  `PackDownloader` later reads; forget it and downloaded packs are silent.

**Provider adapters.** One small interface — `synthesize(text: str) -> bytes`
— and one adapter per provider under `tools/fetch_media/speech/`. The core
knows no vendor. A `--provider fake` adapter that returns a generated tone is
what the unit tests use; **no test ever talks to a vendor**, the rule
`tools/tests/` already follows for iNaturalist and xeno-canto.

**Encoding and loudness.** Shared with the calls: mono AAC-LC `.m4a` through
`afconvert`, no ffmpeg, no Homebrew. `tools/fetch_media/audio.py` grows one
`normalise(samples, rate)` helper that `trim()` and the speech path both call,
against the same target. That **is** issue #148 — speech and calls have to sit
at one loudness or a child hears one of them as "too quiet" — so the two are
one piece of work and #148 is closed by Task 3 rather than done twice. Speech
needs no six-second window and no fade-in; it needs leading and trailing
silence trimmed, which the same module can do.

**Secrets.** A provider key comes from the environment where
`infisical run --env=dev --path=/ --` puts it, exactly like
`XENO_CANTO_API_KEY` (`tools/fetch_media/xenocanto.py::api_key`). Never in the
repository, never in a fixture, never in a test. `cli.main` currently redacts
only the xeno-canto key through `xenocanto.redact`; that function moves to a
shared place and learns the new name, or one failed request prints a key into
a CI log.

### 3.6 What the tool does not do

Listening. `fetch-media speech render` prints "Listen to the file before you
commit it" the way `calls pick` does, and a human decides. A tool that
measures whether a sentence sounds friendly does not exist.

---

## 4. Runtime

### 4.1 The shape of a spoken line

`SpeechAnnouncer.announce(_ sentence: String)` cannot look a clip up: a string
is not a key. One small value type carries what both layers need, in the app
target because the String Catalog lives there:

```swift
/// One thing the app says: which sentence, about which bird, and the words
/// for the runtime fallback when no clip is on the device.
struct SpokenLine: Sendable, Hashable {
    /// The String Catalog key, and the key under `speech` in the manifest.
    let key: String
    /// `nil` for a sentence that belongs to no species.
    let bird: Bird?
    /// What the synthesiser says when there is no clip.
    let text: String

    static func whereIs(_ bird: Bird) -> SpokenLine
    static func firstFind(_ bird: Bird) -> SpokenLine
    static func name(_ bird: Bird) -> SpokenLine
    static func fixed(_ key: String) -> SpokenLine
}
```

The API the screens use keeps its names: `announce(_ line: SpokenLine)`,
`stop()`, `readAloudOnce(_ line: SpokenLine)`. Every call site changes by one
expression — `readAloudOnce(String(localized: "gate.spoken"))` becomes
`readAloudOnce(.fixed("gate.spoken"))`.

### 4.2 `SpeechAnnouncer`

```
announce(line):
    guard no call is playing                 (unchanged, AudioFocus)
    if let clip = catalog.speechURL(for:sentence:) ?? speech.url(for: line.key)
        play the clip                        (AVAudioPlayer, CallPlayer's pattern)
    else
        speak line.text                      (#151's chosen voice)
```

`AudioFocus` needs **no change at all**. `CallPlayer.play(_:)` already calls
`AudioFocus.speech?.stop()`, and `announce` already refuses while a call is
audible; `stop()` simply stops both the synthesiser and the clip player, so
the quit card (#146), the round end and every `readAloudOnce` screen keep
working unchanged. The player inside `SpeechAnnouncer` copies `CallPlayer`'s
identity check on `AVAudioPlayer`: the outgoing player is silenced but held
alive until the replacement exists, so a late `didFinishPlaying` cannot switch
off the clip that just started. Roughly forty lines, and the reason it is a
copy rather than a shared type is that `CallPlayer.isPlaying` exists to draw
`SoundButton`'s rings and the speech has no button.

`AudioSessionConfigurator.activatePlayback()` runs before a clip exactly as
before an utterance, and only once there is something to play.

### 4.3 `ZilpZalpData`

```swift
public extension PackCatalog {
    /// The recorded clip for `sentence` about `bird`, `nil` when the pack
    /// declares none or the file is not on disk. The twin of `callURL(for:)`.
    func speechURL(for bird: Bird, sentence: String) -> URL?
}

/// The fixed sentences that belong to no pack, from `Bundle.module`.
public struct SpeechCatalog: Sendable {
    public static func bundled() throws -> SpeechCatalog
    public func url(for sentence: String) -> URL?
}
```

`Bird` gains `public let speech: [String: MediaClip]?`, decoded from the
manifest — a dictionary rather than an enum of known keys, so a pack may ship
a sentence an older installed app does not know without failing to decode.
`MediaClip` is the three-field clip type; `MediaAsset` keeps its six fields
and is not touched. The voice block decodes into `Pack.voice` and
`SpeechManifest.voice`, which is what the credits generator reads.

`PackDownloader` carries the clips because `assets(of:)` collects them — it
walks the manifest, and the manifest is where they are declared. Same SHA-256
per file, same partial directory, same publish step; nothing else in that
actor changes.

### 4.4 Tests

- `PackCatalogTests.resolvesEverySpeechClip` — for every bird and every
  declared sentence the file exists and hashes to its `sha256`. Modelled on
  `resolvesEveryCall`.
- `SpeechCatalogTests` — the same for the fixed set.
- `speechTextMatchesTheCatalog` — every clip's `text` equals the German value
  of its key in `Localizable.xcstrings`, with the placeholders filled from the
  bird, so an edited sentence cannot ship with a stale clip.
- `PackDownloaderTests` — a stub pack with one speech clip arrives and
  verifies, against the local HTTP server that test already runs.
- Tool side: `tools/tests/test_fetch_media_speech.py` against the fake
  provider, plus the gate and credits tests extended with a speech fixture.

---

## 5. Spec change

Not in this PR. The implementation PRs carry it; this is the wording they use.

**Today, §4 (line 173):**

> **Sprachausgabe:** `AVSpeechSynthesizer` mit `de-DE` direkt auf dem Gerät.
> Kein Audio-Asset, keine Lizenzfrage, keine Netzabhängigkeit. Der
> Klickprototyp macht es mit der Web Speech API bereits genauso. Die
> Sprachausgabe lässt sich in v1 nicht abschalten […]

**Replacement for the first three sentences; the rest of the paragraph stays
as it is:**

> **Sprachausgabe:** Alles, was die App spricht, liegt als vorproduzierte
> Aufnahme im Paket oder in `ZilpZalpData` — dieselbe Pipeline wie die
> Vogelrufe, dieselbe Lizenzprüfung, dieselbe SHA-256-Absicherung. Gesprochen
> wird zur Kurationszeit, nie zur Laufzeit: die App spricht mit keinem
> Sprachdienst. Fehlt für einen Satz eine Aufnahme, fällt die App auf
> `AVSpeechSynthesizer` mit der besten installierten deutschen Stimme zurück
> (Issue #151) — hörbar schlechter, aber nie stumm. Grund für den Wechsel: für
> ein Kind, das noch nicht liest und die Frage nur hört, ist die Systemstimme
> zu schlecht (Entscheidung 2026-09-08, Christian).

**§4, Schritt 2 der Runde (line 163):** replace „per `AVSpeechSynthesizer` vor"
with „als Aufnahme vor (mit `AVSpeechSynthesizer` als Rückfallebene, Issue
#151)".

**§3 Datenmodell (line 108):** the comment on `pronunciation` becomes
„Lautschrift-Override für die Rückfallebene `AVSpeechSynthesizer`; wo eine
Aufnahme existiert, wird sie gespielt".

**§3 Medien-Pipeline:** one sentence — „Neben Fotos und Rufen führt jedes Paket
die gesprochenen Sätze seiner Arten; die paketunabhängigen Ansagen liegen
unter `data/speech/` und werden wie das Basis-Paket in `ZilpZalpData`
gebündelt."

**§5 Datenhaltung:** the `Packs/<pack-id>/` line gains „(Fotos, Rufe und
Sprachaufnahmen)".

**§4, „Zeit fürs Nest" (screen 1k) — only if decision 4 goes to (a).** The
sentence „der ganze Satz ‚Heute hast du 7 Sterne gesammelt' wird stattdessen
**gesprochen**, weil ein Kind, das nicht liest, ihn sonst gar nicht bekäme und
ein Satz in einem Badge nicht umbricht" is a decision from #36 and would be
reversed, not merely reworded. It becomes: „Der Tagesertrag steht als Badge wie
im Design („7 Sterne heute"). Gesprochen wird er seit dem Wechsel auf
Sprachaufnahmen nicht mehr: eine Zahl lässt sich nicht sinnvoll vorproduzieren,
und 31 Aufnahmen für einen Satz, den ein Kind einmal am Tag hört, stehen in
keinem Verhältnis (Entscheidung 2026-09-08)." If decision 4 goes to (b) or (c)
instead, this paragraph stays as it is.

**§10 Offene Punkte, new item:**

> **Stimme der Sprachausgabe (Entscheidung 2026-09-08).** Die Sprachausgabe
> wechselt von `AVSpeechSynthesizer` auf vorproduzierte Aufnahmen. Welche
> Quelle die Aufnahmen produziert und ob die Sätze eines Pakets in derselben
> Stimme gesprochen sind wie die festen Ansagen, entscheiden Christian und
> Johanna. Offen ist außerdem, ob das Deutschland-Paket (#21) mit rund 180
> Sätzen dieselbe Behandlung bekommt wie das Basis-Paket.

`docs/medien-und-lizenzen.md` gets a „Sprachaufnahmen" section in the same
task: where the clips come from, what the voice block declares, and under
which licence our own recordings are released once decision 3 is settled.

---

## 6. Tasks

One issue, one worktree, one branch, one PR against `main`, in this order.
"Blocked" names the decision from the list at the top that has to be answered
first.

### Task 1 — Answer decisions 1–3 (Christian, no PR)

The voice source, the budget or the recording session, and the licence line.
Everything below waits on this in the sense that the fixture licence and the
first provider adapter are written from it — but Task 2 can be started against
the proposals and adjusted, so it need not idle.

### Task 2 — `speech` in the schema, the gate, the credits, the sync

**Branch:** `feat/speech-schema`. **Blocked on:** decision 3 (licence value),
decision 5 (fixed sentences once vs. per pack — decides whether
`data/speech/` exists at all).

`tools/license_gate.py`, `tools/generate_credits.py`,
`tools/sync_bundled_packs.py`, `tools/fetch_media/manifest.py`,
`packages/ZilpZalpData/Sources/ZilpZalpData/{PackSchema,Credits,PackCatalog}.swift`,
a new `SpeechCatalog.swift`, `Package.swift`, plus fixtures and tests on both
sides. **No audio and no app-target change** — this task makes the shape
legal, nothing more.

*Acceptance:* a fixture manifest with a `voice` block and one speech clip
passes the gate; a fixture with `speech` but no `voice` fails it, naming the
manifest; the credits list the voice once per pack; `sync_bundled_packs.py`
reports drift for `data/speech/` the way it does for `basis`;
`PackCatalog.speechURL(for:sentence:)` and `SpeechCatalog.bundled()` resolve
against a fixture; `mise run check` green.

### Task 3 — `fetch-media speech render | import`, and loudness (#148)

**Branch:** `feat/fetch-media-speech`. **Carries Task 2. Blocked on:**
decisions 1 and 2 (which adapter is written first, and whether a key is
needed at all).

`tools/fetch_media/speech/` with the provider interface, the `fake` adapter
and the one chosen adapter; `cli.py` gains the `speech` subcommand;
`audio.py` gains `normalise` and a silence trim, and `trim()` starts using it
— which closes #148. The shared `redact` learns the new key name.

*Acceptance:* `speech render --pack basis --species amsel --provider fake`
writes the file, the manifest entry and regenerates the derived files;
`speech import --file take.wav` produces a clip at the same loudness as a
call; re-running either command for one species changes exactly one clip and
one manifest entry; the ten existing calls, re-run through `calls pick`, land
within 3 dB of each other; no test reaches a vendor; `mise run check` green.

### Task 4 — Produce the fixed set and the base pack (curation)

**Branch:** `feat/speech-basis`. **Carries Task 3. Blocked on:** decisions 1,
4, 5, 7.

The 14 fixed sentences and the 30 base-pack clips, produced and **listened
to** — the same rule the calls follow. Around 20 KB per clip, so roughly
900 KB of audio in the repository and the same again in the bundled copy.
This is the task that either books Johanna's evening or spends the API budget.

*Acceptance:* every clip in the manifest, every hash verified by the gate, the
credits naming the voice once, and a human confirming that each sentence is
intelligible on a phone speaker at arm's length. Nothing is committed that
nobody has heard.

### Task 5 — Clip first, synthesiser second

**Branch:** `feat/spoken-lines`. **Carries Task 2; rebases on #151** — same
file, and #151's voice chooser becomes the fallback branch. Merge order:
#151 first.

`SpokenLine`, `SpeechAnnouncer` playing clips through `AVAudioPlayer` with the
synthesiser behind it, all eight call sites moved over, `ReadAloudOnce` taking
a line. Adds the `collection.name` key and — if decision 4 says so — replaces
the composite "Zeit fürs Nest" sentence with one that speaks no number.

*Acceptance:* with clips present the app plays them and the synthesiser is
never reached; with `data/speech/` emptied the app still speaks every sentence
through #151's voice; a call and a sentence never overlap (the `AudioFocus`
rules are unchanged and re-verified by hand); the quit card (#146), the round
end, the rank ascent, both profile screens and the gate all still speak;
verified in the simulator **and** on a device.

### Task 6 — Downloaded packs carry their speech

**Branch:** `feat/speech-download`. **Carries Tasks 2 and 3.**

`fetch-media upload` puts the clips in the bucket because
`manifest.media_files()` lists them; `PackDownloader.assets(of:)` collects
them so the download verifies and installs them; `packs/index.json` reports
the larger size. A downloaded pack speaks in the same voice as the bundled
one.

*Acceptance:* `upload --dry-run` lists the speech clips; the downloader test
installs a stub pack with one clip and rejects a wrong hash; the index size
changes with the clips.

### Task 7 — Spec, `docs/medien-und-lizenzen.md`, `AGENTS.md`

**Branch:** `docs/speech-assets`. **Carries Task 5.**

The five spec edits from section 5, a „Sprachaufnahmen" section in
`docs/medien-und-lizenzen.md`, and the one line in `AGENTS.md` that today
implies only photos and calls are licensed media.

### Task 8 — The Deutschland pack's 180 clips

**Branch:** `feat/speech-deutschland`. **Blocked on** #21 (the species list is
Christian's and Johanna's) **and** on Task 4 having proven the pipeline.

Not started before the base pack has been heard in a TestFlight build.

### Not in this plan

- **Personal Voice** — deferred on Christian's word, and it is a different
  shape: a per-device permission and a synthesiser, not an asset.
- **A voice switch in the parents area.** Nothing the app makes audible is a
  setting any more (#138), and a second voice would be a second production.
- **Speech for games 3 and 4.** They have no screens yet. Each per-species
  sentence they add costs one clip per species per pack — worth knowing before
  a sentence is invented.

---

## Working mode

As the earlier plans: worktree per task, draft PR early, `mise run check` seen
green before "done", `/simplify`, a Sonnet review, `gh pr ready`, no
self-merge, English in the repository and German in the product.

Two rules specific to this plan:

- **Nothing audible is committed unheard.** Same rule the calls got in #147,
  and the reason the plan has a curation task of its own rather than folding
  the recording into the tooling PR.
- **The synthesiser never goes away.** Every task keeps the app speaking with
  `data/speech/` empty. A pack that ships without clips, a download that has
  not finished, a species added between two releases — all of them have to
  land on #151's voice rather than on silence, because a child who cannot read
  and hears nothing has no task at all.
