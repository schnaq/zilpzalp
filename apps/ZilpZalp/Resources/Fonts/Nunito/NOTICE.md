# Nunito — provenance

- Designers: Vernon Adams, Cyreal, Jacques Le Bailly
- Family: Nunito (variable font, weight axis 200–900)
- License: SIL Open Font License 1.1 — see `OFL.txt` in this directory
- Source repository: https://github.com/google/fonts/tree/main/ofl/nunito
- Vendored from commit: `8b0a1d0f5983c89bc2b93f1b5fb55f9e252744b5`
- Retrieved: 2026-08-02
- Upstream filename at that commit: `Nunito[wght].ttf`
- File in this repo: `Nunito-VariableFont_wght.ttf`
- SHA-256: `bb55a5ca5c2042335b3991af27c4d0705d0ef41cac6164ac737fd8f2a1e85207`

The bytes are unmodified as published in the `google/fonts` repository at
the commit above — only the filename changed, to drop the `[wght]` axis
suffix (Xcode/XcodeGen resource handling does not tolerate `[`/`]` in
bundled filenames). The new name is not invented: it is the exact filename
Google's own `fonts.google.com` distribution package uses for this same
file (verified via `fonts.google.com/download/list?family=Nunito`, which
also confirms Google still ships a matching `static/Nunito-*.ttf` set
(16 styles, weights 200–900 plus italics) alongside the variable font in
that consumer-facing package — only the `google/fonts` *source* repository
dropped standalone static files for this family, in commit `70c8ac40`
(2021-11-02); that repository is what these bytes were vendored from).

Used weights ship as named instances inside the variable font and are
addressed by PostScript name in `ZFont` (`ZilpZalpUI`): `Nunito-Regular`
(400), `Nunito-SemiBold` (600), `Nunito-Bold` (700), `Nunito-ExtraBold` (800).

This file documents provenance for the eventual Credits screen (#18); it is
not bundled into the app.
