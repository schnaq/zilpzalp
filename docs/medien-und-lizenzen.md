# Medien, APIs und Lizenzen — Entscheidung

**Datum:** 2026-08-01
**Status:** entschieden, mit benannten Restrisiken
**Gilt für:** alle Fotos, Tonaufnahmen, Schriften und Symbole in ZilpZalp

Die App ist quelloffen, kostenlos und ohne Gewinnabsicht — wird aber über den App Store verteilt. Das ist der Maßstab für jede Lizenzentscheidung hier.

---

## Die Grundregel

**Zugelassen sind ausschließlich CC0, CC BY und CC BY-SA.**

NonCommercial (`BY-NC`, `BY-NC-SA`, `BY-NC-ND`) ist ausgeschlossen. Zwei Gründe: die Verteilung über einen kommerziellen Store ist angreifbar genug, dass sich der Streit nicht lohnt, und die NC-Erlaubnis ließe sich nicht an Leute weitergeben, die das Repository forken. Eine MIT-lizenzierte Codebasis, die NC-Medien mitliefert, macht ihren Nutzern ein Versprechen, das sie nicht halten kann.

NoDerivatives (`BY-ND`) ist ebenfalls ausgeschlossen, weil schon das Zuschneiden eines Fotos auf ein Quadrat eine Bearbeitung ist.

Ein Gate in der CI prüft jedes Asset im Manifest gegen diese Liste und bricht den Build ab, wenn Lizenz oder Urheber fehlen.

---

## Quellenübersicht

| Quelle | Wofür | Lizenzen | Attribution | API | Bündeln erlaubt | Urteil |
|---|---|---|---|---|---|---|
| **iNaturalist** | Vogelfotos, Artenlisten, deutsche Namen | pro Foto verschieden, filterbar auf CC0/BY/BY-SA | ja, Fotograf:in | v1 offen, kein Schlüssel | ja, gefiltert | **gewählt** |
| **xeno-canto** | Vogelrufe | BY-SA, BY-NC-SA, BY-NC-ND | ja, Aufnehmer:in + XC-Nummer | v3, Schlüssel nötig | ja, nur BY-SA | **gewählt, eingeschränkt** |
| **AVSpeechSynthesizer** | Vogelnamen vorlesen | Systemfunktion | entfällt | Systemframework | entfällt | **gewählt** |
| **Baloo 2, Nunito** | Schriften | OFL 1.1 | Copyright-Hinweis mitliefern | — | ja | **gewählt** |
| **Lucide** | Symbole | ISC | Copyright-Hinweis mitliefern | — | ja | **gewählt** |
| Freesound CC0 | Bedienklänge | CC0 | keine | — | ja | offen, Meilenstein 5 |
| SF Symbols | Symbole | Apple-Lizenz | — | Systemframework | nur in der App | verworfen |
| Featherbase | Federfotos | keine Lizenz, nur Einzelerlaubnis | ja, mit Belegnummer | — | nein | **verworfen** |
| USFWS Feather Atlas | Federfotos | uneinheitlich, kein pauschales Public Domain | unklar | — | fraglich | **verworfen** |
| Wikimedia Commons | Federfotos | CC BY-SA u. a. | ja | ja | ja | zu lückenhaft |
| NABU, LBV | Fotos, Lebensraum | urheberrechtlich geschützt | — | keine | nein | **verworfen** |
| Wikidata P2974 | Lebensraum | CC0 | keine | ja | ja | bei Vögeln nicht gepflegt |
| IUCN Red List | Lebensraum | nur nicht-kommerziell | ja | Schlüssel, Bot-Sperre | nein | **verworfen** |
| Macaulay Library | Rufe, Fotos | Cornell-Bedingungen | ja | eingeschränkt | nein | nicht weiterverfolgt |

---

## Fotos: iNaturalist

**Gewählt.** Die Quelle hat sich in der Designphase bereits bewährt — die zehn Fotos unter `design/assets/photos/` stammen daher, samt vollständiger Nachweise in `CREDITS.md`.

### Was praktisch geprüft wurde

Suche nach deutschem Trivialnamen funktioniert direkt:

```
GET https://api.inaturalist.org/v1/taxa?q=Amsel&rank=species&locale=de
→ id=12716, Turdus merula, "Amsel", 261.250 Beobachtungen
```

Artenlisten pro Region lassen sich ableiten — die Grundlage für die Pakete:

