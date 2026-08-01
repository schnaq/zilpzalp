# ZilpZalp v1 — Design und Spezifikation

**Datum:** 2026-08-01
**Status:** Entwurf zur Freigabe
**Grundlage:** [docs/2026-07_basics.md](../../2026-07_basics.md), Design-Export unter `design/`, Klickprototyp unter `screens/`

---

## 1. Was gebaut wird

Eine quelloffene Lern-App, mit der Kinder heimische Vögel kennenlernen. Kein Account, keine Werbung, keine Käufe, keine Datenerhebung. Alles bleibt auf dem Gerät.

**Plattformen:** iPhone und iPad nativ, zusätzlich lauffähig auf Apple-Silicon-Macs über „Designed for iPad" — dort ohne eigene Optimierung.

**In v1 enthalten**

| Bereich | Umfang |
|---|---|
| Spiel 1 | Vogelname wird vorgelesen, aus vier Fotos das richtige antippen |
| Spiel 2 | Vogelruf wird abgespielt, aus vier Fotos das richtige antippen |
| Profile | Mehrere lokale Profile mit Namen und Avatar, ohne Account |
| Fortschritt | Sterne, acht Ränge von Kohlmeise bis Wiedehopf, Sammlung, lokales Leaderboard |
| Artenpakete | 10 Arten fest gebundelt, „Vögel Deutschlands" (~60 Arten) als Download aus S3 |
| Elternbereich | Per FaceID/Code geschützt: Zeitbudget, Paketverwaltung, Credits, Einstellungen |

**Bewusst nicht in v1**

Spiel 3 (Federn zuordnen) und Spiel 4 (Lebensraum antippen). Beide sind nicht am Code gescheitert, sondern am Material — siehe [docs/medien-und-lizenzen.md](../../medien-und-lizenzen.md). Sie bleiben im Design als „Kommt bald ins Nest" sichtbar. Ebenso zurückgestellt: echte Accounts, Spiel gegen andere, andere Artengruppen wie Bäume oder Fische.

---

## 2. Getroffene Entscheidungen

| Thema | Entscheidung | Begründung |
|---|---|---|
| Sprache | Swift 6.2, SwiftUI, Xcode 26.6 | Vorgabe; SwiftUI deckt iPhone, iPad und Mac aus einer Codebasis |
| Deployment-Target | iOS/iPadOS 18 | Deckt iPads ab ca. 2018 — Kinder spielen oft auf Altgeräten |
| macOS | „Designed for iPad" auf Apple Silicon | Null Engineering-Aufwand, erfüllt „lauffähig, nicht optimiert" |
| Lizenz | MIT | Kein Konflikt mit App-Store-Verteilung, anders als bei GPL/AGPL |
| Repo | Monorepo `apps/` + `packages/` + `tools/` | Konsistent mit dem unlock-Repo |
| Task-Runner | mise | Vorgabe; ersetzt asdf und einen separaten Makefile-Wildwuchs |
| Secrets | Infisical, self-hosted | Vorgabe; Muster aus unlock übernommen |
| CI | GitHub Actions auf `[self-hosted, macOS, ARM64]` | Vorgabe |
| Branches | `main`, Release über SemVer-Tag | Passt zu Store-Releases; unlocks `dev`/`prod` zielt auf Continuous Deployment |
| Assets | Scaleway S3, Manifest im Git | Repo bleibt schlank, Builds bleiben reproduzierbar |
| Auslieferung | Basis-Paket gebundelt, weitere Pakete aus S3 | Sofort spielbar ohne Netz, neue Pakete ohne App-Update |
| S3-Zugriff | öffentlich lesbar | Es sind CC-lizenzierte Dateien; signierte URLs würden einen Schlüssel in der App oder einen Proxy erzwingen |
| Werkzeugsprache | `tools/` in Python | HTTP, Bildskalierung, ffmpeg und S3-Upload sind dort ein Bruchteil des Codes |
| Persistenz | Codable-JSON hinter einem Actor | Wenige Daten; ohne SwiftData in reinen Unit-Tests prüfbar |
| Store-Kategorie | Kids Category | Zielgruppe; Konsequenzen siehe Abschnitt 7 |
| Lokalisierung | Nur Deutsch, aber i18n-fähig gebaut | Texte in String Catalogs, Englisch später ohne Refactoring |
| Medienlizenzen | Nur CC0, CC BY, CC BY-SA | NonCommercial ist bei App-Store-Verteilung angreifbar und nicht weitergebbar |

