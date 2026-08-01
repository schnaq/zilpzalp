# Plan: M0 — Fundament

**Datum:** 2026-08-01
**Grundlage:** [Spec](../specs/2026-08-01-zilpzalp-v1-design.md), GitHub-Issues #1–#6 (Milestone M0)
**Ziel:** Jeder kann klonen, `mise run setup` ausführen, bauen und testen. Grünes CI-Gate.

## Arbeitsweise

Ein Task entspricht einem GitHub-Issue. Jeder Task läuft in einem eigenen Git-Worktree auf einem eigenen Branch und endet mit einem Pull Request, der das Issue per `Closes #N` schließt. PRs werden von Menschen begutachtet — **niemals selbst mergen**.

Reihenfolge und Abhängigkeiten:

- **Welle 1 (parallel):** Task 1, Task 5, Task 6 — unabhängig voneinander, Basis `main`
- **Welle 2:** Task 2 — baut auf dem Branch von Task 1 auf (gestapelter PR)
- **Welle 3:** Task 3 auf Task 2, danach Task 4 auf Task 3

## Globale Constraints

- Swift 6.2 mit strict concurrency, Deployment-Target iOS/iPadOS 18
- Bundle-ID: `com.schnaq.zilpzalp`
- Conventional Commits: Betreff imperativ, höchstens 50 Zeichen, kein Punkt am Ende; Fließtext bei 72 Zeichen umbrechen
- Branch-Namen: `chore/…` für alle M0-Tasks
- Niemals ein Secret ins Repo, auch nicht als Beispielwert
- PR-Beschreibungen auf Deutsch
- Nichts committen, was nicht zum Task gehört; keine Umformatierung fremder Dateien
- `design/` und `screens/` niemals anfassen

## Task 1 — Monorepo-Grundgerüst und mise.toml (#1)

**Branch:** `chore/monorepo-mise` von `main`. **PR:** `Closes #1`.

Verzeichnisse `apps/`, `packages/`, `tools/`, `data/packs/` anlegen und `mise.toml` als zentralen Einstieg schreiben.

**Tasks in mise**

- `setup` — Werkzeuge und Abhängigkeiten installieren
- `check` — Format, Lint, Tests, Lizenz-Gate; identisch zu dem, was CI ausführt
- `test` — nur die Package-Tests
- `build` — App bauen
- `fetch-media` — Medien kuratieren

**Zu pinnen:** Xcode 26.6, Swift 6.2, Python für `tools/`, SwiftFormat, SwiftLint, xcbeautify.

SwiftLint, SwiftFormat und xcbeautify fehlen lokal und müssen über mise kommen, nicht über eine manuelle Homebrew-Installation — sonst weicht der Runner von der Entwicklungsmaschine ab.

**Präzisierungen für diesen Task**

