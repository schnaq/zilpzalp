# design-sync notes — zilpzalp

- **This repo is a Claude Design export, not a source library.** `design/` already holds the
  upload format (`_ds_bundle.js` with a `format: 4` `@ds-bundle` header, `_ds_manifest.json`,
  `styles.css`, `components/<group>/<Name>.{jsx,d.ts,prompt.md}` + per-group `*.card.html`,
  `tokens/`, `guidelines/`, `templates/`, `ui_kits/`, `assets/`).
  There is no `package.json`, no Storybook, no `dist/` — **do not run `package-build.mjs` or
  `package-validate.mjs`**; both target the converter layout, not this one. Sync = upload
  `design/` as-is (`localDir` must be the `design/` dir, paths are relative to it).
- Bundle freshness is checkable without a build: every entry in the header's `sourceHashes`
  is `sha256(file)[:12]`. All 20 matched at the 2026-07-31 sync (including
  `ui_kits/ipad_app/*.jsx` + `birds.js`, which are bundle-tracked).
- Card index is fully derivable: all 22 card HTMLs (incl. `guidelines/color-schemes-hoopoe-round.html`)
  carry a first-line `<!-- @dsCard … -->` marker. `_ds_manifest.json` was uploaded anyway (all
  its refs resolve); `_ds_needs_recompile` is armed so the app regenerates it.
- **No `.design-sync/conventions.md` and no `readmeHeader`.** The skill's conventions-header step
  assumes a generated README to prepend to — nothing generates a README here, and `design/readme.md`
  already documents wrapping, the token vocabulary (`--color-*`, `--rubric-*`, `--shadow-*`,
  ledge/press rules) and where the truth lives.
- **No `_ds_sync.json`.** `scriptsSha` / `styleSha` / `renderHashes` cannot be computed honestly
  without a converter run, so the sidecar is deliberately omitted — the next sync re-verifies
  from scratch instead of trusting a fabricated anchor.
- Dotfiles need explicit paths in the plan's `writes` (`.thumbnail`,
  `templates/quiz-round/.thumbnail`) — `**` does not reliably descend into them.
  Also note `readme.md` is lowercase, so a `README.md` glob misses it.
- Scope decision (user, 2026-07-31): upload **everything**, including the working files
  `scraps/inat-fetch.html`, `uploads/reference_file-*.png` and `SKILL.md`.
- Fonts come from Google Fonts via `@import` in `tokens/fonts.css` — there is no `fonts/` dir
  and no font binaries in the repo.
