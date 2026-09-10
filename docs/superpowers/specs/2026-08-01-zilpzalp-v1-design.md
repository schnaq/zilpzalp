# ZilpZalp v1 — Design und Spezifikation

**Datum:** 2026-08-01
**Status:** Gültig, zuletzt aktualisiert 2026-09-08
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
| Fortschritt | Sterne, Sticker nach fünf Wiedererkennungen, Sammlung, lokales Leaderboard |
| Artenpakete | „Vögel Deutschlands" (70 Arten) fest gebundelt, weitere Pakete als Download aus S3 |
| Elternbereich | Per FaceID/Code geschützt: Zeitbudget, Paketverwaltung, Einstellungen |
| Über ZilpZalp | Öffentlich, ohne Schloss: Version, Herausgeberin, Datenschutz, Internetseite, Support-Mail, Credits |

**Bewusst nicht in v1**

Spiel 3 (Federn zuordnen) und Spiel 4 (Lebensraum antippen). Beide sind nicht am Code gescheitert, sondern am Material — siehe [docs/medien-und-lizenzen.md](../../medien-und-lizenzen.md). In v1 tauchen sie in der Oberfläche nicht auf; sie kommen mit Meilenstein 8 zurück. Ebenso zurückgestellt: echte Accounts, Spiel gegen andere, andere Artengruppen wie Bäume oder Fische.

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
  ZilpZalpCore/           Spiellogik: Runden, Scoring, Sticker-Schwelle, Zeitbudget — UI-frei
  ZilpZalpData/           Bird-Modell, Paket-Manifeste, Profil-Persistenz, Downloader
  ZilpZalpUI/             Design-System: Tokens und Komponenten
tools/                    Python — HTTP, Bildskalierung, ffmpeg, S3
  fetch-media/            Kuratiert Medien aus iNaturalist/xeno-canto, lädt nach S3
  generate_credits.py     Erzeugt Credits-Daten und CREDITS.md aus den Manifesten
data/
  packs/<id>/             Ein Artenpaket, Verzeichnis je Pack-ID
    manifest.json         Paketdefinition inklusive Lizenz-Metadaten