---

## 3. Architektur

### Repo-Layout

```
apps/ZilpZalp/            Xcode-Projekt: App-Target, Assets, Info.plist, Entitlements
packages/
  ZilpZalpCore/           Spiellogik: Runden, Scoring, Ränge, Zeitbudget — UI-frei
  ZilpZalpData/           Bird-Modell, Paket-Manifeste, Profil-Persistenz, Downloader
  ZilpZalpUI/             Design-System: Tokens und Komponenten
tools/                    Python — HTTP, Bildskalierung, ffmpeg, S3
  fetch-media/            Kuratiert Medien aus iNaturalist/xeno-canto, lädt nach S3
  generate-credits/       Erzeugt Credits-Daten und CREDITS.md aus den Manifesten
data/
  packs/*.json            Paketdefinitionen inklusive Lizenz-Metadaten
docs/                     Spec, Medienentscheidung, Secrets, CD-Runbook
design/  screens/         Design-Export und Klickprototyp, unverändert als Referenz
mise.toml                 Werkzeuge und Tasks
```

Die gesamte Logik liegt in SwiftPM-Paketen ohne UI-Abhängigkeit. Dadurch läuft `swift test` in Sekunden ohne Simulator, und das CI-Gate bleibt schnell und verlässlich. Nur das App-Target braucht Xcode und einen Simulator.

### Modulgrenzen

**ZilpZalpCore** kennt weder SwiftUI noch Dateisystem noch Netzwerk. Es enthält:
- `Round` — erzeugt aus einer Artenmenge eine Runde aus 10 Fragen mit je vier Antwortoptionen, wobei die Ablenker zufällig, aber reproduzierbar über einen injizierten Zufallsgenerator gezogen werden
- `Scoring` — aus der Zahl der auf Anhieb richtigen Antworten die Sterne: ab 9 drei Sterne, ab 6 zwei, sonst einer
- `RankLadder` — Sternschwellen 0/25/60/100/150/220/300/400 für Kohlmeise, Amsel, Blaumeise, Rotkehlchen, Star, Buntspecht, Eisvogel, Wiedehopf
- `PlayBudget` — verbrauchte Spielzeit pro Tag und Profil gegen ein eingestelltes Limit

Reine Wertetypen und Funktionen. Vollständig testbar ohne Laufzeitumgebung.

**ZilpZalpData** kapselt alles, was den Zustand hält:
- `Bird`, `MediaAsset`, `Pack` als Codable-Modelle
- `PackCatalog` — liest das gebundelte Basis-Paket und die geladenen Pakete
- `PackDownloader` — lädt Pakete per URLSession aus S3, prüft SHA-256, entpackt nach Application Support
- `ProfileStore` — ein Actor über einer JSON-Datei; Profile, Sterne, Statistik, Sammlung

**ZilpZalpUI** übersetzt das Design-System nach SwiftUI: Farb- und Typo-Tokens, `ZButton`, `ZCard`, `ChoiceTile`, `SoundButton`, `QuizProgress`, `FeedbackBanner`, `RewardSticker`, `HomeTile`, `SettingRow`. Eins zu eins zu den Komponenten unter `design/components/`.

### Datenmodell

```swift
struct Bird: Codable, Identifiable {
    let id: String              // "amsel"
    let name: String            // "Amsel"
    let scientificName: String  // "Turdus merula"
    let taxonID: Int            // iNaturalist 12716
    let article: String         // "die" — für "Wo ist die Amsel?"
    let photo: MediaAsset
    let call: MediaAsset?       // fehlt, solange kein freier Ruf vorliegt
}

struct MediaAsset: Codable {
    let file: String            // "photos/amsel.jpg"
    let sha256: String
    let license: License        // .cc0 | .ccBy | .ccBySa
    let attribution: String     // "Alexis Tinker-Tsavalas"
    let sourceURL: URL          // Beobachtung bzw. Aufnahme
}

struct Pack: Codable, Identifiable {
    let id: String              // "deutschland"
    let title: String           // "Vögel Deutschlands"
    let birds: [Bird]
    let bundled: Bool           // im App-Bundle oder aus S3 geladen
    let downloadSize: Int
}
```

`birds.json` je Paket ist die einzige Wahrheit. Aus ihr entstehen zur Build-Zeit sowohl die Assets als auch der Credits-Screen. Attribution kann dadurch nicht von den Assets abdriften.

