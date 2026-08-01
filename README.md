<img src="assets/logo.svg" alt="ZilpZalp" width="96" align="right">

# ZilpZalp

Eine quelloffene Lern-App, mit der Kinder heimische Vögel kennenlernen. Kein
Account, keine Werbung, keine Käufe, keine Datenerhebung. Alles bleibt auf dem
Gerät.

iPhone und iPad nativ, auf Apple-Silicon-Macs über „Designed for iPad"
lauffähig — dort ohne eigene Optimierung.

**Status:** in Entwicklung, noch kein Release. Es gibt die Spezifikation, den
Design-Export und den Klickprototyp; die Swift-Umsetzung entsteht gerade.

## Was drin ist

In Version 1:

- **Spiel 1** — der Vogelname wird vorgelesen, aus vier Fotos das richtige antippen
- **Spiel 2** — ein Vogelruf wird abgespielt, aus vier Fotos das richtige antippen
- **Profile** — mehrere lokale Profile mit Namen und Avatar, ohne Account
- **Fortschritt** — Sterne, acht Ränge von Kohlmeise bis Wiedehopf, Sammlung, lokales Leaderboard
- **Artenpakete** — 10 Arten fest gebundelt, „Vögel Deutschlands" (~60 Arten) als Download
- **Elternbereich** — per FaceID oder Gerätecode geschützt: Zeitbudget, Pakete, Credits

Spiel 3 (Federn zuordnen) und Spiel 4 (Lebensraum antippen) sind zurückgestellt.
Sie sind nicht am Code gescheitert, sondern am Material — siehe
[docs/medien-und-lizenzen.md](docs/medien-und-lizenzen.md).

## Bauen

Voraussetzungen: macOS auf Apple Silicon, Xcode 26.6 und
[mise](https://mise.jdx.dev). Alles Weitere installiert mise.

```
mise run setup        Abhängigkeiten und Werkzeuge installieren
mise run check        Format, Lint, Tests, Lizenz-Gate — das gleiche wie in CI
mise run test         Nur die Package-Tests
mise run build        App bauen
mise run fetch-media  Medien kuratieren und nach S3 laden
```

`xcodebuild` und `swift` nicht direkt aufrufen — die Werkzeugversionen sind in
`mise.toml` gepinnt, und Abweichungen davon sind die häufigste Ursache für
„geht lokal, geht in CI nicht".

Die Spiellogik liegt in SwiftPM-Paketen ohne UI-Abhängigkeit. `mise run test`
braucht deshalb keinen Simulator und ist in Sekunden durch.

`mise run fetch-media` braucht Zugangsdaten aus Infisical, siehe
[docs/secrets.md](docs/secrets.md). Für alles andere reicht ein Klon.

## Aufbau

| Pfad | Inhalt |
|---|---|
| `apps/ZilpZalp/` | Xcode-Projekt: App-Target, Assets, Info.plist, Entitlements |
| `packages/ZilpZalpCore/` | Spiellogik: Runden, Scoring, Ränge, Zeitbudget — UI-frei |
| `packages/ZilpZalpData/` | Modelle, Paket-Manifeste, Persistenz, Downloader |
| `packages/ZilpZalpUI/` | Design-System: Tokens und SwiftUI-Komponenten |
| `tools/` | Medien-Kuration und Credits-Erzeugung — Python |
| `data/packs/` | Artenpakete mit Lizenz-Metadaten |
| `docs/` | Spezifikation, Medienentscheidung, Secrets |
| `design/`, `screens/` | Design-Export und Klickprototyp, unverändert als Referenz |

Verbindlich ist die Spezifikation:
[docs/superpowers/specs/2026-08-01-zilpzalp-v1-design.md](docs/superpowers/specs/2026-08-01-zilpzalp-v1-design.md).

## Mitmachen

Issues und Pull Requests sind willkommen. Vor größeren Änderungen bitte erst
ein Issue aufmachen — es lohnt sich nicht, an einer Idee zu bauen, die nicht
zur Spezifikation passt.

- Branch von `main`, Merge per Pull Request. Kein direkter Push auf `main`
- Branch-Namen: `feat/…`, `fix/…`, `docs/…`, `chore/…`
- [Conventional Commits](https://www.conventionalcommits.org/de/v1.0.0/);
  Betreff imperativ, höchstens 50 Zeichen, kein Punkt am Ende
- `mise run check` muss durchlaufen, bevor ein PR aufgemacht wird

Die vollständigen Arbeitsregeln — Architekturgrenzen, Testkonzept, Fallstricke —
stehen in [AGENTS.md](AGENTS.md). Die Datei richtet sich an KI-Coding-Agenten,
gilt aber genauso für Menschen.

Die App ist für Kinder gedacht, die noch nicht lesen können, und erscheint in
der Kids Category des App Store. Daraus folgt: kein Third-Party-Analytics, kein
Crash-Reporting, keine Werbung, kein Tracking. Wer eine Abhängigkeit vorschlägt,
prüft das vorher.

## Lizenzen

Der Code steht unter der [MIT-Lizenz](LICENSE).

**Für Medien gilt eine eigene, härtere Regel: nur CC0, CC BY und CC BY-SA.**
Kein NonCommercial, kein NoDerivatives — beides ließe sich nicht an Leute
weitergeben, die dieses Repository forken. Jedes Foto und jede Tonaufnahme wird
in `data/packs/*.json` mit Quelle, Urheber, Lizenz und SHA-256 deklariert; ein
Gate in der CI bricht den Build ab, wenn etwas davon fehlt. Der Credits-Screen
wird aus denselben Manifesten erzeugt und kann deshalb nicht von den Assets
abdriften.

Begründung und Quellenlage: [docs/medien-und-lizenzen.md](docs/medien-und-lizenzen.md).

Fotos stammen aus iNaturalist, Rufe aus xeno-canto — beide werden ausschließlich
zur Kurationszeit angefragt. Die App spricht zur Laufzeit nie mit ihnen.