```
GET https://api.inaturalist.org/v1/observations/species_counts
      ?place_id=7207&taxon_id=3&quality_grade=research&locale=de
→ 617 Vogelarten in Deutschland, nach Beobachtungszahl sortiert,
  mit deutschen Namen: Stockente, Amsel, Graureiher, Kohlmeise, …
```

`place_id=7207` ist Deutschland, `taxon_id=3` ist die Klasse Aves — beides überprüft.

**Wichtiger Befund:** Das `default_photo` eines Taxons trägt häufig eine NC-Lizenz oder gar keine. Für unsere Zwecke ist es unbrauchbar. Der Weg über Beobachtungen mit Lizenzfilter liefert dagegen zuverlässig:

```
GET https://api.inaturalist.org/v1/observations
      ?taxon_id=<id>&photo_license=cc0,cc-by,cc-by-sa
      &quality_grade=research&order_by=votes
```

Für die zwanzig häufigsten Vogelarten Deutschlands wurde das einzeln getestet: **20 von 20 Arten haben frei lizenzierte Fotos**, meist mehrere Tausend. Die Bildseite der Artenpakete ist damit belegt, nicht angenommen.

### API-Details

**v1 genügt, v2 bringt hier keinen Vorteil.** Die v2-Spezifikation liegt unter `https://api.inaturalist.org/v2/api-docs` — nicht unter `/v2/swagger.json`, das ist ein 404. v2 liefert standardmäßig nur minimale Objekte und verlangt einen `fields`-Parameter in RISON-Notation:

```
GET /v2/taxa?q=Erithacus%20rubecula&fields=(id:!t,name:!t,default_photo:(license_code:!t))
```

Für unseren Zweck ist das nur zusätzliche Komplexität. Lesezugriffe brauchen bei beiden Versionen keine Authentifizierung.

**Nützliche Kennungen:** Deutschland `place_id=7207`, Europa `97391`, Bayern `12871` — Bundesländer existieren also. Aves ist `taxon_id=3`. Achtung bei der Ortssuche: `q=Deutschland` findet das Land nicht, `q=Germany` schon.

**Bildgrößen** (nachgemessen): `square` 75×75, `small` 240×180, `medium` 500×375, `large` 1024×769, `original` bis 2048px.

**Die Domain verrät die Lizenz** — laut API-Dokumentation:

> The domain a photo is hosted under reflects the license under which the photo is being shared, and the domain may change over time if the license changes.

Fotos auf `inaturalist-open-data.s3.amazonaws.com` sind offen lizenziert, solche auf `static.inaturalist.org` nicht. Eine brauchbare zweite Absicherung neben dem `license_code`.

**Rate Limits**, wörtlich aus der API-Dokumentation:

> Please note that we throttle API usage to a max of 100 requests per minute, though we ask that you try to keep it to 60 requests per minute or lower, and to keep under 10,000 requests per day.

> The API is intended to support application development, **not data scraping**. For pre-generated data exports, see https://www.inaturalist.org/pages/developers

Für größere Mengen gibt es den offiziellen Weg über die AWS Open Data Registry: `s3://inaturalist-open-data` in `us-east-1`, abrufbar mit `--no-sign-request`. Sollte das Deutschland-Paket auf mehrere hundert Arten wachsen, ist das der richtige Weg statt vieler Einzelanfragen.

### Fallstricke

- **`default_photo` ist unbrauchbar.** Es trägt häufig eine NC-Lizenz oder gar keine, und `photo_license` als Parameter hat am Taxon-Endpunkt **keinerlei Wirkung** — nachgetestet, die Antwort ist mit und ohne identisch. Nur der Umweg über Beobachtungen filtert wirklich
- `taxon_id` liefert auch Unterarten mit. Wo das stört, `rank=species` erzwingen
- Nicht jedes Foto ist didaktisch brauchbar. `order_by=votes` liefert von der Community gut bewertete Aufnahmen, ersetzt aber keine Sichtprüfung — ein unscharfer Vogel im Gegenlicht taugt nicht für ein Ratespiel
- Die Fotos zeigen teils Jungvögel, Weibchen oder untypische Haltungen. Bei Arten mit deutlichem Geschlechtsunterschied, etwa dem Hausrotschwanz, muss bewusst ausgewählt werden
- Die Bild-URLs sind nicht als dauerhaft zugesichert. Deshalb liegen alle Medien in unserem eigenen Bucket, und das Manifest verweist auf ihn — die iNaturalist-URL bleibt nur als Herkunftsnachweis erhalten
- Beitragende können ihre Lizenz nachträglich ändern. Wir dokumentieren Lizenz und Abrufdatum pro Asset
- Deutsche Namen kommen über `locale=de` praktisch lückenlos — geprüft an über 45 Arten, selbst ein Mongolenregenpfeifer mit einer einzigen Beobachtung hat einen. Die einzigen Lücken sind Hybriden