docs/                     Spec, Medienentscheidung, Secrets, CD-Runbook
design/  screens/         Design-Export und Klickprototyp, unverändert als Referenz
mise.toml                 Werkzeuge und Tasks
```

Die gesamte Logik liegt in SwiftPM-Paketen ohne UI-Abhängigkeit. Dadurch läuft `swift test` in Sekunden ohne Simulator, und das CI-Gate bleibt schnell und verlässlich. Nur das App-Target braucht Xcode und einen Simulator.

### Modulgrenzen

**ZilpZalpCore** kennt weder SwiftUI noch Dateisystem noch Netzwerk. Es enthält:
- `Round` — erzeugt aus einer Artenmenge eine Runde aus 10 Fragen mit je vier Antwortoptionen, wobei die Ablenker zufällig, aber reproduzierbar über einen injizierten Zufallsgenerator gezogen werden
- `Scoring` — aus der Zahl der auf Anhieb richtigen Antworten die Sterne: ab 9 drei Sterne, ab 6 zwei, sonst einer; dazu die Zahl der Wiedererkennungen, die einen Sticker verdient (fünf)
- `RoundPlay` — der Verlauf einer Runde: welche Art auf Anhieb erkannt wurde, in welcher Reihenfolge, und welcher Vogel am Rundenende gefeiert wird
- `PlayBudget` — verbrauchte Spielzeit pro Tag und Profil gegen ein eingestelltes Limit

Reine Wertetypen und Funktionen. Vollständig testbar ohne Laufzeitumgebung.

**ZilpZalpData** kapselt alles, was den Zustand hält:
- `Bird`, `MediaAsset`, `Pack` als Codable-Modelle
- `PackCatalog` — liest das gebundelte Basis-Paket und die geladenen Pakete
- `PackDownloader` — lädt Pakete per URLSession aus S3, prüft SHA-256, entpackt nach Application Support
- `ProfileStore` — ein Actor über einer JSON-Datei; Profile, Sterne, Statistik, Wiedererkennungen je Art

Das Basis-Paket ist eine SwiftPM-Ressource von `ZilpZalpData`, kein Asset Catalog im App-Target: `PackCatalog.bundled()` öffnet es über `Bundle.module`, `photoURL(for:)` löst das Foto eines Vogels relativ zum Paketverzeichnis auf. `tools/sync_bundled_packs.py` spiegelt das Paketverzeichnis nach `Resources/Packs/` in `ZilpZalpData`, und `mise run check` schlägt bei Abweichung fehl. Ein Symlink funktioniert nicht — SwiftPM kopiert bei einer `.copy`-Ressource den Link selbst, nicht sein Ziel, sodass er im Bundle ins Leere zeigt.

**ZilpZalpUI** übersetzt das Design-System nach SwiftUI: Farb- und Typo-Tokens, `ZButton`, `ZCard`, `ChoiceTile`, `SoundButton`, `QuizProgress`, `FeedbackBanner`, `RewardSticker`, `HomeTile`, `SettingRow`. Nach den Komponenten unter `design/components/`, mit bewussten Abweichungen wie unten vermerkt. Komponenten bekommen fertige `String`-Werte übergeben und tragen selbst keine Produkttexte. Gesperrte Sticker in der Sammlung bleiben sichtbar — mit Schloss-Symbol statt versteckt, und darunter zeigt `StickerProgress` in fünf Markierungen, wie weit dieser Vogel gekommen ist (Entscheidung 2026-09-09, Issue #177). `HomeTile` kennt einen gesperrten Zustand mit Ei-Symbol als Komponentenfähigkeit, aber v1 setzt ihn auf dem Startbildschirm nicht ein: der besteht nur aus `TopBar` und den zwei Kacheln für Spiel 1 und Spiel 2, ohne Baum und ohne gesperrte Nester für Spiel 3 und 4. Dynamic Type ist bewusst fest: die Geometrie (220 pt Kacheln, 64/96/160 pt Bedienziele) skaliert nicht mit dem Text (Entscheidung 2026-09-07).

Die Sammlung stellt die gefundenen Vögel nach vorn und trägt den Namen des Kindes (Issue #204). Im Playtest standen die beiden erspielten Sticker in der dritten Reihe zwischen gesperrten, weil das Album die Manifest-Reihenfolge behielt — was ein Kind erspielt hat, ist aber der Grund, warum es das Album öffnet. `AlbumOrder.earnedFirst` in `ZilpZalpCore` stellt die gefundenen voran und lässt innerhalb beider Gruppen die Manifest-Reihenfolge stehen, damit ein Vogel morgen dort steht, wo er heute stand; generisch, weil Core kein Datenmodell kennt. Die Überschrift lautet „Johannas Sammlung" statt „Meine Sammlung" und trägt den Avatar des Profils davor (44 pt auf dem iPhone, 64 pt auf dem iPad): Mehrere Kinder teilen sich ein Gerät, und der Screen soll sagen, wessen Album offen ist. Den Genitiv bildet `GermanName.possessive` in `ZilpZalpCore` — ein angehängtes s, nach s, ß, x oder z stattdessen ein Apostroph („Hans’ Sammlung") —, und der String Catalog hält nur das Format `%@ Sammlung`, damit eine Sprache mit anderer Besitzanzeige den ganzen Satz umbauen kann. `collection.title` bleibt die Beschriftung des Buttons auf Startseite und Rundenende; die Überschrift bekommt einen eigenen Schlüssel. Der längste erlaubte Name (20 Zeichen, `ProfileCreationScreen`) bricht auf zwei Zeilen und skaliert notfalls auf 70 %, statt in die TopBar zu wachsen — dort steht die Überschrift ohnehin nicht. Die beiden Zähler „29 Vögel" und „129 Sterne" bleiben (Entscheidung 2026-09-10, Issue #204).

### Datenmodell

```swift
struct Bird: Codable, Identifiable {
    let id: String              // "amsel"
    let name: String            // "Amsel"
    let scientificName: String  // "Turdus merula"
    let taxonID: Int            // iNaturalist 12716
    let article: String         // "die" — für "Wo ist die Amsel?"
    let pronunciation: String?  // Lautschrift-Override für AVSpeechSynthesizer, meist nil
    let photo: MediaAsset
    let call: MediaAsset?       // null, solange kein freier Ruf vorliegt
}

struct MediaAsset: Codable {
    let file: String            // "photos/amsel.png"
    let sha256: String
    let license: License        // .cc0 | .ccBy | .ccBySa — Rohwerte "CC0-1.0" | "CC-BY-4.0" | "CC-BY-SA-4.0"
    let attribution: String     // "Alexis Tinker-Tsavalas"
    let sourceURL: URL          // Beobachtung bzw. Aufnahme
    let retrieved: Date         // Tag der Kuration, Beleg für den Lizenzstand
}

