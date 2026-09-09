# Fonts

Copies of the two faces the app bundles, so that `next/font/local` can serve
them from this project's own origin — nothing is fetched from Google Fonts at
build or at run time.

| File | Family | Designer | Licence |
|---|---|---|---|
| `Baloo2-VariableFont_wght.ttf` | Baloo 2, weight axis 400–800 | Ek Type | OFL 1.1, `Baloo2-OFL.txt` |
| `Nunito-VariableFont_wght.ttf` | Nunito, weight axis 200–900 | Vernon Adams, Cyreal, Jacques Le Bailly | OFL 1.1, `Nunito-OFL.txt` |

The bytes are byte-for-byte the ones in `apps/ZilpZalp/Resources/Fonts/`; their
provenance is documented in the `NOTICE.md` next to each original. Copied
rather than referenced because Vercel builds this directory with `apps/web` as
its root and cannot reach outside it.

The OFL requires the licence to travel with the font files, which is what the
two `*-OFL.txt` are for.