### Medien-Pipeline

```
data/packs/*.json ──> tools/fetch-media ──> Scaleway S3 (zilpzalp-media, fr-par)
                                                 │
                     Basis-Paket ────────────────┼──> Asset Catalog ──> App-Bundle
                     Download-Pakete ────────────┴──> zur Laufzeit per PackDownloader
                                                 │
                     tools/generate-credits ─────┴──> Credits-Screen + CREDITS.md
```

`fetch-media` spricht iNaturalist und xeno-canto **nur zur Kurationszeit** an, niemals die App zur Laufzeit. Das löst gleich mehrere Probleme: keine Rate-Limits im Betrieb, keine verschwindenden Fremd-URLs, geprüfte Lizenzen, gleichbleibende Bildqualität und volle Offline-Fähigkeit.

Ein CI-Gate bricht den Build ab, sobald ein Asset eine Lizenz außerhalb von CC0/CC BY/CC BY-SA trägt oder Attribution fehlt.

### Paket-Download

Der Bucket `zilpzalp-media` liegt bei Scaleway Object Storage in `fr-par`, Endpunkt `s3.fr-par.scw.cloud`, Inhalte öffentlich lesbar. Schreibzugriff hat nur `tools/fetch-media` mit Zugangsdaten aus Infisical. Öffentlich lesbar ist die richtige Wahl, weil es ausschließlich CC-lizenzierte Dateien sind — signierte URLs würden entweder einen Schlüssel in der App oder einen eigenen Dienst erzwingen, und beides ist für eine App ohne Backend der falsche Weg.

Die App holt beim Start des Elternbereichs einen Katalog (`packs/index.json`) aus S3 und zeigt verfügbare Pakete mit Größe an. Ein Download läuft über `URLSession` mit Fortschrittsanzeige, prüft jede Datei gegen ihren SHA-256 und legt sie unter Application Support ab, ausgenommen vom iCloud-Backup. Pakete sind einzeln löschbar. Das gebundelte Basis-Paket lässt sich nicht entfernen, damit die App nie inhaltsleer wird.

Neue Pakete können dadurch ohne App-Update und ohne Review ausgeliefert werden — der Grund, warum wir nicht Apples On-Demand Resources nehmen.

---

## 4. Spielablauf

Beide Spiele nutzen dieselbe Engine, sie unterscheiden sich nur darin, wie die Frage gestellt wird.

1. Kind wählt sein Profil, dann ein Spiel
2. Zehn Fragen. Pro Frage: Aufgabe wird ausgegeben — Spiel 1 liest den Namen per `AVSpeechSynthesizer` vor, Spiel 2 spielt den Ruf ab, wiederholbar per Tippen
3. Vier Fotokacheln. Richtige Wahl färbt sich olivgrün mit Häkchen, falsche Wahl färbt sich sonnengelb mit „Fast! Hör nochmal hin." — **niemals rot, niemals ein Kreuz, kein Blockieren**. Das Kind darf weiter probieren
4. Nach zehn Fragen: Sterne, gegebenenfalls Rangaufstieg, neuer Sticker in der Sammlung

Der Blätter-Fortschritt zeigt den Stand ohne Zahlen. Bei erschöpftem Zeitbudget läuft die aktuelle Runde noch zu Ende, danach erscheint „Zeit fürs Nest".

**Sprachausgabe:** `AVSpeechSynthesizer` mit `de-DE` direkt auf dem Gerät. Kein Audio-Asset, keine Lizenzfrage, keine Netzabhängigkeit. Der Klickprototyp macht es mit der Web Speech API bereits genauso.

---

## 5. Datenhaltung und Datenschutz

Alles liegt lokal. Kein Netzwerkverkehr außer den ausdrücklich von Eltern angestoßenen Paket-Downloads aus dem eigenen S3-Bucket. Keine Analytics, kein Crash-Reporting durch Dritte, keine Werbe-SDKs, keine Accounts.

Profile liegen als JSON in Application Support:

```
Profiles/profiles.json      Name, Avatar, Sterne, Rang, Statistik, Sammlung
Packs/<pack-id>/            Heruntergeladene Pakete
Settings/parental.json      Zeitbudget, ob FaceID aktiv ist
```

