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

Die Signing-Secrets werden erst mit Meilenstein 7 gebraucht. Bis dahin baut CI ohne Codesign.

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

Nur drei Werte liegen als GitHub-Repository-Secret vor:

```
INFISICAL_CLIENT_ID
INFISICAL_CLIENT_SECRET
INFISICAL_API_URL      # https://secrets.schnaq.com — ohne /api
```

Alles Weitere wird zur Laufzeit geladen:

```yaml
- name: Load Infisical secrets into job env
  uses: Infisical/secrets-action@77ab1f4ccd183a543cb5b42435fbd181189f4995 # v1.0.16
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

## Wenn ein Secret kompromittiert ist

1. In Infisical rotieren, nicht nur löschen
2. Beim betroffenen Anbieter widerrufen — Apple Developer Portal, Scaleway Console, xeno-canto-Account
3. Prüfen, ob der Wert in einem Actions-Log auftaucht; falls ja, den Log-Lauf löschen
4. Machine Identity in Infisical neu ausstellen, falls die CI-Zugangsdaten selbst betroffen sind
