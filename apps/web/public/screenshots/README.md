# Screenshots

The "Ein Blick in die App" section on the landing page expects five PNGs here.
The file check runs while the page is prerendered, so dropping the files in and
building again is the whole job — no layout work follows, and a frame whose
file is missing draws a placeholder instead.

| File | Screen |
|---|---|
| `01-start.png` | Start screen with both game tiles |
| `02-erkenne-den-vogel.png` | Game 1 "Erkenne den Vogel", a question with its four photos |
| `03-wer-singt-da.png` | Game 2 "Wer singt da?", sound button and four photos |
| `04-sterne.png` | Round end with its stars and the new sticker |
| `05-sammlung.png` | Collection with several stickers found |

The screens come from issue #168, whose sixth capture — the rank ladder — is
gone with the ladder itself (decision of 2026-09-09). `mise run screenshots`
writes its captures to `DerivedData/screenshots/<device>/` under names of its
own; rename the iPhone set (6.9", 1320×2868) as above. Any aspect ratio works,
the frames crop to portrait, but keep the five consistent with one another.

Nothing else belongs in this directory: no bird photos, and no images from
elsewhere. Every media file this project ships carries a licence, and the ones
in the app are declared in `data/packs/*.json`.
