# ZilpZalp Design System

**ZilpZalp** is an iPad app that teaches children (4+) about birds and nature through play. The core loop is a **bird quiz that needs no reading**: a call plays, and the child taps the bird they hear. Everything a child sees is a photo, an icon, a colour or a sound — words exist for grown-ups and for reading aloud, never as a requirement.

The name is the German name of the *Chiffchaff* (`Phylloscopus collybita`) — a small olive-green bird named after its own two-note song. That gives the system its two mascots and its palette poles: the **Zilpzalp's leaf green** (primary) and the **Wiedehopf / Hoopoe's cinnamon orange** (accent).

## Sources

None. This system was authored from a written brief only — no codebase, Figma file, deck, logo, font binaries, photography or copy were supplied. Every value here is a proposal, not a recreation. Concretely invented (and open for your correction):

- the colour system, including the primary colour (three candidates are shown side by side — see "Primary colour" below),
- the type pairing (Baloo 2 + Nunito, both Google Fonts),
- all German UI copy,
- the component inventory and the iPad screen flow.

If a real brand kit, App Store screenshots, or the app's codebase exist, hand them over and this system should be re-derived from them.

## Colour — derived from the reference photograph

The palette is **pipetted from `assets/reference/wiedehopf-reference.png`**, the hoopoe photo the client supplied, after three rounds of invented schemes were rejected as "too kid-app, too pale, not bird-like".

| Role | Token | Value | Origin in the photo |
| --- | --- | --- | --- |
| Primary | `--color-primary` | `#6E7A21` olive | the meadow behind the bird (`#A1AB53` / `#3B4218`) |
| Accent | `--color-accent` | `#DD6E22` | the crest (`#ED9156`), deepened for contrast |
| Reward / retry | `--color-reward` `--color-retry` | `#E9B21C` | sunlit crest tips |
| Feathers / hints | `--color-info` | `#C9552B` clay | breast plumage |
| Ground | `--surface-page` | `#FBF3E4` oat | warm paper, not white |
| Ink | `--text-strong` | `#2A2213` | the sooty black of the crest tips |

**The system is warm only** — no blue, no teal, no grey, no red. Contrast comes from the soot-dark ink and from each element's ledge, not from black outlines: shapes stay round (26–40px radii) and press into a solid colour ledge.

### Locked decision: scheme "E + F" (final)

After four exploration rounds the client chose **E + F** and it is now the system: oat ground `#FBF3E4`, olive top bar, round radii (26–40px) with coloured ledges — **no black outlines, no hard offset shadows** — and **answer tiles fully filled with their rubric colour, the photo field in that colour's lightest tint** (the "F tiles"). Recorded in `guidelines/color-schemes-hoopoe-round.html` (middle option, "E + F · umgesetzt") and implemented in `tokens/colors.css` + `ChoiceTile tone="…"`. Do not re-explore this; treat it as fixed.

**Ten rubric colours**, all from the same family, give every topic its own colour: `--rubric-wald`, `-wiese`, `-rufe`, `-belohnung`, `-federn`, `-rinde`, `-beeren`, `-nest`, `-sumpf`, `-sonne`. `ChoiceTile tone="…"` paints a tile body in the full rubric colour with the photo field in its lightest tint — that is where the design gets its colourfulness.

## Content fundamentals