struct Pack: Codable, Identifiable {
    let id: String              // "deutschland"
    let title: String           // "Vögel Deutschlands"
    let birds: [Bird]
}
```

`data/packs/<id>/manifest.json` je Paket ist die einzige Wahrheit. Aus ihr entstehen zur Build-Zeit sowohl die Assets als auch der Credits-Screen. Attribution kann dadurch nicht von den Assets abdriften. Ob ein Paket gebundelt ist, erkennt der Katalog daran, woher er es geladen hat — `Pack` braucht dafür kein eigenes Feld; `downloadSize` steht ausschließlich in `packs/index.json`.

Das Profilbild eines Kindes ist ein Vogelfoto aus dem mitgelieferten Paket (Issue #205). `Profile.avatar` bleibt ein String, jetzt aber eine Art-ID: Die zehn Vögel, die die Profilanlage anbietet, stehen als `Profile.avatarChoices` im Datenmodul, und ein Test hält sie mit dem gebundelten Manifest in Deckung. Gezeichnet wird die Scheibe, die das Album einem gesammelten Sticker gibt — dieselbe Form wie die Kollektionen (#187), gerade statt gekippt, das gewählte Bild mit Ring und Häkchen (#189). Vorher waren es acht Lucide-Piktogramme; ein Kind hat dazu „Das sind keine Vögel" gesagt (#193), und der Playtest vom 10.09. hat es bestätigt. Die acht alten Namen bilden im Datenmodul fest auf je einen Vogel ab (`Profile.species(forAvatar:)`, ohne Simulator getestet), damit ein Profil auf einem TestFlight-Gerät sein Gesicht behält — `star` braucht keinen Eintrag, weil der Star ohnehin so heißt. Kein Schema-Bump, keine Migration: Die Datei bleibt, wie sie ist, bis das Kind selbst ein neues Bild wählt. Ein Name, den dieser Build nicht kennt, zeigt weiterhin das Vogel-Piktogramm auf sandfarbener Scheibe. Eigene Illustrationen (#45) und Zubehör darauf (#77) bleiben offen und erben dasselbe Feld (Entscheidung 2026-09-10, Issue #205).

### Medien-Pipeline

```
data/packs/<id>/manifest.json ──> tools/fetch-media ──> Scaleway S3 (zilpzalp-media, fr-par)
                                                             │
                     Basis-Paket ────────────────────────────┼──> SwiftPM-Ressource (ZilpZalpData) ──> App-Bundle
                     Download-Pakete ────────────────────────┴──> zur Laufzeit per PackDownloader
                                                             │
                     tools/generate_credits.py ──────────────┴──> Credits-Screen + CREDITS.md
