# Secrets

Alle Secrets liegen in der selbst gehosteten Infisical-Instanz unter `https://secrets.schnaq.com`. Nichts davon gehört ins Repository — auch nicht in eine `.env.example` mit echtem Wert.

## Projekt

| Feld         | Wert                                   |
| ------------ | -------------------------------------- |
| Instanz      | `https://secrets.schnaq.com`           |
| Projekt      | ZilpZalp                               |
| Projekt-ID   | `9820fa11-518f-4760-a64f-7f832e6c2e8a` |
| Environments | `dev`, `prod`                          |

Die CLI erwartet die Domain **mit** `/api`, die GitHub Action **ohne**. Das ist keine Inkonsistenz im Repo, sondern eine Eigenheit der beiden Werkzeuge — im unlock-Repo hat genau das schon einmal Zeit gekostet.

## Lokale Einrichtung

Einmalig anmelden:

```
infisical login --domain=https://secrets.schnaq.com/api
```

Achte darauf, die richtige Organisation zu wählen. Wer in einer anderen Organisation angemeldet ist, bekommt beim Zugriff `403 This project does not belong to your selected organization`.

Danach laufen die mise-Tasks, die Secrets brauchen, automatisch über `infisical run`.

## Ordner und Inhalte

| Pfad | Secret                                  | Wofür                                     |
| ---- | --------------------------------------- | ----------------------------------------- |
| `/`  | `XENO_CANTO_API_KEY`                    | Vogelrufe kuratieren, `tools/fetch-media` |
| `/`  | `SCW_ACCESS_KEY`, `SCW_SECRET_KEY`      | Scaleway Object Storage, Medien-Upload    |
| `/`  | `S3_BUCKET`, `S3_REGION`, `S3_ENDPOINT` | Zielbucket für Medien                     |
| `/ios` | `IOS_DIST_CERT_P12_BASE64` | Apple-Distribution-Zertifikat |
| `/ios` | `IOS_DIST_CERT_PASSWORD` | Passwort dazu |
| `/ios` | `IOS_PROVISIONING_PROFILE_BASE64` | App-Store-Provisioning-Profil |
| `/ios` | `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8_BASE64` | App Store Connect API, TestFlight-Upload |
| `/ios` | `IOS_DIST_CERT_CHAIN_BASE64` | optional: Apple-WWDR-Zwischenzertifikat, nur nötig für eine Generation, die `.github/certs` noch nicht mitbringt |

Die Signing-Secrets liest ausschließlich `.github/workflows/testflight.yml`. Der Workflow läuft nach jedem grünen CI-Lauf auf `main` auf dem self-hosted Runner: Zertifikat und Profil wandern in eine eigene Keychain (`.github/scripts/ios-signing-setup.sh`), das Archiv entsteht ohne Signatur, und `xcodebuild -exportArchive` signiert und lädt es mit dem App-Store-Connect-Schlüssel nach TestFlight. `.github/scripts/ios-signing-teardown.sh` räumt danach alles wieder ab — der Runner ist persistent, Signing-Material darf keinen Lauf überleben. Der normale CI-Lauf baut weiterhin ohne Codesign.

Die Apple-WWDR-Zwischenzertifikate liegen als öffentliche CA-Zertifikate im Repository unter `.github/certs/` und werden bei jedem Release in die Keychain importiert — kein Secret, kein Download zur Laufzeit, und die Kette hängt nicht mehr davon ab, was der Runner zufällig mitbringt (siehe `.github/certs/README.md`).

Lokal mit denselben Befehlen nachvollziehbar:

```
mise run archive
infisical run --env=prod --path=/ios -- mise run upload
```

Das ist ein echter Upload. Ohne `GITHUB_RUN_NUMBER` trägt der Build die Nummer aus `project.yml`, und App Store Connect lehnt eine Build-Nummer ab, die es schon kennt.

## Medien-Bucket

| Feld | Wert |
|---|---|
| Anbieter | Scaleway Object Storage |
| Bucket | `zilpzalp-media` |
| Region | `fr-par` |
| Endpunkt | `https://s3.fr-par.scw.cloud` |
| Lesezugriff | öffentlich |

Öffentlich lesbar ist Absicht: es sind ausschließlich CC-lizenzierte Medien, und die App soll sie ohne Zugangsdaten laden können. Schreibrechte hat allein `tools/fetch-media` über `SCW_ACCESS_KEY` und `SCW_SECRET_KEY` aus Infisical.

## In GitHub Actions

Für Infisical liegen nur drei Werte als GitHub-Repository-Secret vor:

```
INFISICAL_CLIENT_ID
INFISICAL_CLIENT_SECRET
INFISICAL_API_URL      # https://secrets.schnaq.com — ohne /api
```

Alles Weitere wird zur Laufzeit aus Infisical geladen:

```yaml
- name: Load Infisical secrets into job env
  uses: Infisical/secrets-action@6cd3f7c0e4cc0d2395ee4ef414eb6eeb5d3e73db # v1.0.17
  with:
    method: universal
    client-id: ${{ secrets.INFISICAL_CLIENT_ID }}
    client-secret: ${{ secrets.INFISICAL_CLIENT_SECRET }}
    domain: ${{ secrets.INFISICAL_API_URL }}
    project-slug: ${{ env.INFISICAL_PROJECT_SLUG }}
    env-slug: prod
    secret-path: /ios
    export-type: env
```

**Wichtig:** GitHub maskiert Werte, die über diese Action in die Job-Umgebung kommen, nicht automatisch. Jeder Wert, der in einer Ausgabe landen könnte, muss ausdrücklich maskiert werden:

```bash
echo "::add-mask::$XENO_CANTO_API_KEY"
```

Bei mehrzeiligen Werten wie einem Base64-Zertifikat zeilenweise maskieren.

### Ausnahme: Vercel

Der Deploy der Website (`.github/workflows/web.yml`, Job `deploy`) braucht nur
zwei Werte: `VERCEL_TOKEN` (projekt-scoped) und `VERCEL_PROJECT_ID`. Beide
liegen in Infisical (Environment `dev`, Ordner `/actions`) und werden von dort
nach GitHub Actions als Repository-Secret synchronisiert — so kommen sie in
GitHub an, ohne dass der Workflow selbst die Infisical-Action aufruft.
`VERCEL_ORG_ID` wird nicht mehr gebraucht: der projekt-scoped Token liefert
über `GET /v9/projects/{id}` auch die `accountId`, aus der der Workflow die
Org-ID selbst herleitet (siehe Kommentar in `web.yml`). Das Secret kann aus
den GitHub-Org-Secrets gelöscht werden. Werte aus `secrets.*` maskiert GitHub
im Log automatisch, anders als die per Infisical-Action geladenen oben.

## Smoke-Test

`.github/workflows/secrets-smoke.yml` (`workflow_dispatch`, self-hosted Runner) prüft, ob die Machine Identity aus CI heraus tatsächlich lesen kann. Er lädt bewusst nur einen unkritischen Wert (`S3_BUCKET`), maskiert ihn und bricht ab, wenn er leer ist. Ein grüner Lauf ist der Beleg für #6, dass die drei `INFISICAL_*`-Repository-Secrets funktionieren — nicht mehr.

## Wenn ein Secret kompromittiert ist

1. In Infisical rotieren, nicht nur löschen
2. Beim betroffenen Anbieter widerrufen — Apple Developer Portal, Scaleway Console, xeno-canto-Account
3. Prüfen, ob der Wert in einem Actions-Log auftaucht; falls ja, den Log-Lauf löschen
4. Machine Identity in Infisical neu ausstellen, falls die CI-Zugangsdaten selbst betroffen sind
