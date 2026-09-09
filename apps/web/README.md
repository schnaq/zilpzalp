# apps/web — the ZilpZalp website

The landing page and the legal pages behind `zilpzalp.schnaq.com`: the marketing
URL, the privacy policy URL and the support URL that App Store Connect asks for
before the first review. Next.js 16 with the App Router, TypeScript, plain CSS,
no component library and no client-side JavaScript of its own.

German product copy, English code and comments — the same rule as everywhere
else in this repository, see [AGENTS.md](../../AGENTS.md).

## Working on it

```
mise run web:install   install from the committed bun.lock
mise run web:dev       serve on localhost with hot reload
mise run web:lint      ESLint over the flat config
mise run web:build     the build CI and Vercel run
```

bun's version is pinned in `mise.toml` like every other tool. `mise run check`
— the Swift gate — deliberately does not touch this directory, and neither
SwiftFormat nor SwiftLint crawls it.

## Where the design comes from

The palette, the spacing and the two faces are the app's, from
`packages/ZilpZalpUI/Sources/ZilpZalpUI/Tokens` and `design/tokens`. Warm only:
no blue, no teal, no neutral grey, no red. The dark theme has no counterpart in
the app and is derived here, inside the same world.

`fonts/` holds copies of the two variable fonts with their OFL licences —
copied rather than referenced because Vercel builds this directory as its root
and cannot reach outside it. Nothing is fetched from Google Fonts, or from
anywhere else, at build or at run time: no analytics, no cookies, no
third-party scripts, no external images.

## Vercel

Two settings the dashboard has to carry, because neither fits in `vercel.json`:

- **Root Directory: `apps/web`.** The `ignoreCommand` asks
  `git diff --quiet HEAD^ HEAD ./`, and `./` is that root directory. Pointed at
  the repository root instead, the command would skip every deploy that does
  not touch the root — including every change in here.
- The framework preset is Next.js; bun is detected from `bun.lock`.

`ignoreCommand` exits 0 to skip the build and non-zero to run it, which is why
a Swift-only push does not deploy. That is Vercel's own documented example, but
the JSDoc in `vercel/vercel` states the opposite convention — so watch the
first two deploys: a Swift-only commit should skip, a change in here should
build.

## Screenshots

`public/screenshots/` is empty until #168 lands. The section on the landing page
checks for each file while the page prerenders and draws a placeholder frame in
its place, so the images appear on the next build with no layout work; the
names it expects are in
[public/screenshots/README.md](public/screenshots/README.md).