### Was iNaturalist nicht kann

Es gibt **keine Habitat-Information**. Die kontrollierten Begriffe umfassen nur Alive or Dead, Established, Life Stage, Leaves, Evidence of Presence, Flowers and Fruits und Sex. Der Endpunkt für Observation Fields antwortet mit 404, Guides und Lists sind aus der API verschwunden, und eine Projektsuche nach „Gartenvögel" liefert nichts Verwertbares.

**Folge für die Pakete:** Geografische Pakete wie „Vögel Deutschlands" (617 Arten verfügbar) oder „Vögel Europas" (1.145) lassen sich sauber automatisch ableiten. Thematische Pakete wie „Gartenvögel" oder „Wasservögel" **müssen von Hand kuratiert werden** — man nimmt die nach Häufigkeit sortierte Länderliste und wählt daraus aus.

Das ist auch inhaltlich nötig: die Sortierung folgt der Beobachtungshäufigkeit, nicht dem, was ein Kind im Garten sieht. Unter den zwanzig häufigsten deutschen Arten stehen Stockente, Graureiher, Graugans, Höckerschwan, Blässhuhn und Kormoran — fotogene Wasservögel, die gern fotografiert werden, aber kein Gartenvogel-Paket ergeben.

---

## Vogelrufe: xeno-canto

**Gewählt, aber eingeschränkt.**

Die API v2 ist abgeschaltet:

```
GET https://xeno-canto.org/api/2/recordings?query=…
→ {"error":"server_error","message":"Xeno-canto API v2 is no longer available."}
```

Die aktuelle v3 verlangt einen kostenlosen Schlüssel:

```
GET https://xeno-canto.org/api/3/recordings?query=…
→ 401 {"message":"Missing or invalid 'key' parameter."}
```

Der Schlüssel liegt in Infisical unter `XENO_CANTO_API_KEY`.

### Lizenzlage

Die Nutzungsbedingungen nennen drei Lizenzfamilien, aus denen Aufnehmende wählen:

> **Attribution-NonCommercial-NoDerivs** (BY-NC-ND): This is the most restrictive of our licenses.
> **Attribution-NonCommercial-ShareAlike** (BY-NC-SA): […] as long as those derivative works are licensed under the same license.
> **Attribution-ShareAlike** (BY-SA): Again, this license is similar to the previous license, but it also allows anyone to use the recording commercially.

Nach unserer Grundregel bleibt davon **allein BY-SA** übrig. Beide NC-Varianten scheiden aus.

Attribution ist Pflicht und umfasst Aufnehmer:in, Lizenz und XC-Katalognummer — genau die Angaben, die xeno-canto auch selbst bei jeder Aufnahme zeigt.

Zum automatisierten Zugriff:

> the server cannot usually accomodate indiscriminate automated requests such as mass downloads of pages or files. […] Requests for the transfer of large amounts of data, for any use allowed by the license, are of course welcome at the contact address below.

Für zehn bis sechzig Arten mit je einer Aufnahme ist das kein Massendownload. Wächst der Bedarf, fragen wir vorher an. `tools/fetch-media` drosselt auf höchstens eine Anfrage pro Sekunde und setzt einen aussagekräftigen User-Agent.

### Gemessene Verfügbarkeit

Der Filter `lic:` funktioniert serverseitig und ist **zwingend** — die ersten hundert Treffer zur Amsel sind ohne ihn ausnahmslos NC-lizenziert. Verfügbare Werte: `PD`, `BY`, `BY-SA`. `CC0` liefert nichts, gemeinfreie Aufnahmen laufen unter `PD`.

Am Beispiel Amsel wird das Verhältnis deutlich: 1.336 Aufnahmen insgesamt, davon **123 frei nutzbar** — knapp 9 Prozent. Der Vorrat ist also um Größenordnungen dünner als bei den Fotos, aber er reicht.

