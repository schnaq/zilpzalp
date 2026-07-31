# assets/

Contains one file: `reference/wiedehopf-reference.png` — the hoopoe photograph the whole colour system is pipetted from. No logo, illustration, product photography or icon files were provided, and this design system never invents brand artwork.

What belongs here once it exists:

| Path | What | Used by |
| --- | --- | --- |
| `assets/logo.svg` | Real ZilpZalp mark | replaces the internals of `components/brand/Wordmark.jsx` |
| `assets/photos/<bird>.png` | ✅ vorhanden: 10 Arten, 512×512, iNaturalist CC BY (`CREDITS.md`) | `ChoiceTile photo=` + `credit=` |
| `assets/audio/<bird>.mp3` | Real field recordings of calls | `SoundButton` |
| `assets/illustrations/tree.svg` | The home tree, nests, eggs | `ui_kits/ipad_app/HomeScreen.jsx` (currently plain rounded blocks) |

Icons are **not** vendored: they come from the Lucide CDN (`https://unpkg.com/lucide@latest/dist/umd/lucide.min.js`). See ICONOGRAPHY in the root readme.