- **Language: German, informal `du`.** "Wer singt da?", "Hör nochmal hin", "Gut gemacht!". Never `Sie` to a child; `Sie` **only** in the grown-ups area ("Hier stellen Sie ein, wie lange gespielt wird").
- **Everything kid-facing is 1–4 words** and works when read aloud by the app: `Weiter`, `Los!`, `Nochmal hören`, `Genau!`, `Fast!`. Sentence case, no full stops on labels, at most one exclamation mark.
- **Never negative, never a score.** There is no "Falsch", no ✗, no red, no timer, no leaderboard. A wrong tap is `Fast! Hör nochmal hin.` — an invitation, on sunny yellow.
- **We say what the child did, not how clever they are.** "Du hast den Zilpzalp gefunden!" over "Du bist ein Genie!".
- **Bird names are always the real ones** (Zilpzalp, Wiedehopf, Blaumeise) — children love real words. Names are shown *and* spoken; they can be switched off for pre-readers.
- **Grown-up copy is plain, calm, and parent-respecting**: full sentences, 20–24px, no marketing tone, no exclamation marks. "Keine Werbung, keine Käufe."
- **No emoji anywhere.** The visual voice is photos + Lucide glyphs; emoji would fight both.
- **Vibe:** a nature notebook a child scribbles in — curious, patient, sunny. Closer to a forest kindergarten than to a game console.

## Visual foundations

**Colour.** Warm, photo-derived, organised by rubric: olive (primary), crest orange (accent, audio), sun (reward + "try again"), clay (feathers/hints), bark, berry, marsh. Neutrals are warm — oat paper `#FBF3E4`, sand lines, soot ink `#2A2213`. **No blue, no grey, no red anywhere.** The ground stays oat on every screen; colour arrives through tiles and rubric colours, so a quiz screen can carry four different hues without becoming loud.

**Type.** `Baloo 2` (700/800) for every kid-facing word — rounded terminals, high x-height, holds up at 88px. `Nunito` for grown-up prose. Kid text floor is **20px**; buttons are 22px, headlines 28–36px, screen titles 48–64px, celebrations 88px. The 16px caption size is legal in the grown-ups area only.

**Spacing & layout.** 4-based scale, but the app lives at 24–48px. Screen gutter is 48px. Landscape iPad, 1194×834. The header is fixed and translucent; the answer grid is a single 4-up row that never scrolls; the grown-ups door is always top-right, the back chevron always top-left. Touch targets: **64px floor, 96px default, 160px+ for answers.**

**Backgrounds.** Cream paper by default. Two full-bleed exceptions: forest green `--surface-forest` for celebrations and chapter starts, and a soft sky→cream→leaf vertical gradient on Home. No photographic backgrounds behind text, no noise/grain, no decorative gradients anywhere else.

**Cards & borders.** Every card and tile carries a **3px solid outline** (5px on tiles) in sand or its own rubric shade — never black, never a hard offset shadow. Radii: 12 / 20 / 28 (cards) / 40 (tiles) / 56 / pill. Buttons are always pills. Nothing in the system has a sharp corner; the shapes are deliberately round and soft.

**Shadows.** Two systems. (1) Ambient: `--shadow-sm/md/lg`, always tinted with bark brown — never neutral black. (2) The **ledge**: every pressable sits on a 6–10px solid block of its own 700-shade, like a plastic toy button. Ledges replace outlines as the contrast device.

**Press & hover.** Press = translate down onto a 2px ledge in 90ms; correct tiles then lift 4px with `--ease-bounce`. Hover (trackpad only; iPad is touch-first) lightens the fill ~12%, never darkens, never scales. Focus = 5px sky-blue ring. Disabled = 45% opacity, ledge removed.

**Animation.** Anything that appears bounces in (`--ease-bounce`, 260–420ms); anything that moves eases out (160ms). Idle life: resting elements bob 8px over 1.6s, stickers sit at −4°. Celebrations get 900ms. Nothing is linear, nothing crossfades slowly, nothing exceeds 900ms. Keyframes live in `guidelines/motion.css` (`zz-pop`, `zz-ring`, `zz-bob`, `zz-wiggle`).

**Transparency & blur.** Exactly one use: the fixed TopBar (88% cream + 12px backdrop blur) so content scrolls under it. Modals use a 45% green-black scrim. No glassmorphism elsewhere.

**Photo credits.** Attribution sits **inside the image**, bottom-left: 13px Nunito semibold, cream text on a warm protection gradient (`rgba(42,34,19,.55)` → transparent, 14px tall). Never over the bird's head, never a separate caption row, never bigger than 14px — small enough that children ignore it, legible enough for CC-BY. `ChoiceTile credit="…"` renders it; a collected sum-up list also lives in the grown-ups area as legal backup. Photography comes from **iNaturalist** (API, filtered to CC0/CC-BY); `assets/photos/CREDITS.md` records species, photographer, licence and observation URL.