**Test über die zwanzig häufigsten deutschen Arten:** alle zwanzig haben frei lizenzierte Aufnahmen, achtzehn davon in Qualitätsstufe A. Nur Blaumeise und Buntspecht haben in A nichts, in B aber sehr wohl.

**Stichprobe über die Ränge 21 bis 60:** ebenfalls zwanzig von zwanzig mit freien Aufnahmen — von Kleiber (34) und Mönchsgrasmücke (68) bis Reiherente (3).

Damit ist das Deutschland-Paket mit rund sechzig Arten auch auf der Tonseite belegt. Für seltenere Arten jenseits davon wird es dünner; dort ist im Zweifel die Art zu tauschen.

### Kuration ist Pflicht

Die Zahlen allein täuschen. Das Feld `type` zeigt, was tatsächlich aufgenommen wurde, und vieles davon taugt nicht für ein Ratespiel: „wings noise" beim Fasan, „wingbeats" beim Höckerschwan, „nocturnal flight call" beim Kiebitz, „begging call" bei der Schwanzmeise. Ein Kind soll den typischen Gesang oder Ruf lernen, nicht das Flügelschlagen.

`tools/fetch-media` bevorzugt deshalb `type:song`, dann `type:call`, und legt Kandidaten zur Sichtung vor, statt blind den ersten Treffer zu nehmen. Die Längen reichen von fünf Sekunden bis über zwei Minuten — für das Spiel wird auf wenige Sekunden zugeschnitten.

### Restrisiko

Sollte der Vorrat bei einer Art doch nicht reichen, gibt es drei Auswege in dieser Reihenfolge: Art aus dem Paket nehmen und durch eine gleichwertige ersetzen; Aufnahmen aus Wikimedia Commons ergänzen; selbst aufnehmen und unter CC BY-SA stellen.

### ShareAlike beim Zuschneiden

Rohaufnahmen sind oft minutenlang. Für das Spiel brauchen wir wenige Sekunden. Ein Zuschnitt ist eine Bearbeitung und muss unter CC BY-SA bleiben. Das ist unproblematisch: die Audiodateien bleiben BY-SA, der Programmcode bleibt MIT — beides steht nebeneinander, ohne sich anzustecken.

Ob die technischen Schutzmaßnahmen des App Store mit der entsprechenden Klausel von CC BY-SA kollidieren, ist eine Frage, die ein Mensch beurteilen sollte. Sie ist in Abschnitt 10 des Specs als offener Punkt vermerkt. Falls die Antwort ungünstig ausfällt, weichen wir auf CC0- und CC-BY-Aufnahmen aus.

---

## Vogelnamen vorlesen

`AVSpeechSynthesizer` mit `de-DE`, direkt auf dem Gerät, zur Laufzeit. Kein Audio-Asset, keine Lizenzfrage, kein Speicherbedarf, keine Netzabhängigkeit. Der Klickprototyp nutzt bereits die entsprechende Web-Schnittstelle.

Vorgerenderte Sprachdateien wurden verworfen: sie kosten Platz, müssen bei jeder neuen Art nachgezogen werden, und der Export von System-Sprachausgabe wirft eigene Lizenzfragen auf.

Zu prüfen bleibt die Aussprache. „Zilpzalp" und „Hausrotschwanz" sollten von der deutschen Stimme korrekt kommen; falls nicht, hilft eine phonetische Schreibweise im Manifest.

---

## Schriften und Symbole

**Baloo 2** (Ek Type) und **Nunito** (Vernon Adams, Cyreal, Jacques Le Bailly), beide unter SIL Open Font License 1.1. Das Bündeln in einer App ist ausdrücklich gedeckt:

> Original or Modified Versions of the Font Software may be bundled, redistributed and/or sold with any software

Auflagen: die vollständige Lizenz und alle Copyright-Hinweise mitliefern, und die reservierten Namen nicht für veränderte Fassungen verwenden. Wir liefern die Schriften unverändert aus und legen `OFL.txt` je Schrift bei.

**Lucide** unter ISC, Symbole werden als SVG ins Repository übernommen. Der Copyright-Hinweis wird mitgeliefert; einige Symbole stammen aus Feather und brauchen zusätzlich dessen MIT-Hinweis.

