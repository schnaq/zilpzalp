# AGENTS.md

Leitfaden für KI-Coding-Agenten in diesem Repository (Claude Code, Copilot, Cursor und andere). Menschen dürfen ebenfalls mitlesen — hier steht, wie in diesem Projekt gearbeitet wird.

## Was ZilpZalp ist

Eine quelloffene Lern-App, mit der Kinder heimische Vögel kennenlernen. Vier Spielarten, lokale Profile, kein Account, keine Werbung, keine Datenerhebung. iPhone und iPad nativ, auf Apple-Silicon-Macs über „Designed for iPad" lauffähig.

Die verbindliche Spezifikation liegt in [docs/superpowers/specs/2026-08-01-zilpzalp-v1-design.md](docs/superpowers/specs/2026-08-01-zilpzalp-v1-design.md). Bei Widersprüchen zwischen dieser Datei und dem Spec gewinnt der Spec.

## Grundregeln

1. **Plan vor Code.** Bei allem, was mehr als eine Datei berührt, erst den Plan vorlegen und abstimmen. Nicht drauflosbauen.
2. **Einfachheit gewinnt.** Die kleinste Lösung, die das Problem wirklich löst. Keine Abstraktion auf Vorrat.
3. **Chirurgische Änderungen.** Nur anfassen, was zur Aufgabe gehört. Kein Refactoring nebenbei, keine Umformatierung fremder Dateien.
4. **Verifizieren statt behaupten.** „Fertig" erst sagen, wenn `mise run check` durchgelaufen ist und die Ausgabe gesehen wurde. Kein „sollte jetzt funktionieren".
5. **Kein toter Code.** Nichts auskommentiert liegen lassen, keine ungenutzten Hilfsfunktionen für später.
6. **Zielgruppe mitdenken.** Die App ist für Kinder, die noch nicht lesen können. Jede UI-Entscheidung an dieser Messlatte prüfen.

## Sprache

Alles, was ins Repository geht, ist **englisch**: Code und Bezeichner, Kommentare, Commit-Messages, PR-Texte und Entwickler-Dokumentation. Auch dann, wenn die Absprache darüber auf Deutsch lief.

**Produktinhalte bleiben deutsch.** Der String Catalog, alle Texte, die Kinder oder Eltern zu sehen bekommen, `sourceLanguage` und `developmentLanguage`. Die App erscheint auf Deutsch und ist nur i18n-fähig gebaut — das ist Inhalt, nicht Dokumentation.

Bestandsschutz: der Spec, die vorhandenen deutschen Dateien unter `docs/` und diese Datei bleiben vorerst deutsch. Sie werden in einem eigenen Schritt migriert, nicht nebenbei. Was dort neu entsteht, entsteht englisch.

## Wo was liegt

| Bereich | Pfad | Zweck |
|---|---|---|
| App-Target | `apps/ZilpZalp/` | Xcode-Projekt, Assets, Info.plist, Entitlements |
| Website | `apps/web/` | Landing page and legal pages, Next.js on Vercel — German copy, English code |
| Spiellogik | `packages/ZilpZalpCore/` | Runden, Scoring, Ränge, Zeitbudget — ohne UI, ohne I/O |
| Daten | `packages/ZilpZalpData/` | Modelle, Paket-Manifeste, Persistenz, Downloader |
| Design-System | `packages/ZilpZalpUI/` | Tokens und SwiftUI-Komponenten |
| Werkzeuge | `tools/` | Medien-Kuration, Credits-Erzeugung — **Python**, nicht Swift |
| Paketdaten | `data/packs/` | Artenpakete mit Lizenz-Metadaten |
| Design-Referenz | `design/`, `screens/` | Design-Export und Klickprototyp — **nicht verändern** |

`design/` und `screens/` sind Referenzmaterial aus der Designphase. Sie werden nicht gepflegt und nicht kompiliert. Wenn die Swift-Umsetzung vom Design abweicht, ist das eine bewusste Entscheidung und gehört in den Spec, nicht in eine Änderung an `design/`.

## Architekturgrenzen

`ZilpZalpCore` importiert weder SwiftUI noch UIKit noch Foundation-Netzwerk-APIs. Es enthält reine Wertetypen und Funktionen. Wer dort eine `URLSession` oder ein `View` unterbringen will, hat die Grenze falsch gezogen.

`ZilpZalpUI` kennt keine Spiellogik. Komponenten bekommen fertige Werte übergeben und melden Ereignisse nach oben.

Alles, was ohne Simulator testbar ist, gehört in ein Package. Das App-Target enthält nur Verdrahtung.

## Werkzeuge

Alles läuft über mise. Nicht direkt `xcodebuild` oder `swift` aufrufen, sondern:

```
mise run setup      Abhängigkeiten und Werkzeuge installieren
mise run check      Format, Lint, Tests, Lizenz-Gate — das gleiche wie in CI
mise run format     Formatieren und behebbare Lint-Funde korrigieren
mise run test       Nur die Package-Tests
mise run generate   Xcode-Projekt aus project.yml erzeugen (vor dem Öffnen in Xcode)
mise run build      App bauen
mise run archive    App für den App Store archivieren, ohne Signatur
mise run upload     Dieses Archiv signieren und zu TestFlight schicken
mise run fetch-media  Medien kuratieren und nach S3 laden
mise run web:install  Abhängigkeiten der Website installieren (bun, apps/web)
mise run web:dev      Website lokal servieren
mise run web:build    Website bauen — derselbe Build wie in CI und auf Vercel
```

