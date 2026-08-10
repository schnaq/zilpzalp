# Plan: M1 — Design-System in Swift

**Datum:** 2026-08-02
**Grundlage:** [Spec](../specs/2026-08-01-zilpzalp-v1-design.md), Design-Export `design/`, Issues #7–#12, #47, #48 (Milestone M1)
**Ziel:** Alle Tokens und Komponenten aus `design/` als SwiftUI in `ZilpZalpUI`, Fonts und Icons eingebunden.

## Arbeitsweise

Wie M0: ein Task = ein Issue = ein Worktree = ein PR gegen `main` (kein Stapeln — Lehre aus M0). PRs werden von Menschen gemergt. Nach Merge-Konflikten rebased der Controller bzw. der Task-Agent.

Reihenfolge: Welle A parallel (Task 1 Fonts, Task 2 Icons, Task 8 App-Icon), dann Task 3 Tokens, dann Welle B (Task 4 Basis, Task 6 Navigation parallel), dann Task 5 Quiz-Komponenten, Task 7 Wortmarke.

## Globale Constraints

- Code, Kommentare, Commits, PR-Texte: Englisch. Produkttexte (falls überhaupt in Komponenten): über String Catalog, Deutsch
- Swift 6 strict concurrency; `mise run check` muss grün sein (SwiftFormat/SwiftLint sind scharf)
- `design/` und `screens/` sind Referenz — lesen ja, ändern nie
- Touch-Ziele nie unter 64 pt (Kinderhände); `correct` ist Olivgrün, `retry` Sonnengelb — niemals Rot, niemals ein X
- Jede Komponente bekommt eine Xcode-Preview mit allen Varianten
- Falls `.macOS(.v15)` in `ZilpZalpUI/Package.swift` beim SwiftUI-Code stört: Plattform entfernen (bewusste Entscheidung, im PR dokumentieren) statt `#available`-Verrenkungen
- Conventional Commits ≤50 Zeichen imperativ; kein Merge durch Agenten

## Task 1 — Baloo 2 und Nunito einbinden (#8)

**Branch:** `chore/fonts` von `main`. **PR:** `Closes #8`. **Diese Plandatei mit committen** (liegt unversioniert unter demselben Pfad im Haupt-Arbeitsverzeichnis).

Beide Schriften ins App-Bundle, mit Registrierung in der Info.plist (XcodeGen: `project.yml`, generierte Info.plist-Keys beachten — `UIAppFonts`) und einem Font-Helper in `ZilpZalpUI`.