**SF Symbols verworfen.** In der App wären sie nutzbar, aber exportierte Symboldateien in einem öffentlichen Repository sind durch Apples Lizenz nicht gedeckt. Für ein Open-Source-Projekt ist das ein unnötiges Risiko, zumal Lucide besser zum runden, freundlichen Erscheinungsbild passt.

---

## Was nicht funktioniert hat

### Federn — Spiel 3 hat keine Quelle

**Featherbase** ist die naheliegende Quelle und scheidet trotzdem aus. Die Bedingungen sind keine Lizenz, sondern eine persönliche Erlaubnis unter drei Auflagen:

> the use is not for commercial purposes […] the use is made with full reference to the source […] the Featherbase team has been informed about the use by email

Eine solche Erlaubnis lässt sich nicht an Leute weitergeben, die das Repository forken. In einem MIT-Projekt wäre das ein Versprechen ohne Deckung — unabhängig davon, ob Featherbase auf Anfrage zustimmen würde.

**USFWS Feather Atlas** deckt nordamerikanische Arten ab und stellt selbst klar, dass nicht alle Inhalte gemeinfrei sind.

**Wikimedia Commons** hat einzelne gute Federfotos mitteleuropäischer Arten, aber unsystematisch: die Kategorien sind nach Federtyp geordnet, nicht nach Art, und die vorhandenen Aufnahmen stammen von sehr wenigen Beitragenden. Für eine vollständige Artenliste reicht das nicht.

**Konsequenz:** Spiel 3 wird vertagt. Der wahrscheinlichste Weg später sind eigene Fotos unter eigener Lizenz. Zu beachten: das Sammeln von Federn besonders geschützter Arten ist nach BNatSchG eingeschränkt.

### Lebensraum — Spiel 4 muss selbst kuratiert werden

**Wikidata** hat mit P2974 eine Habitat-Eigenschaft, die bei Vögeln praktisch nicht gepflegt ist. Stichprobe: das Rotkehlchen (Q25334) ist ansonsten reich beschrieben — Rote Liste, Spannweite, Gewicht, Namen in vielen Sprachen — hat aber keine einzige Habitat-Aussage. Selbst die Beispiele auf der Eigenschaftsseite sind Bakterien und Krebstiere.

**IUCN** hat ein gepflegtes Habitat-Schema, erlaubt die API aber nur nicht-kommerziell und untersagt die Weiterverbreitung. Zudem ist das Schema global und grob — achtzehn Kategorien wie „Forest" oder „Wetlands (inland)", nicht die kindgerechten fünf, die wir brauchen.

**NABU und LBV** haben genau die passenden Kategorien und pflegen Artenporträts danach. Beide Bildarchive sind aber urheberrechtlich geschützt, es gibt keine API, und ein systematisches Auslesen ihrer Zuordnung berührt das Datenbankherstellerrecht nach §87a UrhG. Als *Vorbild* für unser eigenes Kategorienschema sind sie nützlich, als Datenquelle nicht.

**Konsequenz:** Die Zuordnung Art → Lebensraum schreiben wir selbst, mit Literaturbeleg je Art. Bei sechzig Arten ist das überschaubare Redaktionsarbeit, und das Ergebnis gehört uns.

---

## Wie Medien ins Projekt kommen

```
data/packs/*.json ──> tools/fetch-media ──> Scaleway S3 (zilpzalp-media, fr-par)
                                                 │
                     Basis-Paket ────────────────┼──> Asset Catalog ──> App-Bundle
                     Download-Pakete ────────────┴──> zur Laufzeit geladen
                                                 │
                     tools/generate-credits ─────┴──> Credits-Screen + CREDITS.md
```

Drei Eigenschaften sind wichtig:

**Die App spricht zur Laufzeit nie mit iNaturalist oder xeno-canto.** Beide werden ausschließlich zur Kurationszeit angefragt. Das macht die App offlinefähig, schützt vor verschwindenden Fremd-URLs, hält uns von Rate-Limits fern und sorgt dafür, dass jedes ausgelieferte Medium einmal von einem Menschen gesehen wurde.

**Der eigene S3-Bucket ist die stabile Quelle.** Er entkoppelt Builds von der Verfügbarkeit fremder Dienste und erlaubt es, neue Pakete ohne App-Update auszuliefern.

**Der Credits-Screen wird erzeugt, nicht geschrieben.** Attribution stammt aus demselben Manifest wie die Assets und kann deshalb nicht von ihnen abdriften. Das ist die wichtigste einzelne Entscheidung in diesem Dokument: sie macht Lizenztreue zu einer Eigenschaft des Build-Prozesses statt zu einer Frage von Sorgfalt.

