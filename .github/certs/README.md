# Apple WWDR intermediate certificates

Public certificate authority certificates, downloaded from
<https://www.apple.com/certificateauthority/> and committed as DER (`.cer`).
`.github/scripts/ios-signing-setup.sh` imports every file in this directory
into the ephemeral release keychain before it looks at anything else, so
`codesign` can build the chain leaf → WWDR intermediate → Apple root.

They are committed rather than fetched at job time for three reasons: they are
public CA certificates and no secret, so nothing here needs Infisical; the
self-hosted runner's CI user never receives newer intermediates, because those
arrive with Xcode in a developer's login keychain and not in a service
session; and this repository's CI rule forbids downloading anything during a
run (see `.github/workflows/ci.yml` — tooling is provisioned, never
`curl | bash`).

| File | Source URL | SHA-256 | Subject OU | Issuer | Expires |
|---|---|---|---|---|---|
| `AppleWWDRCAG3.cer` | <https://www.apple.com/certificateauthority/AppleWWDRCAG3.cer> | `dcf21878c77f4198e4b4614f03d696d89c66c66008d4244e1b99161aac91601f` | G3 | Apple Root CA | 2030-02-20 |
| `AppleWWDRCAG4.cer` | <https://www.apple.com/certificateauthority/AppleWWDRCAG4.cer> | `ea4757885538dd8cb59ff4556f676087d83c85e70902c122e42c0808b5bce14c` | G4 | Apple Root CA | 2030-12-10 |
| `AppleWWDRCAG5.cer` | <https://www.apple.com/certificateauthority/AppleWWDRCAG5.cer> | `53fd008278e5a595fe1e908ae9c5e5675f26243264a5a6438c023e3ce2870760` | G5 | Apple Root CA | 2030-12-10 |
| `AppleWWDRCAG6.cer` | <https://www.apple.com/certificateauthority/AppleWWDRCAG6.cer> | `bdd4ed6e74691f0c2bfd01be0296197af1379e0418e2d300efa9c3bef642ca30` | G6 | Apple Root CA - G3 | 2036-03-19 |

A DER file holds exactly the certificate, so the SHA-256 of the file is the
certificate's SHA-256 fingerprint. Verify a file two ways:

```
shasum -a 256 .github/certs/AppleWWDRCAG6.cer
openssl x509 -inform der -in .github/certs/AppleWWDRCAG6.cer \
  -noout -subject -issuer -enddate -fingerprint -sha256
```

Apple also serves `AppleWWDRCAG2.cer`, `AppleWWDRCAG7.cer` and
`AppleWWDRCAG8.cer`. G7 (2023) and G8 (2025) have expired and would only add
noise to the keychain. G2 carries a different subject (`CN=Apple Worldwide
Developer Relations CA - G2`) and does not belong to the generation series
that issues Apple Distribution certificates.

The distribution certificate this repository signs with expires 2027-08-01;
its issuer is printed by the signing script on every release run. When that
printed issuer names an OU which is not in the table above, download that
generation from the URL pattern used here and add it — do not work around it
in the script.
