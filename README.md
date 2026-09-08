<img src="assets/logo.svg" alt="ZilpZalp" width="96" align="right">

# ZilpZalp

An open-source learning app that teaches children the birds around them. No
account, no ads, no purchases, no data collection. Everything stays on the
device.

Native on iPhone and iPad, and runnable on Apple Silicon Macs through "Designed
for iPad" — without a dedicated Mac layout.

ZilpZalp is by **Johanna Hillebrand**, in collaboration with
[schnaq GmbH](https://schnaq.com). The idea and the implementation are hers;
schnaq provides the home for the project — repository, build and release
infrastructure, and the media bucket.

**Status:** in development, no release yet. The specification, the design export
and the clickable prototype exist; the Swift implementation is being built.

## What's in it

In version 1:

- **Game 1** — the bird's name is read aloud, tap the right one of four photos
- **Game 2** — a bird call is played, tap the right one of four photos
- **Profiles** — several local profiles with a name and an avatar, no account
- **Progress** — stars, eight ranks from great tit to hoopoe, a collection, a local leaderboard
- **Species packs** — 10 species bundled with the app, "Birds of Germany" (~60 species) as a download
- **Parent area** — behind Face ID or the device passcode: time budget, packs, credits

Game 3 (match the feather) and game 4 (tap the habitat) are deferred. They did
not fail on the code but on the material — see
[docs/medien-und-lizenzen.md](docs/medien-und-lizenzen.md).

## Building

Requirements: macOS on Apple Silicon, Xcode 26.6 and
[mise](https://mise.jdx.dev). mise installs everything else.

```
mise run setup        install dependencies and tools
mise run check        format, lint, tests, licence gate — the same as CI
mise run format       format the sources and fix correctable lint findings
mise run test         package tests only
mise run generate     generate the Xcode project (before opening it in Xcode)
mise run build        build the app
mise run fetch-media  curate media and upload it to S3
```

Do not call `xcodebuild` or `swift` directly — the tool versions are pinned in
`mise.toml`, and drifting away from them is the most common cause of "works
locally, fails in CI".

The game logic lives in SwiftPM packages with no UI dependency, so
`mise run test` needs no simulator and finishes in seconds.

`mise run fetch-media` needs credentials from Infisical, see
[docs/secrets.md](docs/secrets.md). A plain clone is enough for everything else.

## Layout

| Path | Contents |
|---|---|
| `apps/ZilpZalp/` | Xcode project: app target, assets, Info.plist, entitlements |
| `packages/ZilpZalpCore/` | Game logic: rounds, scoring, ranks, time budget — UI-free |
| `packages/ZilpZalpData/` | Models, pack manifests, persistence, downloader |
| `packages/ZilpZalpUI/` | Design system: tokens and SwiftUI components |
| `tools/` | Media curation and credits generation — Python |
| `data/packs/` | Species packs with licence metadata |
| `docs/` | Specification, media decision, secrets |
| `design/`, `screens/` | Design export and clickable prototype, kept unchanged as reference |

The specification is binding:
[docs/superpowers/specs/2026-08-01-zilpzalp-v1-design.md](docs/superpowers/specs/2026-08-01-zilpzalp-v1-design.md).

## Contributing

Issues and pull requests are welcome. For anything larger, please open an issue
first — it is no fun to build out an idea that turns out not to fit the
specification.

- Branch off `main`, merge through a pull request. No direct pushes to `main`
- Branch names: `feat/…`, `fix/…`, `docs/…`, `chore/…`
- [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/);
  imperative subject, 50 characters at most, no trailing period
- `mise run check` has to pass before a PR goes up

The full working rules — architecture boundaries, testing approach, pitfalls —
are in [AGENTS.md](AGENTS.md). That file addresses AI coding agents, but it
applies to humans just as much.

The app is meant for children who cannot read yet and will ship in the App
Store's Kids Category. That rules out third-party analytics, crash reporting,
ads and tracking. Check for those before proposing a dependency.

## Licences

The code is under the [MIT licence](LICENSE).

**Media follow a separate, stricter rule: CC0, CC BY and CC BY-SA only.** No
NonCommercial, no NoDerivatives — neither could be passed on to people who fork
this repository. Every photo and every recording is declared in
`data/packs/*.json` with source, creator, licence and SHA-256; a gate in CI
fails the build if any of that is missing. The credits screen is generated from
the same manifests and therefore cannot drift away from the assets.

Reasoning and sources: [docs/medien-und-lizenzen.md](docs/medien-und-lizenzen.md).

Photos come from iNaturalist, calls from xeno-canto — both are queried at
curation time only. The app never talks to them at runtime.