### Dateiformate

**Fotos: HEIC (HEVC in HEIF), Qualität 60, 4:2:0, sRGB, ohne Metadaten.** Gemessen an den zehn Fotos des Basis-Pakets erreicht HEIC die Qualität des bisherigen JPEG 88 bereits bei Qualität rund 51 und mit etwa 55 bis 65 Prozent der Bytes; Qualität 60 lässt darüber noch Reserve und ist bei Anzeigegröße nicht vom verlustfreien Original zu unterscheiden. iOS dekodiert HEIC über ImageIO, `UIImage(contentsOfFile:)` braucht dafür nichts Eigenes. Der Encoder schreibt `exif=None`: die HEIF-Seite von Pillow würde sonst den EXIF-Block der Vorlage übernehmen, und damit das Kameramodell und die GPS-Position aus dem Garten eines Menschen.

**Rufe bleiben AAC-LC, 64 kbit/s, mono, in `.m4a`.** Sechs Sekunden wiegen damit rund 50 KB — klein genug, dass ein anderes Format nichts Nennenswertes spart, und in Hardware dekodiert auf jedem Gerät, das die App unterstützt. Opus wurde geprüft und verworfen: `AVAudioPlayer` gilt für Opus in einem CAF-Container als abspielbar, dokumentiert ist es nicht belastbar. Für eine Kinder-App, deren Ton auf jedem Gerät funktionieren muss, ist das der falsche Ort für eine Wette.

### Manifest-Format

```json
{
  "id": "amsel",
  "name": "Amsel",
  "scientificName": "Turdus merula",
  "taxonID": 12716,
  "article": "die",
  "photo": {
    "file": "photos/amsel.heic",
    "sha256": "…",
    "license": "CC-BY-4.0",
    "attribution": "Alexis Tinker-Tsavalas",
    "sourceURL": "https://www.inaturalist.org/observations/20490738",
    "retrieved": "2026-08-01"
  }
}
```

---

## Was ein Mensch noch prüfen muss

Diese Punkte sind bewusst nicht abschließend beantwortet:

1. **CC BY-SA und die Schutzmaßnahmen des App Store.** Betrifft zugeschnittene Audios. Ausweichweg vorhanden: nur CC0 und CC BY verwenden
2. **CC BY-SA bei bearbeiteten Fotos.** Ein auf 1:1 zugeschnittenes BY-SA-Foto ist eine Bearbeitung und bleibt BY-SA. Sauberer ist, BY-SA-Fotos zu meiden und bei CC0 und CC BY zu bleiben, wo der Vorrat ohnehin groß genug ist
3. **Ob unser Vorgehen den iNaturalist-Nutzungsbedingungen entspricht,** insbesondere das Zwischenspeichern der Fotos im eigenen Bucket. Die Lizenz der einzelnen Fotos erlaubt es; die Plattformbedingungen sind separat zu lesen
4. **Ob eine kostenlose App im App Store als nicht-kommerzielle Nutzung gilt.** Wir umgehen die Frage, indem wir NC-Material komplett meiden — sie muss also nicht beantwortet werden

---

## Quellen

- iNaturalist API: https://api.inaturalist.org/v1/docs/ · https://api.inaturalist.org/v2/docs/
- xeno-canto Bedingungen: https://xeno-canto.org/about/terms · API: https://xeno-canto.org/explore/api
- SIL Open Font License 1.1: https://openfontlicense.org/
- Baloo 2: https://github.com/google/fonts/tree/main/ofl/baloo2 · Nunito: https://github.com/google/fonts/tree/main/ofl/nunito
- Lucide: https://github.com/lucide-icons/lucide/blob/main/LICENSE
- Featherbase Bedingungen: https://www.featherbase.info/en/contact/
- USFWS Feather Atlas: https://www.fws.gov/lab/featheratlas/ · Haftungsausschluss: https://www.fws.gov/disclaimer
- NABU Impressum: https://www.nabu.de/wir-ueber-uns/impressum.html · LBV: https://www.lbv.de/impressum/
- Wikidata P2974: https://www.wikidata.org/wiki/Property:P2974
- IUCN Habitat-Schema: https://www.iucnredlist.org/resources/habitat-classification-scheme
