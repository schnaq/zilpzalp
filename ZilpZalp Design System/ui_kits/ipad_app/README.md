# ZilpZalp — iPad app UI kit

Landscape iPad (1194×834). Five screens, all composed from the design-system components — nothing is re-implemented here.

| Screen | File | What it shows |
| --- | --- | --- |
| Home tree | `HomeScreen.jsx` | The trunk-and-branches home with activity nests (`HomeTile`), star count, bottom utility dock |
| Quiz | `QuizScreen.jsx` | Wordless round: `SoundButton` call, four `ChoiceTile` photos, `FeedbackBanner`, leaf `QuizProgress` |
| Reward | `RewardScreen.jsx` | Full-bleed forest-green celebration with one new `RewardSticker` |
| Collection | `CollectionScreen.jsx` | Sticker album, earned + locked, with habitat/rarity `Badge`s |
| Grown-ups | `GrownupsScreen.jsx` | The only screen with 16–20px type, switches and full sentences (`SettingRow`) |

Open `index.html` for the click-through: home → any nest → answer → reward → collection; the grown-ups door is top-right on every kid screen.

**Photography:** ten real bird photos live in `assets/photos/` (iNaturalist, CC BY, 512×512) and are wired through `birds.js`. The quiz screen shows them with the mandatory credit line inside the image; the grown-ups screen carries the collected credit list. Still placeholders: `RewardSticker` uses Lucide glyphs instead of illustrated stickers, and the home tree is built from plain rounded blocks as a stand-in for real illustration.