Kein Passwort im Klartext. Der Elternbereich nutzt `LAContext` mit `deviceOwnerAuthentication`, was automatisch auf den Geräte-Code zurückfällt, wenn keine Biometrie vorhanden ist. Auf „Designed for iPad"-Macs muss dieser Fallback geprüft werden.

Abstürze werden ausschließlich über Apples eigenes MetricKit und den Xcode Organizer sichtbar. Das ist in der Kids Category der einzig saubere Weg.

---

## 6. Testkonzept

| Ebene | Werkzeug | Umfang |
|---|---|---|
| Logik | Swift Testing (`@Test`) in SwiftPM | Rundenerzeugung, Scoring, Rangschwellen, Zeitbudget, Manifest-Parsing, SHA-Prüfung |
| Lizenz-Gate | eigenes Tool in CI | Jedes Asset hat erlaubte Lizenz und Attribution |
| Snapshot | Xcode-Previews, manuell | Design-Komponenten gegen `design/` |
| Integration | XCTest im Simulator, sparsam | Ein Durchlauf pro Spiel, Profilanlage, Paket-Download gegen einen lokalen Server |

Bewusst wenige Simulator-Tests. Ein instabiles Gate auf einem self-hosted Runner wird binnen einer Woche abgeschaltet — dann ist gar nichts gewonnen.

---

## 7. Kids Category — Konsequenzen

Die Wahl der Kids Category ist keine reine Metadaten-Entscheidung, sie bindet die Umsetzung:

- **Keine Third-Party-Analytics und kein Third-Party-Crash-Reporting.** Kein Sentry, kein Firebase. Nur MetricKit
- **Externe Links brauchen ein Parental Gate.** Betrifft direkt den Credits-Screen: die Quellenlinks zu iNaturalist, xeno-canto und den Lizenztexten dürfen nicht ohne Erwachsenen-Prüfung öffnen. Umsetzung: Credits zeigen Namen und Lizenz immer im Klartext, der Link öffnet erst nach der FaceID-Abfrage
- **Privacy Manifest** (`PrivacyInfo.xcprivacy`) ist Pflicht und deklariert: keine Datenerhebung
- **Datenschutzerklärung** muss verlinkt sein — als statische Seite, nicht in der App klickbar ohne Gate
- Werbung, In-App-Käufe und Verhaltens-Targeting entfallen ohnehin

Die genauen Wortlaute der Guidelines 1.3 und 5.1.4 sind noch gegen die aktuelle Fassung zu prüfen; die entsprechende Recherche wurde abgebrochen. Das ist als Aufgabe in Meilenstein 6 eingeplant und blockiert die Entwicklung bis dahin nicht.

---

## 8. CI/CD

Zwei Workflows, beide auf `[self-hosted, macOS, ARM64]`.

**`ci.yml`** — bei jedem Pull Request und Push auf `main`:
`mise install` → SwiftFormat und SwiftLint → `swift test` über alle Pakete → Lizenz-Gate über die Manifeste → `xcodebuild build` ohne Codesign für iPhone und iPad.
`concurrency: ci-${{ github.ref }}` mit `cancel-in-progress: true`.

**`release.yml`** — bei Tag `v*`:
Infisical lädt die Signing-Secrets → ephemere Keychain wird angelegt → `xcodebuild archive` und `-exportArchive` → Upload nach TestFlight über die App Store Connect API → git-cliff erzeugt den Changelog-Eintrag → Keychain wird per `if: always()` wieder entfernt.
`cancel-in-progress: false`, damit ein laufender Upload nie abgebrochen wird.

Aus unlock übernommen: SHA-gepinnte Actions, `Infisical/secrets-action` mit Universal Auth, `::add-mask::` für jeden aus Infisical geladenen Wert, vorinstallierte Werkzeuge statt `curl | bash`, Aufräumen des Signing-Materials mit `if: always()`.

Bewusst anders als unlock: Swift statt Flutter, Tag-basiertes Release statt Branch-Deploy, und CODEOWNERS, PR-Template sowie Dependabot werden ergänzt — im Referenz-Repo fehlen sie.

**Secrets.** In GitHub liegen nur `INFISICAL_CLIENT_ID`, `INFISICAL_CLIENT_SECRET` und `INFISICAL_API_URL`. Alles andere kommt aus Infisical: Signing-Zertifikat und Profil, App-Store-Connect-Key, Scaleway-Zugangsdaten, xeno-canto-API-Key. Details in [docs/secrets.md](../../secrets.md).

