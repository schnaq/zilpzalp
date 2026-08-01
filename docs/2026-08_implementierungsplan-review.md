# Review des Implementierungsplans — 2026-08-01

Prüfung des v1-Plans ([Spec](superpowers/specs/2026-08-01-zilpzalp-v1-design.md) plus die 48 Issues in den Milestones M0–M8) auf Lücken, Widersprüche und Reihenfolge-Probleme. Alle Befunde sind bereits in die Issues eingearbeitet; dieses Dokument hält fest, was gefunden wurde und warum die Änderungen so ausfielen.

Gesamturteil vorab: Der Plan ist solide geschnitten. Die Platzierung der Guidelines-Recherche in M2, die dokumentierten API-Fallen von xeno-canto und iNaturalist und die generierten Credits als Lizenzmaßnahme sind Stärken, an denen nichts zu ändern war.

## Befunde und Anpassungen

### 1. Paketverwaltung brauchte ein Schloss, das erst einen Milestone später existierte

Die Paketverwaltung (#34, M5) liegt laut eigenem Text „hinter dem FaceID-Schloss", aber der Elternbereich mit `LAContext`-Schloss (#35) lag in M6. **Anpassung:** #35 nach M5 verschoben; Milestone-Beschreibungen von M5 und M6 sowie die Tabelle in Abschnitt 9 des Spec nachgezogen. Zeitbudget, Parental Gate und Privacy Manifest bleiben in M6.

### 2. Rundenende in M3 hing von Bausteinen aus M4 ab

Das Rundenende (#26, M3) zeigte Sticker-Vergabe und einen Button „Sammlung" — `ProfileStore` (#27) und Sammlung (#29) entstehen aber erst in M4. **Anpassung:** #26 grenzt jetzt ab: In M3 werden nur die Sterne der Runde angezeigt, Persistenz und Sammlung-Verdrahtung folgen in M4, keine Wegwerf-Persistenz. M3 läuft mit implizitem Einzelprofil (festgehalten in #49).

### 3. Stummschalter-Problem bestand schon in M3, war aber erst in M5 adressiert

Die Audio-Session-Konfiguration gegen den umgelegten Stummschalter lag beim Audio-Player (#30, M5). `AVSpeechSynthesizer` in Spiel 1 (M3) ist genauso betroffen — ein stummes Spiel 1 ist für Nichtleser unbrauchbar. **Anpassung:** `AVAudioSession` mit Kategorie `.playback` gehört zu #24 (M3); #30 nutzt dieselbe Konfiguration.

### 4. Spiel 2 konnte die Runde nicht immer füllen

Drei Regeln kollidierten: Runden haben 10 Fragen ohne Artwiederholung (#22), Spiel 2 überspringt Arten ohne Ruf (#31), und das Basis-Paket hat genau 10 Arten, davon zwei mit ungeklärtem Ruf (#32). Ohne Zusatzpaket wären womöglich nur 8 Arten im Fragenpool. **Anpassung:** Kleiner-Pool-Regel in #22 — die Runde bleibt bei 10 Fragen, bei weniger als 10 geeigneten Arten sind Wiederholungen erlaubt (möglichst spät), unter 4 Arten wird das Spiel nicht angeboten. Ruflose Arten bleiben in Spiel 2 als Ablenker-Fotos zulässig (#31). Damit bleibt die Sterne-Logik in #23 (Schwellen 9 und 6 von 10) unverändert gültig.

### 5. Ein Schalter „Vogelstimmen" hätte Spiel 1 abschaltbar gemacht

#24 und #30 hingen beide an der Einstellung „Vogelstimmen". Schalten Eltern sie aus, verliert Spiel 1 seine Aufgabenstellung — für Kinder ohne Lesefähigkeit wäre die App unbrauchbar. **Anpassung:** Die Sprachausgabe ist in v1 nicht abschaltbar; „Vogelstimmen" betrifft nur die Rufe (#24, #30, #35).

### 6. Settings ohne Feature dahinter

Der Elternbereich (#35) listete „Musik" und „Sprache". Es gibt in v1 weder Musik noch eine zweite Sprache. **Anpassung:** Beide bewusst gestrichen — „Musik" käme höchstens mit den Bedienklängen (#45) zurück, „Sprache" mit der englischen Lokalisierung (#46). Abweichung vom Design ist beabsichtigt und im Issue begründet.

### 7. Kein Issue für den Home-Screen

HomeTile existierte als Komponente (#12), der Quiz-Screen als Issue (#25) — aber kein Issue baute den Startbildschirm mit Baum, Spielauswahl, gesperrten „Kommt bald ins Nest"-Nestern und Navigation. M3 heißt „erste spielbare Fassung"; ohne Shell führt kein Weg ins Spiel. **Anpassung:** Neues Issue #49 (M3).

### 8. Niemand erzeugte `packs/index.json`

#14 definiert die Bucket-Struktur mit dem Index, #33 liest ihn — kein Schritt erzeugte ihn. **Anpassung:** Neues Issue #50 (M2): Index wird aus `data/packs/*.json` generiert, Upload als letzter Schritt von `mise run fetch-media`, das gebündelte Basis-Paket erscheint nicht darin.

### 9. Integrationstests aus dem Spec waren keinem Issue zugeordnet

Abschnitt 6 des Spec nennt eine sparsame XCTest-Ebene (ein Durchlauf pro Spiel, Profilanlage, Download gegen lokalen Server). **Anpassung:** Neues Issue #51 (M7) — bewusst wenig, aber nicht null.

### 10. CI-Schritt vor dem Werkzeug, das er aufruft

Der CI-Workflow (#4, M0) enthält den Lizenz-Gate-Schritt, das Gate-Werkzeug entsteht erst in M2 (#17). **Anpassung:** #4 definiert den Schritt bis dahin als ausdrücklich markierten Skip mit `::notice::`; sobald das Werkzeug existiert, ist sein Fehlen ein Fehler.

### 11. Kleinere Präzisierungen

- **#17** — Die SHA-256-Prüfung des Gates gilt nur für Assets im Repo bzw. App-Bundle. Für reine S3-Assets prüft `tools/fetch-media` beim Upload; CI lädt nicht bei jedem Lauf Medien aus S3
- **#22** — Ablenker-Unterscheidbarkeit („nicht drei Meisen") bekommt eine Datenbasis: die Gattung, abgeleitet aus dem ersten Wort des `scientificName`. Kein neues Schemafeld
- **#27** — „aktueller Rang" wird nicht gespeichert, sondern aus den Gesamtsternen über `RankLadder` abgeleitet. Ein Feld weniger, eine Inkonsistenzquelle weniger
- **#2** — String Catalog von Anfang an, alle UI-Texte in `Localizable.xcstrings`. Die englische Lokalisierung (#46) hängt daran

## Nicht angefasst

- Scoring-Schwellen (#23) — bleiben durch die Kleiner-Pool-Entscheidung in Befund 4 gültig
- Paket- und Artenschema (#13) — die Gattungsableitung braucht kein neues Feld
- Milestone-Zuschnitt M0–M2 parallel, ab M3 sequenziell — trägt weiterhin