```

`fetch-media` spricht iNaturalist und xeno-canto **nur zur Kurationszeit** an, niemals die App zur Laufzeit. Das löst gleich mehrere Probleme: keine Rate-Limits im Betrieb, keine verschwindenden Fremd-URLs, geprüfte Lizenzen, gleichbleibende Bildqualität und volle Offline-Fähigkeit.

`tools/generate_credits.py` läuft als Teil von `mise run check`, schreibt `CREDITS.md` und `credits.json` (Letzteres als weitere Ressource in `ZilpZalpData` gebündelt, für den In-App-Credits-Screen) und schlägt bei Abweichung fehl. Die Credits umfassen neben den Medien auch die Fonts (OFL) und die Icons (Lucide, ISC — mit einzelnen Icons aus Feather, MIT).

Ein CI-Gate bricht den Build ab, sobald ein Asset eine Lizenz außerhalb von CC0/CC BY/CC BY-SA trägt oder Attribution fehlt.

### Paket-Download

Der Bucket `zilpzalp-media` liegt bei Scaleway Object Storage in `fr-par`, Endpunkt `s3.fr-par.scw.cloud`, Inhalte öffentlich lesbar. Schreibzugriff hat nur `tools/fetch-media` mit Zugangsdaten aus Infisical. Öffentlich lesbar ist die richtige Wahl, weil es ausschließlich CC-lizenzierte Dateien sind — signierte URLs würden entweder einen Schlüssel in der App oder einen eigenen Dienst erzwingen, und beides ist für eine App ohne Backend der falsche Weg.

Die App holt beim Start des Elternbereichs einen Katalog (`packs/index.json`) aus S3 und zeigt verfügbare Pakete mit Größe an. Ein Download läuft über `URLSession` mit Fortschrittsanzeige, prüft jede Datei gegen ihren SHA-256 und legt sie unter Application Support ab, ausgenommen vom iCloud-Backup. Pakete sind einzeln löschbar. Das gebundelte Basis-Paket lässt sich nicht entfernen, damit die App nie inhaltsleer wird.

Neue Pakete können dadurch ohne App-Update und ohne Review ausgeliefert werden — der Grund, warum wir nicht Apples On-Demand Resources nehmen.

Die Umsetzung (Entscheidung 2026-09-10, Issue #34) weicht in drei Punkten ab. Der Katalog wird geholt, sobald die Paketkarte im Elternbereich erscheint — also hinter dem Schloss, nicht beim Öffnen des Bereichs, damit die einzige Netzverbindung der App zwei Türen tief liegt. Die Spiele lesen nicht mehr ein Paket, sondern eine `PackLibrary` aus Basispaket und allen installierten Paketen; eine Art, die zweimal vorkommt, zählt einmal, und das Basispaket gewinnt. Belegter Speicher wird aus den Dateien gemessen (`.fileSizeKey`, kein Datumsschlüssel), nicht aus der Größe im Index — heruntergeladen wurde vielleicht eine ältere App-Version, und der Index ist genau dann unerreichbar, wenn jemand Platz schaffen will.

Das gebundelte Paket ist „Vögel Deutschlands" mit 70 Arten; das frühere Zehn-Arten-Paket `basis` ist darin aufgegangen und gelöscht (Entscheidung 2026-09-10, Christian und Johanna, Issue #192). Zehn Arten waren zu wenige — ein Kind lernt dann die Bilder statt der Vögel. Weil das Paket vorher aus dem Bucket geladen werden konnte, tragen manche Geräte eine Installation unter derselben ID wie das gebundelte Paket: `PackDownloader.installations()` übergeht sie und löscht ihre Dateien, sonst stünde dasselbe Paket zweimal in der Kollektionsauswahl und im Elternbereich mit Löschknopf. `packs/index.json` nennt das gebundelte Paket nicht mehr, die Objekte unter `packs/deutschland/` bleiben im Bucket liegen.

---

## 4. Spielablauf

Beide Spiele nutzen dieselbe Engine, sie unterscheiden sich nur darin, wie die Frage gestellt wird.

1. Kind wählt sein Profil, dann ein Spiel
2. Zehn Fragen. Pro Frage: Aufgabe wird ausgegeben — Spiel 1 liest Artikel und Namen (mit `pronunciation`-Override, wo hinterlegt) per `AVSpeechSynthesizer` vor, Spiel 2 spielt den Ruf ab, wiederholbar per Tippen
3. Vier Fotokacheln. Richtige Wahl färbt sich olivgrün mit Häkchen, falsche Wahl färbt sich sonnengelb mit „Versuchs nochmal" — **niemals rot, niemals ein Kreuz, kein Blockieren**. Das Kind darf weiter probieren. Die Kacheln zeigen nie den Vogelnamen als Text. Auf dem iPad stehen sie im 2×2-Raster, nicht in der einen Reihe des Design-Exports — Issue #25, Task 15 des Plans und die Umsetzung sind sich darin einig; Grund sind Kachelgröße und Bedienziele auf 11-Zoll-iPads in beiden Ausrichtungen. Ob die Frage neben dem Raster oder darüber steht, wird am tatsächlich verfügbaren Platz gemessen statt an der Größenklasse — auf dem iPad im Hochformat steht sie deshalb darüber (Issue #118). Das iPhone läuft nur noch im Hochformat: quer bleiben für Frage, Antworten und Rückmeldung 718×216 pt, und die größte Kachel, die daraus zu holen ist, misst 83 pt (Issue #117)
4. Nach zehn Fragen: Sterne und der Weg zum nächsten Sticker. Ränge und Vogel-Leiter sind abgeschafft; einen Sticker gibt es, wenn ein Kind denselben Vogel **fünfmal auf Anhieb erkannt** hat — nach einem Fehlversuch gefunden zählt nicht, denn unter vier Kacheln findet man die richtige immer irgendwann. Unter dem gefeierten Vogel stehen fünf Markierungen, so weit gefüllt, wie der Zähler steht; die fünfte ist der neue Sticker und wird gefeiert wie früher der erste Fund. Gefeiert wird der Vogel, dessen Sticker in dieser Runde vollständig wurde, sonst der, der einem Sticker am nächsten gekommen ist (Entscheidung 2026-09-09, Christian und Johanna, Issue #177). Am Rundenende sind verdiente Sterne ausgefüllt und nicht verdiente nur umrandet: `RewardScreen.jsx` zeichnet dort drei gleiche gefüllte Kreise und unterscheidet verdient und nicht verdient überhaupt nicht, die Umriss-Sterne aus `HomeTile.jsx` unterscheiden nur über die Farbe — beides kann ein Kind, das nicht liest, nicht zählen (Entscheidung 2026-09-08, Issue #149). Die Überschrift „Super gemacht!" schrumpft so weit, wie sie zu breit ist, statt abgeschnitten zu werden — auf einem 390-pt-iPhone fehlen ihr 1,2 pt; Untergrenze ist `--text-title`, auf dem iPad im Vollbild bleibt die Zeile bei `--text-hero`, und der Design-Export zeichnet mit „Gut gemacht!" eine kürzere Überschrift und kein Telefon (Entscheidung 2026-09-09, Issue #137)

Eine laufende Runde verlässt der Zurück-Pfeil der `TopBar` nicht mehr sofort, sondern stellt zuerst die gesprochene und geschriebene Frage „Willst du aufhören?" über der abgedunkelten Runde: Die große, primäre Antwort ist „Weiterspielen", ein Tippen neben die Karte zählt genauso, nur „Aufhören" beendet die Runde, und die Wischgeste von links stellt dieselbe Frage, statt die Runde zu verlassen — für die abgeschlossene Runde und für „Zeit fürs Nest" ändert sich nichts (Entscheidung 2026-09-08, Issue #146).

Von links hereinwischen geht überall dort zurück, wo ein Zurück-Pfeil steht, und tut genau das, was er tut; in der laufenden Runde stellt es die Frage darüber. Ausgenommen sind Rundenende und „Zeit fürs Nest": Dort bleibt die Geste aus, weil dort kein Pfeil steht (Entscheidung 2026-09-08, Issue #150).

Das Kind wählt auf der Startseite, welche Vögel seine Runden fragen (Issue #187). Seit dem Paket-Download (#34) spielen alle installierten Pakete zusammen — mit Deutschland, Welt und Afrika sind das 131 Arten, und wer „die Vögel aus Afrika" wollte, konnte nicht danach fragen. Die Wahl ist ein Profilfeld (`collection`, leer heißt alle Vögel), gehört also dem Kind und wandert mit dem Profilwechsel; ein Paket, das im Elternbereich gelöscht wird, fällt stillschweigend auf „Alle Vögel" zurück, ohne die Wahl zu überschreiben. Auf der Startseite steht dafür **eine Pille** zwischen Überschrift und Spielkacheln — Foto der Kollektion und ihr Name, 64 pt hoch — und darüber öffnet sich die Auswahl als Karte über der abgedunkelten Startseite. Keine Reihe von Kollektionen: Fünf Einträge brauchen bei 96 pt Durchmesser 480 pt, ein 390-pt-iPhone lässt zwischen seinen Gutters 294 pt, und damit bliebe nur Scrollen (versteckte Inhalte für ein Kind, das nicht liest) oder Kreise unter der 64-pt-Grenze. Aus den Tokens gerechnet kostet die Pille auf einem 390-pt-iPhone rund 40 pt Kachelgröße und auf dem iPad nichts (auf einem 440-pt-iPhone und dem 13-Zoll-iPad im Simulator nachgesehen); beide Spiele bleiben überall ohne Scrollen sichtbar. Jeder Eintrag ist ein rundes Foto des ersten Vogels seines Manifests mit dem Titel darunter — „Alle Vögel" trägt das Vogel-Piktogramm, weil der erste Vogel der Bibliothek derselbe Amsel ist wie der des Basispakets —, der gewählte Eintrag trägt Ring **und** Häkchen, und ein Tippen spricht den Namen. Spiel 2 folgt der Wahl: Es erscheint nur, wenn die gewählte Kollektion mindestens vier Arten mit Ruf hat; eine Kollektion mit weniger als vier Arten wird gar nicht erst angeboten. Ist nur ein Paket installiert, gibt es nichts zu wählen und die Startseite sieht aus wie vorher. Sticker, Sterne und Sammlung bleiben global — die Kollektion entscheidet nur, wonach eine Runde fragt (Entscheidung 2026-09-10, Issue #187).

Das Rundenende bekommt links oben ein Haus zur Startseite (Issue #175). Im Design ist 1d ein Endbild, in der App liegt es auf dem `NavigationStack`, und beide Buttons darunter führen weiter hinein — wer aufhören oder das iPad weitergeben wollte, kam nur über eine weitere Runde heraus. Es ist ein wortloser Icon-Button an der Stelle, an der jeder andere Screen seinen Zurück-Pfeil hat, und keine dritte Pille neben „Nochmal spielen" und „Sammlung": Der Screen scrollt nicht, und auf einem 375-pt-iPhone geht die Höhe dafür nicht auf. Eine `TopBar` bekommt 1d weiterhin nicht, und die Wischgeste bleibt aus — das Haus führt nicht zurück, sondern ganz heraus, und es öffnet erst, wenn die Runde verbucht ist (Entscheidung 2026-09-09, Issue #175).

Der Blätter-Fortschritt zeigt den Stand ohne Zahlen. Auf dem iPhone sitzt die Blätterreihe unter der TopBar statt wie im Design darin: Zehn 44-pt-Blätter mit 12 pt Abstand sind 548 pt breit — breiter als jedes iPhone. Bei erschöpftem Zeitbudget läuft die aktuelle Runde noch zu Ende, danach erscheint „Zeit fürs Nest".

Auch die `TopBar` weicht auf dem iPhone ab: Sie nutzt den Bildschirm-Gutter `--space-4` (16 pt) statt des iPad-`--gutter-screen` (48 pt), denn bei 375 pt blieben der Mitte neben zwei 64-pt-Buttons und zwei 24-pt-Abständen nur 103 pt, während „Für Erwachsene" 114,5 pt braucht — mit 16 pt sind es 167 pt (Issue #93). Ihre Titelzeile misst dabei die Schriftgröße selbst (60-pt-Bar, `--text-headline/1` aus dem JSX), nicht die Zeilenhöhe der Headline-Stufe.

Ebenso weicht `SettingRow` auf dem iPhone ab: Unterhalb der Regular-Größenklasse stehen Symbol und Titel in einer Zeile, der Hinweis darunter über die ganze Textspalte und der Wert entweder am Ende der Titelzeile oder — wenn beide zusammen nicht in eine Zeile passen — in einer eigenen Zeile am rechten Rand. Der Bereich hinter dem Schloss nutzt dazu denselben 16-pt-Gutter wie die `TopBar`. Mit den iPad-Spalten hinter dem iPad-Gutter blieben „Spielzeit pro Tag" auf einem 390-pt-iPhone 53,6 pt Textspalte statt der 155,8 pt, die der Titel braucht — vier Zeilen, und der Hinweis mitten im Wort getrennt. Die Wahl ist eine reine Funktion aus Größenklasse und den beteiligten Breiten (`SettingRowLayout.choose`), gemessen wird sie im Layout selbst; der Schalter einer Schalter-Zeile bleibt in der Hand von `Toggle` und bekommt niemals eine eigene Zeile, und auf dem iPad bleiben die drei Spalten des Designs (Entscheidung 2026-09-10, Issue #142).

Der Bereich hinter dem Schloss heißt in der Oberfläche „Einstellungen" statt „Für Erwachsene" — es sind die Einstellungen der App, und genau das Wort kennt jeder vom Gerät. Der Titel steht in der `TopBar` und ist gleichzeitig die VoiceOver-Beschriftung seiner Tür auf der Startseite; im Code bleibt alles `parents.*`, und der FaceID-Zwecktext nennt weiterhin den „Elternbereich", weil er erklärt, wer aufschließt, nicht wohin es führt. Der kürzere Titel braucht in der Bar 172,7 pt statt 200,4 pt (Entscheidung 2026-09-10, Christian, Issue #142).

„Zeit fürs Nest" (Screen 1k) weicht in drei Punkten vom Design ab (Issue #36). Der Screen bekommt einen Button „Zum Nest" zurück zur Startseite: Im Design ist 1k ein Endbild, in der App ist es ein Ziel im `NavigationStack` und braucht einen Ausgang — eine `TopBar` bekommt es trotzdem nicht, denn hinter ihm liegt entweder eine abgeschlossene Runde oder die Startseite, und in beides führt kein Weg zurück. Der Tagesertrag steht als Badge wie im Design („7 Sterne heute"); der ganze Satz „Heute hast du 7 Sterne gesammelt" wird stattdessen **gesprochen**, weil ein Kind, das nicht liest, ihn sonst gar nicht bekäme und ein Satz in einem Badge nicht umbricht. Die Startseite bekommt keine Zeitanzeige: Die Screens 1a und 1b haben keine, 1k ist der einzige Ort für das Budget, und ein Countdown ist genau das, was das Issue ausschließt.

**Sprachausgabe:** `AVSpeechSynthesizer` mit `de-DE` direkt auf dem Gerät. Kein Audio-Asset, keine Lizenzfrage, keine Netzabhängigkeit. Der Klickprototyp macht es mit der Web Speech API bereits genauso. Die Sprachausgabe lässt sich in v1 nicht abschalten — ohne sie hätte Spiel 1 für noch nicht lesende Kinder keine Aufgabenstellung. Spiel 2 erscheint auf der Startseite nur, wenn es auch spielbar ist — mindestens vier Arten des Pakets mit Ruf; sonst fehlt seine Kachel, wie die von Spiel 3 und 4, statt gesperrt oder ohne Rufe angeboten zu werden (Issue #31). Einen Schalter „Vogelstimmen" gibt es nicht: Sind Rufe da, ist Spiel 2 da, und wer Ruhe will, nutzt die Gerätelautstärke (Entscheidung 2026-09-08, Issue #138). Die Audiosession (`AVAudioSession`, Kategorie `.playback`) wird vom Sprachdienst konfiguriert und vom Rufe-Player mitgenutzt, damit beide auch bei umgelegtem Stummschalter hörbar bleiben.

---

## 5. Datenhaltung und Datenschutz

Alles liegt lokal. Kein Netzwerkverkehr außer den ausdrücklich von Eltern angestoßenen Paket-Downloads aus dem eigenen S3-Bucket. Keine Analytics, kein Crash-Reporting durch Dritte, keine Werbe-SDKs, keine Accounts.

Profile liegen als JSON in Application Support:

```
Profiles/profiles.json      Name, Avatar, Sterne, Statistik, Wiedererkennungen je Art
Packs/<pack-id>/            Heruntergeladene Pakete
Settings/parental.json      Zeitbudget, ob FaceID aktiv ist
```

Kein Passwort im Klartext. Der Elternbereich nutzt `LAContext` mit `deviceOwnerAuthentication`, was automatisch auf den Geräte-Code zurückfällt, wenn keine Biometrie vorhanden ist — dieses Schloss schützt nur den Zugang zum Elternbereich selbst; externe Links bekommen ein eigenes Gate, siehe Abschnitt 7. Auf „Designed for iPad"-Macs muss dieser Fallback geprüft werden.

Abstürze werden ausschließlich über Apples eigenes MetricKit und den Xcode Organizer sichtbar. Das ist in der Kids Category der einzig saubere Weg.

---

## 6. Testkonzept

| Ebene | Werkzeug | Umfang |
|---|---|---|
| Logik | Swift Testing (`@Test`) in SwiftPM | Rundenerzeugung, Scoring, Wiedererkennungen und Sticker-Schwelle, Zeitbudget, Manifest-Parsing, SHA-Prüfung |
| Lizenz-Gate | eigenes Tool in CI | Jedes Asset hat erlaubte Lizenz und Attribution |
| Snapshot | Xcode-Previews, manuell | Design-Komponenten gegen `design/` |
| Integration | XCTest im Simulator, sparsam | Ein Durchlauf pro Spiel, Profilanlage, Paket-Download gegen einen lokalen Server |

Bewusst wenige Simulator-Tests. Ein instabiles Gate auf einem self-hosted Runner wird binnen einer Woche abgeschaltet — dann ist gar nichts gewonnen.

---

## 7. Kids Category — Konsequenzen

Die Wahl der Kids Category ist keine reine Metadaten-Entscheidung, sie bindet die Umsetzung:

- **Keine Third-Party-Analytics und kein Third-Party-Crash-Reporting.** Kein Sentry, kein Firebase. Nur MetricKit
- **Externe Links brauchen ein Parental Gate.** Betrifft den öffentlichen Screen „Über ZilpZalp" und die von ihm geöffneten Credits: Datenschutz-, Web- und Mail-Link ebenso wie die Quellenlinks zu iNaturalist, xeno-canto und den Lizenztexten dürfen nicht ohne Erwachsenen-Prüfung öffnen. Umsetzung: Credits zeigen Namen und Lizenz immer im Klartext, der Link selbst öffnet erst nach einer eigenständigen Erwachsenen-Aufgabe (Rechen- oder Frageaufgabe mit Sprachhinweis) — getrennt vom `LAContext`-Schloss des Elternbereichs, das nur dessen Zugang schützt (Guideline 1.3, siehe `docs/kids-category.md`). Die Credits liegen bewusst *nicht* hinter diesem Schloss: die Attribution, die CC BY 4.0 §3(a)(2) verlangt, muss ohne Gerätecode erreichbar sein (#199)
- **Privacy Manifest** (`PrivacyInfo.xcprivacy`) ist Pflicht und deklariert: keine Datenerhebung
- **Datenschutzerklärung** muss verlinkt sein — als statische Seite, nicht in der App klickbar ohne dasselbe Aufgaben-Gate. Der Link steht auf „Über ZilpZalp"
- Werbung, In-App-Käufe und Verhaltens-Targeting entfallen ohnehin

Die Wortlaute der Guidelines 1.3, 5.1.4 und 2.3.8 sind gegen die aktuelle Fassung geprüft, siehe `docs/kids-category.md` (#19, abgeschlossen in M2). Offen bleiben die technischen Umsetzungen: das Aufgaben-Gate für externe Links (#37) und die Altersfreigabe-Einstellungen in App Store Connect (#41); sie blockieren die Entwicklung bis dahin nicht.

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
| M4 | Profile und Fortschritt | Profilwahl, Avatare, ~~Ränge~~ (2026-09-09 abgeschafft, #177), Sammlung, Leaderboard „Unser Schwarm" |
| M5 | Spiel 2 und Pakete | Vogelrufe, Audio-Player, Paket-Download, Elternbereich mit Schloss, Paketverwaltung |
| M6 | Eltern und Compliance | Zeitbudget, Parental Gate, Privacy Manifest, Age Rating |
| M7 | Release | Signing, TestFlight, Store-Assets, „Designed for iPad" auf Mac |
| M8 | Danach | Spiel 3 Federn, Spiel 4 Lebensraum, weitere Pakete, Englisch |

M0 bis M2 sind Fundament und lassen sich weitgehend parallel bearbeiten. Ab M3 baut jeder Meilenstein auf dem vorherigen auf.

M0 ist am 2026-09-07 mit dem Secrets-Smoke-Workflow (#6) abgeschlossen. Dass die Komponenten aus M1 erst nach dem Start von M2 landeten, ist eine bewusste Entscheidung aus dem Plan vom 2026-09-07: drei Stränge — Komponenten, Datenschema, Spiellogik — laufen dort parallel, keiner hängt an einer offenen Entscheidung.

Die Recherche zu den App-Review-Guidelines liegt bewusst schon in M2 und nicht erst in M6: der Paket-Downloader in M5 erzeugt ausgehenden Netzverkehr, und `PrivacyInfo.xcprivacy` erklärt gleichzeitig, dass keine Daten erhoben werden. Inhalte abrufen ist aller Voraussicht nach keine Datenerhebung — aber das ist eine Aussage in einer verpflichtenden Erklärung, und sie sollte belegt sein, bevor der Netzwerkcode entsteht, nicht danach.

---

## 10. Offene Punkte

Diese Fragen sind bewusst offen und blockieren den Start nicht:

1. **CC BY-SA bei zugeschnittenen Audios.** Schneiden wir eine BY-SA-Aufnahme auf wenige Sekunden zu, entsteht ein Bearbeitungswerk, das unter derselben Lizenz stehen muss. Für die Audiodateien ist das unproblematisch — sie bleiben BY-SA, der Code bleibt MIT. Ob das Zusammenspiel mit den App-Store-Bedingungen und deren technischen Schutzmaßnahmen sauber ist, muss ein Mensch beurteilen. Ausweg, falls nötig: nur CC0- und CC-BY-Aufnahmen verwenden. Weiterhin offen; blockiert M3 nicht, weil das Basis-Paket nur CC-BY-Fotos und keine Rufe enthält
2. **Qualität der Vogelrufe.** Die Verfügbarkeit ist belegt — alle vierzig geprüften Arten haben frei lizenzierte Aufnahmen. Offen ist die inhaltliche Eignung: viele Aufnahmen sind Flügelschläge, Bettelrufe oder nächtliche Flugrufe statt des typischen Gesangs. Jede Aufnahme muss vor Aufnahme ins Paket angehört werden. Wartet auf `tools/fetch-media` für Rufe (#16) und das manuelle Anhören (#32). Entscheidung 2026-09-08 (Christian, #32): Für die zehn Rufe des Basis-Pakets tritt das Anhören im Spiel an die Stelle des Anhörens vorab. Ausgewählt wurden sie nach den xeno-canto-Metadaten und einer einmaligen Messung des Signalverlaufs im PR — nicht durch `fetch-media`, das nichts misst. Eine Aufnahme, die im Spiel durchfällt, wird per `fetch-media calls pick` ausgetauscht
3. **Habitat-Zuordnung für Spiel 4** muss selbst erarbeitet und belegt werden. Ein systematisches Übernehmen der Kategorisierung von NABU oder LBV berührt das Datenbankrecht nach §87a UrhG. Unverändert, erst in M8 relevant
4. ~~**Wortlaut der App-Review-Guidelines** zu Kids Category und Altersfreigabe ist gegen die aktuelle Fassung zu verifizieren~~ — erledigt, siehe `docs/kids-category.md` (#19). Offen bleiben die technischen Umsetzungen: das Aufgaben-Gate für externe Links (#37) und die Altersfreigabe-Einstellungen in App Store Connect (#41)
5. **Artenliste** ist eine inhaltliche Entscheidung, die Christian und Johanna treffen — nicht eine technische. Ein Vorschlag (#21) ist in Arbeit. Die Rangleiter ist damit erledigt: sie ist abgeschafft, an ihrer Stelle steht der Sticker nach fünf Wiedererkennungen (Entscheidung 2026-09-09, Christian und Johanna, Issue #177)
6. **`.playback` vs. `.duckOthers` für die Audiosession.** Die Sprachausgabe (#24) nutzt zurzeit `.playback` ohne Ducking — das unterbricht Eltern-Musik im Hintergrund vollständig, und da die Session nie deaktiviert wird, bekommt die Musik kein Fortsetzen-Signal. `.duckOthers` würde nur absenken, verlangt dafür ein Session-Lebenszyklus-Management, das mit dem Rufe-Player (#30) geteilt werden muss. Offen; keine einseitige Entscheidung in #24

---

## 11. Erfolgskriterien für v1

- Ein Kind kann ohne Lesefähigkeit und ohne Hilfe eine Runde spielen
- Die App startet ohne Netzverbindung und ist mit dem gebundelten Basis-Paket vollständig spielbar. Nur das Laden zusätzlicher Pakete braucht einmalig Netz
- Die Credits nennen für jedes Medium Urheber und Lizenz, automatisch aus dem Manifest erzeugt — auf dem Credits-Screen und nicht in den Fotos selbst (Entscheidung 2026-09-10, Issue #200)
- Ein Fremder kann das Repo klonen, `mise run setup` ausführen und die App bauen
- Das CI-Gate ist grün und schnell genug, dass niemand es umgehen will
- Kein Byte verlässt das Gerät außer beim ausdrücklich angestoßenen Paket-Download
