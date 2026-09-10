# Plan: pack management in the grown-ups' area

Status: proposed 2026-09-10, for #34. Parents download, see and delete species
packs behind the existing lock; the games then draw from every installed pack
plus the bundled base pack. Spec §3 "Paket-Download" is the contract.

## The merged catalog

`PackLibrary` (new, `ZilpZalpData`) is what the app plays from: a value type
over `[PackCatalog]`, bundled first, installed packs after it in id order.

- `birds: [Bird]` — the union, in pack order. **A species id seen twice is kept
  once, the first pack wins.** Ids are globally unique by curation rule, but a
  downloaded manifest is a document somebody else wrote, and both
  `SpeciesPhotos` and `QuizSession` build their dictionaries with
  `Dictionary(uniqueKeysWithValues:)` — which traps on a duplicate key. The rule
  is a crash guard, not tidiness.
- `photoURL(for:)`, `callURL(for:)`, `speechURL(for:sentence:)` — the same three
  questions `PackCatalog` answers, routed to the pack the bird came from.
- `packs: [Pack]`, `isEmpty`, `static let empty`.

`PackCatalog` stays what it is: one pack, one directory. `SpeechClips` takes a
`PackLibrary` instead of a `PackCatalog`, so a downloaded pack's recorded
sentences are found the way the bundled one's are.

The app replaces `AppModel.catalog: PackCatalog?` with a non-optional
`PackLibrary` — an empty library is the failure `RootView` already draws
`app.pack.failed` for. That removes an optional from `CollectionScreen`,
`RoundEndSticker` and the previews rather than adding one.

## What is on disk

`PackInstallation` (new): one installed pack's `catalog`, its `pack` and its
`bytes` on disk. `PackDownloader.installations()` walks `Packs/` once and
returns every pack that opened plus a `PackDownloadError` per pack that did
not — **a broken manifest costs its own species and nothing else**, where
`installedPacks()` used to fail the whole listing. `installedPacks()` and
`catalog(for:)` have no callers outside the tests once this exists, so they go
with the same commit.

Size is summed from `.fileSizeKey` and `.isRegularFileKey` only. No date key,
no `attributesOfItem` — those are the Required Reason APIs
`docs/kids-category.md` says not to declare speculatively, and nothing here
needs them. Total storage is the sum of the installed rows.

## Download flow and states

`PackModel` (new, app target) owns the one `PackDownloader`, pointed at the
public read endpoint of the media bucket, and holds what the shell reads:

- `library` and `photos` — opened synchronously from the bundled pack in `init`
  so the launch is unchanged, then merged with the installed packs in `load()`.
  Both are rebuilt after every install and delete, so a pack loaded while the
  app runs reaches the games without a restart.
- `available` — `.loading` / `.failed` / `.ready([PackIndex.Entry])`, fetched
  when the grown-ups' area opens and never before. **The lock is the only door
  the network is behind** (Kids Category).
- `installed` — the rows: the bundled pack first and not deletable, then every
  downloaded one with its size.
- `progress` per pack id, and the ids whose last download failed. The
  downloader's progress closure runs on its own executor, so every report hops
  to the main actor before it touches observable state.

A download that fails or is interrupted leaves the pack's `.partial` directory
and nothing installed — the downloader's existing rule, which is also what
makes a retry resume. Deleting removes both directories.

## The UI

A "Pakete" card in `ParentsScreen`, from `SettingRow` and `ZCard` like the rows
above it (`design/` has no pack screen to follow):

| State | Row |
|---|---|
| bundled | title, "10 Arten · immer dabei", not tappable |
| available | title, "60 Arten · 12 MB" — a tap starts the download |
| downloading | "60 Arten · 42 %", row disabled |
| installed | "60 Arten · 12 MB", a tap asks "löschen?" before it deletes |

Under the card the total on the device. Calm sentences instead of the list when
the index could not be fetched, and one line under a pack whose download failed.
German strings, English keys (`parents.packs.*`), `%lld Arten` as a plural
variation.

## Tests

Swift Testing in `ZilpZalpData`, no new simulator test:

- the library over the bundled pack alone; over bundled plus one installed pack;
  a species with a call and one without; a duplicate id kept once, first pack
  winning; a pack whose manifest does not decode skipped **and reported**.
- install and delete round trip against the existing `StubBucket`: after the
  download the library holds both packs, after the delete only the bundled one.
- storage: the size of an installed pack, and nothing counted twice.

## Commits

1. this plan
2. `PackLibrary` + `SpeechClips` + tests
3. `PackInstallation`, `installations()`, storage, tests
4. `PackModel` and the app wiring (`catalog:` → `library:`)
5. the "Pakete" card and its strings
6. spec §3: one dated line