---

## 9. Meilensteine

| # | Ziel | Ergebnis |
|---|---|---|
| M0 | Fundament | Monorepo, mise, Xcode-Projekt, grünes CI-Gate, AGENTS.md, CLAUDE.md, MIT-Lizenz |
| M1 | Design-System in Swift | Tokens und alle Komponenten als SwiftUI, Fonts und Lucide-Icons eingebunden |
| M2 | Daten und Medien | Paket-Schema, S3-Bucket, `fetch-media`, Lizenz-Gate, generierte Credits, **Guidelines-Recherche** |
| M3 | Spiel 1 | Quiz-Engine, Sprachausgabe, Sterne-Scoring, Layout für iPhone und iPad |
| M4 | Profile und Fortschritt | Profilwahl, Avatare, Ränge, Sammlung, Leaderboard „Unser Schwarm" |
| M5 | Spiel 2 und Pakete | Vogelrufe, Audio-Player, Paket-Download, Elternbereich mit Schloss, Paketverwaltung |
| M6 | Eltern und Compliance | Zeitbudget, Parental Gate, Privacy Manifest, Age Rating |
| M7 | Release | Signing, TestFlight, Store-Assets, „Designed for iPad" auf Mac |
| M8 | Danach | Spiel 3 Federn, Spiel 4 Lebensraum, weitere Pakete, Englisch |

M0 bis M2 sind Fundament und lassen sich weitgehend parallel bearbeiten. Ab M3 baut jeder Meilenstein auf dem vorherigen auf.

Die Recherche zu den App-Review-Guidelines liegt bewusst schon in M2 und nicht erst in M6: der Paket-Downloader in M5 erzeugt ausgehenden Netzverkehr, und `PrivacyInfo.xcprivacy` erklärt gleichzeitig, dass keine Daten erhoben werden. Inhalte abrufen ist aller Voraussicht nach keine Datenerhebung — aber das ist eine Aussage in einer verpflichtenden Erklärung, und sie sollte belegt sein, bevor der Netzwerkcode entsteht, nicht danach.

---

## 10. Offene Punkte

Diese Fragen sind bewusst offen und blockieren den Start nicht:

1. **CC BY-SA bei zugeschnittenen Audios.** Schneiden wir eine BY-SA-Aufnahme auf wenige Sekunden zu, entsteht ein Bearbeitungswerk, das unter derselben Lizenz stehen muss. Für die Audiodateien ist das unproblematisch — sie bleiben BY-SA, der Code bleibt MIT. Ob das Zusammenspiel mit den App-Store-Bedingungen und deren technischen Schutzmaßnahmen sauber ist, muss ein Mensch beurteilen. Ausweg, falls nötig: nur CC0- und CC-BY-Aufnahmen verwenden
2. **Qualität der Vogelrufe.** Die Verfügbarkeit ist belegt — alle vierzig geprüften Arten haben frei lizenzierte Aufnahmen. Offen ist die inhaltliche Eignung: viele Aufnahmen sind Flügelschläge, Bettelrufe oder nächtliche Flugrufe statt des typischen Gesangs. Jede Aufnahme muss vor Aufnahme ins Paket angehört werden
3. **Habitat-Zuordnung für Spiel 4** muss selbst erarbeitet und belegt werden. Ein systematisches Übernehmen der Kategorisierung von NABU oder LBV berührt das Datenbankrecht nach §87a UrhG
4. **Wortlaut der App-Review-Guidelines** zu Kids Category und Altersfreigabe ist gegen die aktuelle Fassung zu verifizieren
5. **Artenliste und Rangleiter** sind inhaltliche Entscheidungen, die Christian und Johanna treffen — nicht technische

---

## 11. Erfolgskriterien für v1

- Ein Kind kann ohne Lesefähigkeit und ohne Hilfe eine Runde spielen
- Die App startet ohne Netzverbindung und ist mit dem gebundelten Basis-Paket vollständig spielbar. Nur das Laden zusätzlicher Pakete braucht einmalig Netz
- Jedes angezeigte Medium nennt Urheber und Lizenz, automatisch aus dem Manifest erzeugt
- Ein Fremder kann das Repo klonen, `mise run setup` ausführen und die App bauen
- Das CI-Gate ist grün und schnell genug, dass niemand es umgehen will
- Kein Byte verlässt das Gerät außer beim ausdrücklich angestoßenen Paket-Download