Die Website hat ihren eigenen Workflow (`.github/workflows/web.yml`); `ci.yml`
ignoriert `apps/web/**`, damit eine Textänderung an einer Rechtsseite weder den
macOS-Runner belegt noch einen TestFlight-Build auslöst. Umgekehrt fasst
`mise run check` `apps/web` nicht an.

Das `.xcodeproj` ist nicht eingecheckt. Vor dem Öffnen in Xcode `mise run generate`; ein von Hand in Xcode angelegtes Projekt kennt die Quelldateien nicht. Das Signing-Team (schnaq GmbH) steht in `project.yml` — im Signing-Tab von Xcode nichts umstellen, jedes Generieren stellt `project.yml` wieder her.

Xcode-Version ist in `mise.toml` gepinnt. Wenn ein Build lokal geht und in CI nicht, ist fast immer die Xcode-Version die Ursache.

## Medien und Lizenzen

**Harte Regel: nur CC0, CC BY und CC BY-SA.** Kein NonCommercial, kein NoDerivatives. Das CI-Gate bricht den Build ab, wenn ein Asset ohne gültige Lizenz oder ohne Attribution im Manifest steht.

Jedes Medium wird über `data/packs/*.json` deklariert — mit Quelle, Urheber, Lizenz und SHA-256. Der Credits-Screen wird daraus **generiert**. Nie Attribution von Hand in eine View schreiben; sie würde von den Assets abdriften.

Die App spricht zur Laufzeit **niemals** mit iNaturalist oder xeno-canto. Diese APIs werden ausschließlich von `tools/fetch-media` zur Kurationszeit genutzt. Zur Laufzeit spricht die App nur mit dem eigenen S3-Bucket, und auch das nur, wenn Eltern ausdrücklich ein Paket laden.

Zwei Befunde, die man sonst teuer wieder entdeckt:

- **Bei xeno-canto ist der `lic:`-Filter zwingend.** Ohne ihn sind die Treffer praktisch ausnahmslos NonCommercial. Gültige Werte sind `PD`, `BY` und `BY-SA`; `CC0` liefert nichts
- **Bei iNaturalist ist `default_photo` unbrauchbar** und `photo_license` wird am Taxon-Endpunkt stillschweigend ignoriert. Nur der Weg über `/v1/observations` mit `photo_license=cc0,cc-by,cc-by-sa` filtert wirklich

Details in [docs/medien-und-lizenzen.md](docs/medien-und-lizenzen.md).

## Kids Category

Die App erscheint in der Kids Category des App Store. Daraus folgen Regeln, die nicht verhandelbar sind:

- Kein Third-Party-Analytics, kein Third-Party-Crash-Reporting. Kein Sentry, kein Firebase. Nur MetricKit
- Externe Links nur hinter einem Parental Gate — betrifft besonders den Credits-Screen
- `PrivacyInfo.xcprivacy` deklariert: keine Datenerhebung
- Keine Werbung, keine In-App-Käufe, kein Tracking

Wer eine Abhängigkeit hinzufügen will, prüft zuerst, ob sie Daten sammelt oder Netzwerkverkehr erzeugt.

## Secrets

Niemals ein Secret ins Repo, auch nicht in eine Beispieldatei mit echtem Wert. Alles läuft über Infisical, siehe [docs/secrets.md](docs/secrets.md).

In GitHub liegen ausschließlich `INFISICAL_CLIENT_ID`, `INFISICAL_CLIENT_SECRET` und `INFISICAL_API_URL`. Jeder aus Infisical geladene Wert wird in CI mit `::add-mask::` maskiert — GitHub tut das nicht von selbst.

## Git

- Branch von `main`, Merge per Pull Request. Kein direkter Push auf `main`
- Branch-Namen: `feat/…`, `fix/…`, `docs/…`, `chore/…`
- Conventional Commits — git-cliff erzeugt daraus den Changelog. Betreff imperativ, höchstens 50 Zeichen, kein Punkt am Ende. Fließtext bei 72 Zeichen umbrechen
- Jeder grüne CI-Lauf auf `main` baut, signiert und lädt nach TestFlight (`.github/workflows/testflight.yml`); die Tags `vX.Y.Z` bleiben für App-Store-Releases
- Nicht committen oder pushen, ohne dass es gewünscht wurde

## Tests

Swift Testing (`@Test`) für Package-Logik, XCTest nur wo der Simulator wirklich gebraucht wird. Neue Logik in `ZilpZalpCore` ohne Test wird nicht gemerged.

Simulator-Tests bleiben bewusst sparsam. Ein instabiles Gate auf dem self-hosted Runner wird binnen einer Woche abgeschaltet, und dann ist gar nichts gewonnen.

## Fallstricke

- `swift test` in den Packages braucht keinen Simulator und ist der schnelle Weg. Wer `xcodebuild test` für Logik nutzt, wartet unnötig
- Der self-hosted Runner ist persistent. Build-Artefakte, DerivedData und Simulator-Zustand überleben Läufe und müssen aufgeräumt werden
- Signing-Material gehört in eine ephemere Keychain, die per `if: always()` wieder verschwindet
- `AVSpeechSynthesizer` verhält sich auf „Designed for iPad"-Macs anders als auf iOS. Vor Release dort testen
- `LAContext` mit `deviceOwnerAuthentication` fällt automatisch auf den Geräte-Code zurück. Nicht `deviceOwnerAuthenticationWithBiometrics` verwenden — sonst sperrt man Geräte ohne FaceID aus
- iNaturalist-Foto-URLs sind nicht garantiert stabil. Deshalb liegen alle Medien in unserem eigenen S3-Bucket, nicht als Fremd-URL im Manifest
