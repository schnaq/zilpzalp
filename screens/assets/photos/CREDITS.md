# Bildnachweise — Vogelfotos

Alle Fotos stammen von **iNaturalist** (API-Abfrage, gefiltert auf `photo_license=cc0,cc-by`, Qualitätsstufe *research*), zugeschnitten auf 1:1, 512×512 px. **CC BY verlangt Namensnennung** — sie erscheint in der App im Bild unten links (`ChoiceTile credit="…"`) und gesammelt im Erwachsenenbereich unter „Fotos & Dank“.

| Datei | Art | Wissenschaftlich | Fotograf:in | Lizenz | Beobachtung |
| --- | --- | --- | --- | --- | --- |
| `zilpzalp.png` | Zilpzalp | *Phylloscopus collybita* | Tomas Broucek | CC BY 4.0 | https://www.inaturalist.org/observations/353438691 |
| `wiedehopf.png` | Wiedehopf | *Upupa epops* | Dmitry Ivanov | CC BY 4.0 | https://www.inaturalist.org/observations/299928082 |
| `amsel.png` | Amsel | *Turdus merula* | Alexis Tinker-Tsavalas | CC BY 4.0 | https://www.inaturalist.org/observations/20490738 |
| `blaumeise.png` | Blaumeise | *Cyanistes caeruleus* | Thorsten Hackbarth | CC BY 4.0 | https://www.inaturalist.org/observations/153819994 |
| `kohlmeise.png` | Kohlmeise | *Parus major* | SteveM4560 | CC BY 4.0 | https://www.inaturalist.org/observations/258365796 |
| `rotkehlchen.png` | Rotkehlchen | *Erithacus rubecula* | Alexis Tinker-Tsavalas | CC BY 4.0 | https://www.inaturalist.org/observations/19776411 |
| `buntspecht.png` | Buntspecht | *Dendrocopos major* | Вячеслав Юсупов | CC BY 4.0 | https://www.inaturalist.org/observations/18530920 |
| `eisvogel.png` | Eisvogel | *Alcedo atthis* | Alexis Lours | CC BY 4.0 | https://www.inaturalist.org/observations/98375354 |
| `star.png` | Star | *Sturnus vulgaris* | egorbirder | CC BY 4.0 | https://www.inaturalist.org/observations/72752929 |
| `hausrotschwanz.png` | Hausrotschwanz | *Phoenicurus ochruros* | SteveM4560 | CC BY 4.0 | https://www.inaturalist.org/observations/345090569 |

## Verwendung im Code

```jsx
<ChoiceTile photo="assets/photos/wiedehopf.png" name="Wiedehopf" credit="Foto: Dmitry Ivanov (CC BY)" tone="rufe" />
```

Beim Austauschen eines Fotos immer beide Stellen mitziehen: diese Tabelle **und** das `credit`-Prop.