**Lizenzpflichten (OFL 1.1)**
- Vollständige `OFL.txt` je Schrift mitliefern
- Copyright-Hinweise erhalten: Baloo 2 von Ek Type; Nunito von Vernon Adams, Cyreal und Jacques Le Bailly
- Schriften unverändert ausliefern (reservierte Namen unberührt)
- Beide Hinweise gehören später zusätzlich in den Credits-Bereich (#18) — hier nur als Dateien neben den Fonts

**Präzisierungen**
- Quelle: Google Fonts (offizielle Releases), Variable oder statische TTF — statisch bevorzugen, nur die Gewichte, die `design/tokens/` verlangt (400/600/700/800)
- Font-Helper: `ZFont`-Namespace in `ZilpZalpUI`, der Familiennamen + Gewichte kapselt, damit Komponenten nie String-Literale streuen
- Nachweis: App im Simulator zeigt einen Text in Baloo 2 (Screenshot oder gerenderte Preview), `mise run check` grün

## Task 2 — Lucide-Icons vendoren (#9)

**Branch:** `chore/lucide-icons` von `main`. **PR:** `Closes #9`.

Die benötigten Lucide-Symbole als SVG ins Repo, in ein Asset-Katalog-Set überführt und über einen `Icon`-Wrapper in `ZilpZalpUI` nutzbar.

- Benötigte Symbole aus `design/components/` und `design/ui_kits/ipad_app/` ermitteln (grep nach lucide-Importen/Namen im JSX)
- SVG → template image im Asset Catalog der `ZilpZalpUI`-Package-Resources (nicht App-Target — Komponenten-Previews brauchen sie)
- ISC-Copyright-Hinweis (Lucide) als Datei mitliefern; Symbole aus Feather brauchen zusätzlich dessen MIT-Hinweis
- `Icon`-Wrapper: typsicherer Zugriff (enum oder statische Konstanten), Größen-API passend zu Touch-Zielen
- Nachweis: Preview rendert mehrere Icons, `mise run check` grün

## Task 3 — Design-Tokens nach Swift (#7)

**Branch:** `feat/design-tokens` von `main`. **PR:** `Closes #7`.

Alle Tokens aus `design/tokens/*.css` als Swift-Konstanten in `ZilpZalpUI`.

- Farben: Olive, Orange, Sun, Clay, Bark, Berry, Marsh, warme Neutraltöne, semantische Aliase, zehn Rubrikfarben
- Typografie: hero 88 bis caption 16, Gewichte 400/600/700/800 (nutzt `ZFont` aus Task 1, falls schon gemergt — sonst Familiennamen-Konstanten, die Task 1 später konsumiert)
- Spacing 4–128, Touch-Ziele 64/96/160, Radien 12/20/28/40/56/pill, Rahmen 3 und 5
- Schatten inklusive Ledge-Effekt; Motion 90/160/260/420/900 ms und die vier Easing-Kurven
- **`correct` ist Olivgrün, niemals Rot; `retry` ist Sonnengelb** — didaktische Entscheidung
- **Klären und dokumentieren:** `ChoiceTile` kennt neun Rubriktöne, `colors.css` definiert zehn — `nest` und `sonne` fehlen dort. Diskrepanz im PR dokumentieren, Tokens vollständig aus `colors.css` übernehmen
- Nachweis: Preview mit Farbfeldern + Typo-Rampe, `mise run check` grün

## Task 4 — Basis-Komponenten (#10)

**Branch:** `feat/core-components` von `main`. Braucht Task 3. **PR:** `Closes #10`.

Nach `design/components/core/`: **ZButton** (Pill auf farbigem Ledge, Töne `primary|accent|reward|quiet`, Größen md 64/lg 96/xl 120, Druck 4 pt nach unten in 90 ms), **IconButton** (rund, wortlos, VoiceOver-`label` verpflichtend, min 64 pt), **ZCard** (Töne `paper|leaf|clay|sun|sand`, immer 3 pt Kontur), **Badge** (Pill, nicht tippbar). Ledge stets 700er-Variante der Farbe; keine schwarzen Schatten. Preview je Komponente mit allen Varianten.

## Task 5 — Quiz-Komponenten (#11)

**Branch:** `feat/quiz-components` von `main`. Braucht Tasks 3+4. **PR:** `Closes #11`.

Nach `design/components/quiz/`: **ChoiceTile** (Zustände `idle|chosen|correct|retry`, min 220 pt, `credit`-Feld bei CC-BY-Fotos Pflicht, unten links), **SoundButton** (min 120 pt, zwei pulsierende Ringe bei Wiedergabe), **QuizProgress** (Blätter, ohne Zahlen), **FeedbackBanner** (`correct|retry|hint`), **RewardSticker** (leicht gedreht, gesperrt sichtbar mit Schloss). Nie ein rotes X.

## Task 6 — Navigations-Komponenten (#12)

**Branch:** `feat/navigation-components` von `main`. Braucht Task 3. **PR:** `Closes #12`.

Nach `design/components/navigation/`: **TopBar** (fest, transluzent, 90 % Cream, 12 pt Blur), **HomeTile** (Töne `leaf|clay|sun|hoopoe`, 0–3 Sterne, gesperrt = Ei), **SettingRow** (einzige 16-pt-Text-Komponente; Navigations- und Schaltzeile).

## Task 7 — Wortmarke und Markenkomponenten (#48)

**Branch:** `feat/brand-components` von `main`. Braucht Tasks 1+3. **PR:** `Closes #48`.

Nach `design/components/brand/Wordmark.jsx`, mit echter Bildmarke: `assets/logo.svg` als Asset, skalierbar; Wortmarke „Zilp" olive-500 / „Zalp" orange-500, Baloo 2 800, min 40 pt, Töne `duo|mono-light|mono-dark`; Kombination für Startbildschirm und Elternbereich.

## Task 8 — App-Icon aus der Bildmarke (#47)

**Branch:** `feat/app-icon` von `main`. Unabhängig. **PR:** `Closes #47`.

Aus `assets/logo.svg` das App-Icon: Single-Size 1024×1024 für App Store Connect plus Dark- und Tinted-Varianten. Zwingend: deckender Hintergrund (cream-50 `#FFFCF3` oder olive-500 `#6E7A21` — Transparenz ist verboten), Schnabel-Beschnitt bei runden Ecken prüfen und Vogel ggf. neu im Quadrat ausrichten, vereinfachte Fassung für kleine Größen erwägen, auf dunklem Untergrund gegenprüfen (ink-900-Anteile). Rendering per Werkzeugkette (rsvg-convert/ImageMagick o. ä. über mise/uvx, nicht Homebrew global) — Skript unter `tools/` ablegen, damit das Icon reproduzierbar ist.
