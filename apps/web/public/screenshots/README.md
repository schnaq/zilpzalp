# Screenshots

The "Ein Blick in die App" section on the landing page expects six PNGs here.
Until they exist the section draws its placeholder frames, so dropping the
files in is the whole job — no layout work follows.

| File | Screen |
|---|---|
| `01-start.png` | Start screen with both game tiles |
| `02-wer-ist-das.png` | Game 1 "Wer ist das?", a question with its four photos |
| `03-wer-singt-da.png` | Game 2 "Wer singt da?", sound button and four photos |
| `04-sterne.png` | Round end with three stars and the new sticker |
| `05-sammlung.png` | Collection with several stickers found |
| `06-rangleiter.png` | Rank ladder, a child mid-way up |

The screens are the six from issue #168 in the same order; `mise run
screenshots` writes them to `DerivedData/screenshots/<device>/`, from where the
iPhone (6.9", 1320×2868) set is renamed as above. Any aspect ratio works — the
frames crop to portrait — but keep the six consistent with one another.

Nothing else belongs in this directory: no photos of birds, and no images from
elsewhere. Every media file the project ships carries a licence, and the ones
in the app are declared in `data/packs/*.json`.