**Imagery.** Real bird photography, warm daylight, shallow depth of field, subject centred, square crop, no filters and no black-and-white. Habitat shots may go full-bleed 16:9. Until photos arrive, `ChoiceTile` shows a sand placeholder with a bird glyph — ship real photos before launch.

## Iconography

- **Lucide**, loaded from CDN (`https://unpkg.com/lucide@latest/dist/umd/lucide.min.js`), wrapped by `components/core/Icon.jsx`. **This is a substitution** — no icon set was provided. Lucide was chosen because its rounded caps and even stroke sit closest to the brand's chunky outlines. Swap it for the real set when one exists; only `Icon.jsx` changes.
- **Stroke weight 2.5–3.5**, never 1–2: thin icons look fragile next to 5px tile borders.
- Kid-facing sizes are **32–64px** and icons are *always* paired with a photo, a colour or a word — the only wordless icon controls are the four navigation glyphs (back, home, album, sound), which children learn in one session.
- Recurring glyphs: `volume-2` / `play` (calls), `bird`, `feather`, `leaf` (progress), `star` (rewards), `egg` (locked), `sparkles` (rare), `album` (collection), `user-round-cog` (grown-ups).
- **No emoji, no unicode dingbats, no hand-drawn SVG.** No icon font.
- No brand mark exists: the wordmark is set in Baloo 2 800, "Zilp" green + "Zalp" orange (`components/brand/Wordmark.jsx`). Nothing in `assets/` — see `assets/README.md` for the manifest of what to drop in.

## Index

| Path | What |
| --- | --- |
| `styles.css` | The only file consumers link — `@import`s everything below |
| `tokens/` | `fonts.css` `colors.css` `typography.css` `spacing.css` `radii.css` `shadows.css` `motion.css` |
| `guidelines/` | `motion.css` (brand keyframes) + all foundation specimen cards |
| `components/` | `core/` `quiz/` `navigation/` `brand/` — see below |
| `ui_kits/ipad_app/` | Five-screen click-through recreation, `index.html` + `README.md` |
| `templates/quiz-round/` | Starting template: the iPad quiz round, ready to copy into a new design |
| `assets/` | `photos/` (10 bird photos, iNaturalist CC BY, + `CREDITS.md`), `reference/wiedehopf-reference.png` (palette source) |
| `SKILL.md` | Agent-Skills entry point |

### Components

**core/** — `Button`, `IconButton`, `Card`, `Badge`, `Icon`
**quiz/** — `ChoiceTile`, `SoundButton`, `QuizProgress`, `RewardSticker`, `FeedbackBanner`
**navigation/** — `TopBar`, `HomeTile`, `SettingRow`
**brand/** — `Wordmark`

Each has a sibling `.d.ts` (props contract) and `.prompt.md` (what & when + usage). No source defined an inventory, so this is an authored set sized to the product; there is deliberately no Input, Select, Tabs, Dialog, Toast or Tooltip — a wordless children's quiz has no use for them yet.

**Intentional additions:** `Icon` (a thin Lucide wrapper, so a future icon-set swap touches one file) and `Wordmark` (stands in for missing logo artwork).

## Known gaps

1. The palette is derived from one photograph; if the app's real photography has a different white balance, re-pipette it.
2. **Fonts are linked from Google Fonts**, not vendored — no licensed binaries were provided. If you have the real faces, drop them in and replace `tokens/fonts.css` with `@font-face` rules.
3. **No logo, illustration or audio.** Bird photography is solved (iNaturalist, CC BY — see `assets/photos/CREDITS.md`); stickers and the home tree are still stand-ins.
4. **Icons are a Lucide substitution.**
5. Copy is German only; no localisation strategy is defined.
