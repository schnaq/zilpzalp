# Baloo 2 — provenance

- Designer: Ek Type
- Family: Baloo 2 (variable font, weight axis 400–800)
- License: SIL Open Font License 1.1 — see `OFL.txt` in this directory
- Source repository: https://github.com/google/fonts/tree/main/ofl/baloo2
- Vendored from commit: `c13390277dfb1fcc7415d84ef7ef9cfc1e52f8c1`
- Retrieved: 2026-08-02
- Upstream filename at that commit: `Baloo2[wght].ttf`
- File in this repo: `Baloo2-VariableFont_wght.ttf`
- SHA-256: `d47a6852548059b1db49a1319d06d499d546c3fa2237cf9eee9c43c8abb025c2`

The bytes are unmodified as published in the `google/fonts` repository at
the commit above — only the filename changed, to drop the `[wght]` axis
suffix (Xcode/XcodeGen resource handling does not tolerate `[`/`]` in
bundled filenames). The new name is not invented: it is the exact filename
Google's own `fonts.google.com` distribution package uses for this same
file (verified via `fonts.google.com/download/list?family=Baloo%202`, which
also confirms Google still ships a matching `static/Baloo2-*.ttf` set
alongside the variable font in that consumer-facing package — only the
`google/fonts` *source* repository dropped standalone static files for this
family, in commit `8e0cd058` (2021-11-25); that repository is what these
bytes were vendored from).

Used weights ship as named instances inside the variable font and are
addressed by PostScript name in `ZFont` (`ZilpZalpUI`): `Baloo2-Regular`
(400), `Baloo2-SemiBold` (600), `Baloo2-Bold` (700), `Baloo2-ExtraBold` (800).

This file documents provenance for the eventual Credits screen (#18); it is
not bundled into the app.
