# Plan: the pack gallery

Status: proposed 2026-10-20, brief confirmed by Christian. Replaces the
text-only "Pakete" card (`PacksSection`, plan 2026-09-10-pack-management) with a
gallery parents can see birds in, and gives the child side a way to ask for
more birds without reading. Spec §3 "Paket-Download" is updated with it.

Audience: a parent at home on Wi-Fi, usually prompted by a child ("mehr
Vögel!"). Outcome: from Home, at most two taps plus the unlock to see packs;
photos before downloading; one button to load; "Fertig – jetzt spielen" selects
the new pack as the child's collection.

## Index schema (`packs/index.json`)

Every new field is optional. The 1.0.0 build decodes this index too, so nothing
existing is renamed or removed, and an index without the new fields (today's
bucket) still decodes — the cards then draw glyph stickers.

```json
{
  "packs": [{
    "id": "afrika", "title": "Vögel Afrikas", "speciesCount": 30,
    "downloadSize": 17500000, "manifest": "packs/afrika/manifest.json",
    "manifestSha256": "…",
    "covers": ["strauss", "kronenkranich", "graupapagei"],
    "species": [{
      "id": "strauss", "name": "Strauß",
      "preview": "packs/afrika/previews/strauss.jpg",
      "attribution": "…", "license": "CC-BY-4.0"
    }]
  }],
  "retired": [{"id": "welt", "successors": ["…"]}]
}
```

- `manifestSha256`: SHA-256 of the manifest **as the bucket holds it** (from
  the object metadata for packs not uploaded in this run, so a local re-curation
  that was never uploaded does not leave the app stuck on "Aktualisieren"). An
  installed pack whose manifest hashes differently has an update.
- `covers`: three species ids, the first three of the manifest — the curated
  order already opens with the pack's best-known birds.
- `species`: one line per bird, with a 256 px square JPEG thumbnail of the
  curated portrait (`photos[0]`) and that photo's attribution and licence. The
  thumbnails are CC BY / BY-SA derivatives shown before the pack's credits are
  on the device, so the detail page prints their attribution, generated from
  these fields. **Only listed when the bucket holds the pack's previews** (the
  first preview key is checked, as the manifest is): the index never names an
  object nobody can fetch.
- `retired`: packs that are dissolved into others. A retired pack is not in
  `packs` any more. `RETIRED` in `tools/fetch_media/index.py` declares them; it
  stays empty until the successor packs of "Vögel der Welt" are uploaded. A
  test pins that a retired pack's species are a subset of its successors', so
  no sticker leaves the album.

Previews are staged by `fetch-media upload` like the index — outside
`data/packs/`, appended to the run after the pack's own objects and before the
index — and are **not** part of `s3.plan`, so `downloadSize` stays what the
download costs. Nothing is uploaded by this change: whoever has Infisical
re-uploads `afrika` and `welt` once to publish previews and hashes.

## Data and Core

- `PackIndex` gains the fields above, decoded with defaults.
- `PackIndex.migrations(installed:)`: for each installed retired pack, the
  successors the index offers. Tested.
- `PackInstallation.manifestSHA256`, hashed from the manifest `installations()`
  already reads.
- `PackDownloader.preview(_ key:)`: one bucket object through the same
  `fetch` (one host, `NoRedirects`, safe relative path). The default
  `URLCache` keeps it.
- Writing a file onto a full disk becomes `PackDownloadError.outOfSpace`, so
  the gallery can say so. Reacting to the write error rather than asking for
  free space first keeps the app off the `DiskSpace` Required Reason API
  (docs/kids-category.md); the download is resumable, so nothing is lost.
- `NewBirdsHint.isDue(collected:of:)` in `ZilpZalpCore`: 80 % of the
  installed species collected. Count-based, so it does not care how the
  sticker threshold is set; the app counts `profile.hasSticker(for:)` over the
  deduplicated library.
- Dedupe: `PackLibrary` already keeps a species id once, first pack wins, and
  stickers are keyed by species id. Species may now be in several packs by
  design, so tests pin it for "Alle Vögel", a narrowed pack and the
  collections.

## App

- **Gallery** (`PackGallery`), first section of the open Elternbereich: one
  card per pack — bundled, installed, downloadable — with three overlapping
  sticker circles, the title, "N Vögel · X MB" and one state button:
  `Laden` → progress ring → `✓ Geladen` → `Aktualisieren`. A pack loaded in this
  visit shows `Fertig – jetzt spielen` instead, which chooses it as the
  playing child's collection and goes Home. Stickers of species already on the
  device use the local photo; the rest are previews from the bucket.
- **Detail** sheet per pack: every species as a sticker grid with its name,
  the load button, delete for installed packs, and the photo credits. A sheet
  rather than a push: leaving the screen shuts the door. It lives inside the
  open subtree, so it closes when the door does.
- **States**: offline (index or download fails: calm sentence, retry);
  expensive or constrained path (`NWPathMonitor`) asks before a download;
  an interrupted download resumes (`Weiterladen`); out of space says so;
  update available; delete with confirmation.
- **Retired packs**: an installed retired pack puts a card on top of the
  gallery offering its successors. Loading them deletes the retired pack only
  once every successor is installed.
- **Child side**: the collection picker scrolls (10+ packs) and ends with a
  "+" sticker that opens the Elternbereich — the gallery is its first section,
  so that is the deep link. No text-only affordance.
- **Hints**: the grown-ups' button on Home wears a sparkle badge (label
  "Neue Vögel" for VoiceOver, no text for the child) once the playing child
  holds 80 % of the installed species' stickers, unless the last index seen
  had nothing left to load. A one-time, dismissible line for grown-ups on Home
  ("Mehr Vögel im Elternbereich") after a profile exists; dismissed for good by
  its close button or by opening the Elternbereich. Neither touches the
  network; both stay off in screenshot runs.

## Out of scope / open

- The "+" tile only exists where the picker does, i.e. with two or more packs
  installed — a fresh install relies on the first-start hint.
- First pack wins can keep a species' callless copy while another pack has a
  call, which costs game 2 that species. Preferring the copy with a call would
  change which photo a sticker shows; left alone.
- Successor packs of "Vögel der Welt" are still to be curated; `RETIRED` stays
  empty until they are in the bucket.