- Xcode selbst ist nicht über mise installierbar. Lösung: `mise run setup` bzw. `check` prüft die Xcode-Version (26.6, Build via `xcodebuild -version`) und bricht mit klarer Meldung ab, wenn sie abweicht
- Die mise-Tasks für `check`, `test`, `build` dürfen in diesem Task noch Platzhalter mit ehrlicher Meldung sein, wo die Ziele noch fehlen (kein Xcode-Projekt, kein Lint-Config, kein Lizenz-Gate-Tool). Ein Platzhalter endet mit Exit-Code 0 und `::notice::`-artiger Meldung, WAS noch fehlt und welches Issue es liefert (#2, #3, #17). `setup` muss echt funktionieren
- Leere Verzeichnisse brauchen `.gitkeep`
- Diese Plandatei (`docs/superpowers/plans/2026-08-01-m0-fundament.md`) liegt unversioniert im Haupt-Arbeitsverzeichnis unter demselben Pfad — in diesem Task mit committen, sie gehört zur Projektdokumentation
- `.gitignore` für Xcode/Swift/Python-Artefakte anlegen (DerivedData, `.build/`, `*.xcuserstate`, `__pycache__/`, `.superpowers/` ist bereits selbst-ignorierend)

**Fertig, wenn** ein frischer Klon nach `mise run setup` mit `mise run check` durchläuft (mit den dokumentierten Platzhalter-Meldungen).

## Task 2 — Xcode-Projekt und die drei SwiftPM-Pakete (#2)

**Branch:** `chore/xcode-projekt` von `chore/monorepo-mise` (gestapelter PR, Basis-Branch im PR entsprechend setzen). **PR:** `Closes #2`.

App-Target unter `apps/ZilpZalp/` und die Pakete `ZilpZalpCore`, `ZilpZalpData`, `ZilpZalpUI` unter `packages/`.

**Vorgaben**

- Swift 6.2 mit strict concurrency, Deployment-Target iOS/iPadOS 18
- Bundle-ID `com.schnaq.zilpzalp`
- `ZilpZalpCore` importiert weder SwiftUI noch UIKit noch Netzwerk-APIs. Reine Wertetypen
- `ZilpZalpUI` enthält keine Spiellogik
- Das App-Target ist nur Verdrahtung
- String Catalog von Anfang an: alle UI-Texte in `Localizable.xcstrings`, nichts hart im Code

**Präzisierungen für diesen Task**

- Projekterzeugung über **XcodeGen** (`project.yml` versioniert, `.xcodeproj` wird generiert und ist git-ignoriert). XcodeGen über mise pinnen und in `mise run setup` integrieren; `mise run build` generiert das Projekt vor dem Build. Begründung: reproduzierbar, keine Binär-Blobs im Repo, keine Merge-Konflikte im Projektfile
- Jedes Paket bekommt ein Minimal-Gerüst mit je mindestens einem echten Typ und einem echten Test (kein `assert(true)`): z. B. `ZilpZalpCore` mit einem `Rank`-Platzhaltertyp ist NICHT gefordert — nimm etwas Triviales, das nicht in Konflikt mit #22/#23 gerät, etwa eine `ZilpZalpCore.version`-Konstante mit Test. Die echte Spiellogik kommt in M3
- App zeigt vorerst nur einen Platzhalter-Screen (App-Name als Text). Kein Design-System-Vorgriff
- iPhone- und iPad-Familie (Targeted Device Families 1,2), Querformat und Hochformat wie es das Design später braucht — vorerst alle Orientierungen erlauben
- mise-Tasks `test` und `build` aus Task 1 von Platzhaltern auf echte Aufrufe umstellen (`swift test` je Paket; `xcodebuild build` ohne Codesign via xcbeautify)

**Fertig, wenn** `swift test` in allen drei Paketen läuft und die App im Simulator startet (nachweisen mit `xcrun simctl launch`-Ausgabe).

## Task 3 — SwiftFormat und SwiftLint konfigurieren (#3)

**Branch:** `chore/format-lint` von `chore/xcode-projekt` (gestapelter PR). **PR:** `Closes #3`.

Konfiguration für beide Werkzeuge, abgestimmt auf Swift 6.2, und als mise-Task verfügbar.

SwiftFormat läuft in CI mit `--lint`, damit unformatierter Code den Build bricht statt still korrigiert zu werden.

**Präzisierungen für diesen Task**

- `.swiftformat` und `.swiftlint.yml` im Wurzelverzeichnis, Geltungsbereich: `apps/` und `packages/`, ausgenommen generierte Dateien
- Der `check`-Platzhalter aus Task 1 wird für Format und Lint durch echte Aufrufe ersetzt; zusätzlich ein Task `format`, der lokal tatsächlich formatiert
- Bestehenden Code aus Task 2 einmalig konform formatieren, falls nötig — das gehört ausnahmsweise zum Task

**Fertig, wenn** `mise run check` beide ausführt und bei einem Verstoß mit Exit-Code ungleich null endet (nachweisen: absichtlichen Verstoß einbauen, rot sehen, zurücknehmen).

## Task 4 — CI-Workflow: Format, Lint, Tests, Build-Smoke (#4)

**Branch:** `chore/ci-workflow` von `chore/format-lint` (gestapelter PR). **PR:** `Closes #4`.

`.github/workflows/ci.yml` für Pull Requests und Pushes auf `main`.

**Aufbau**

- `runs-on: [self-hosted, macOS, ARM64]`
- `concurrency: ci-${{ github.ref }}` mit `cancel-in-progress: true`
- Actions SHA-gepinnt mit `# vX`-Kommentar
- Schritte: mise → SwiftFormat/SwiftLint → `swift test` → Lizenz-Gate → `xcodebuild build` ohne Codesign für iPhone und iPad

**Reihenfolge zum Lizenz-Gate:** Das Tool entsteht erst mit #17 in M2. Bis dahin läuft der Schritt als ausdrücklich markierter Skip mit `::notice::`-Hinweis. Sobald das Tool existiert, ist sein Fehlen ein Fehler — nie stillschweigend überspringen.

**Auf dem persistenten Runner beachten**

- Xcode über `DEVELOPER_DIR` pinnen, nicht über `setup-xcode`
- DerivedData und Build-Ausgaben vor dem Build löschen, sonst schlagen alte Artefakte durch
- Werkzeuge müssen vorinstalliert sein. Prüfen mit `command -v X || { echo "::error::…"; exit 1; }` statt `curl | bash`

**Präzisierungen für diesen Task**

- Der CI-Lauf ruft `mise run check` auf — dieselbe Definition wie lokal, kein paralleles Skript
- Ob ein self-hosted Runner mit den Labels bereits registriert ist, ist unbekannt. Der Workflow wird trotzdem korrekt geschrieben; im PR-Text ausdrücklich darauf hinweisen, dass der erste Lauf einen registrierten Runner voraussetzt

**Fertig, wenn** der Workflow syntaktisch valide ist (`actionlint`, falls verfügbar, sonst Begründung) und der PR die Runner-Voraussetzung dokumentiert. Der echte Grün-Nachweis folgt, sobald der Runner steht.

## Task 5 — MIT-Lizenz, README, CODEOWNERS, PR-Template und Dependabot (#5)

**Branch:** `chore/repo-grundausstattung` von `main`. **PR:** `Closes #5`.

Die Grundausstattung eines quelloffenen Repos.

- `LICENSE` mit MIT (Copyright-Inhaber: „schnaq GmbH", Jahr 2026)
- `README.md`: was die App ist, wie man sie baut (`mise run setup` / `check` / `build`), wie man beiträgt, Hinweis auf die Medienlizenzen (nur CC0/CC BY/CC BY-SA, Verweis auf `docs/medien-und-lizenzen.md`)
- `CODEOWNERS` mit `* @n2o`
- `.github/pull_request_template.md` — kurz: Was/Warum/Wie geprüft, Checkbox für `mise run check`
- `.github/dependabot.yml` für GitHub Actions und Python (pip in `tools/`), wöchentlich

**Präzisierungen für diesen Task**

- README auf Deutsch, Ton wie AGENTS.md: knapp, konkret, keine Marketing-Prosa
- Nicht mit Task 1 kollidieren: dieser Task legt keine Verzeichnisse und keine mise.toml an; README beschreibt die mise-Kommandos so, wie Task 1 sie definiert

**Fertig, wenn** alle fünf Dateien liegen und das PR-Template beim Öffnen eines Test-PR greift.

## Task 6 — .infisical.json anlegen und Secret-Zugang prüfen (#6)

**Branch:** `chore/infisical-config` von `main`. **PR:** verweist auf #6, schließt es NICHT (`Teil von #6`), weil die Prüfung des Secret-Zugangs Credentials braucht, die noch nicht vorliegen.

`.infisical.json` im Wurzelverzeichnis, damit lokale Aufrufe ohne zusätzliche Flags funktionieren:

```json
{
  "workspaceId": "9820fa11-518f-4760-a64f-7f832e6c2e8a",
  "defaultEnvironment": "dev",
  "gitBranchToEnvironmentMapping": null,
  "domain": "https://secrets.schnaq.com"
}
```

**Achtung:** Die CLI erwartet die Domain **mit** `/api`, die GitHub Action **ohne** — prüfen gegen `docs/secrets.md` und die Datei entsprechend korrekt anlegen; wenn `docs/secrets.md` etwas anderes sagt als dieses Snippet, gewinnt `docs/secrets.md`.

**Nicht in diesem Task** (blockiert auf Credentials, bleibt im Issue offen): Machine Identity für CI anlegen, `INFISICAL_CLIENT_ID`, `INFISICAL_CLIENT_SECRET`, `INFISICAL_API_URL` als GitHub-Secrets hinterlegen, Zugangsprüfung.

**Fertig, wenn** die Datei korrekt liegt und der PR-Text dokumentiert, welcher Rest auf Credentials wartet.
