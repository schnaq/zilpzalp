import type { Metadata } from 'next'
import Link from 'next/link'
import { LegalPage } from '../legal-page'
import { SUPPORT_MAIL } from '../site-chrome'

export const metadata: Metadata = {
  title: 'Support',
  description:
    'Hilfe zu ZilpZalp: Kontakt, häufige Fragen von Eltern und wie man einen Fehler meldet.',
}

const FAQ = [
  {
    q: 'Muss mein Kind lesen können?',
    a: <>Nein. Die Vogelnamen werden vorgelesen, geantwortet wird mit Fotos.</>,
  },
  {
    q: 'Wer spricht in der App?',
    a: (
      <>
        Eine KI-Stimme, vorab aufgenommen. Fehlt für einen Satz die Aufnahme,
        liest die Stimme des Geräts.
      </>
    ),
  },
  {
    q: 'Wie öffne ich den Elternbereich?',
    a: (
      <>
        Mit dem runden Knopf oben rechts auf der Startseite, dem mit Figur und
        Zahnrad. Er fragt Face ID, Touch ID oder den Gerätecode ab. Ist kein
        Gerätecode eingerichtet, kommt stattdessen eine Rechenaufgabe für
        Erwachsene.
      </>
    ),
  },
  {
    q: 'Wie begrenze ich die Spielzeit?',
    a: (
      <>
        Im Elternbereich, in Minuten pro Tag und für alle Profile. Die laufende
        Runde wird noch zu Ende gespielt, dann heißt es „Zeit fürs Nest“.
      </>
    ),
  },
  {
    q: 'Können mehrere Kinder auf einem Gerät spielen?',
    a: (
      <>
        Ja. Jedes Kind bekommt ein eigenes Profil und sammelt für sich. Ein
        Vorname genügt.
      </>
    ),
  },
  {
    q: 'Was passiert, wenn ich die App lösche?',
    a: (
      <>
        Ist iCloud an, kommen Profile, Sterne und Sticker zurück, sobald du die
        App mit derselben Apple-ID wieder installierst – auch auf einem anderen
        iPhone oder iPad. Geladene Pakete holst du im Elternbereich neu.
      </>
    ),
  },
  {
    q: 'Braucht die App Internet?',
    a: (
      <>
        Zum Spielen nicht. Ins Netz geht sie nur für die Liste der Pakete —
        beim Start, damit der Knopf zum Elternbereich neue Pakete zeigen kann,
        und im Elternbereich — und für die Pakete, die du lädst. Die
        Spielstände sichert iOS in deiner iCloud.
      </>
    ),
  },
  {
    q: 'Welche Geräte werden unterstützt?',
    a: (
      <>
        iPhone und iPad ab iOS bzw. iPadOS 18. Auf Macs mit Apple Silicon läuft
        die iPad-Version.
      </>
    ),
  },
  {
    q: 'Es kommt kein Ton',
    a: (
      <>
        Prüf die Lautstärke; der Stummschalter stört nicht. Spricht die App
        nicht von selbst, steht Vorlesen im Elternbereich auf „Nur auf
        Knopfdruck“ – dann auf den Lautsprecher tippen. Sonst die App ganz
        schließen und neu öffnen.
      </>
    ),
  },
  {
    q: 'Warum fehlt „Wer singt da?“ auf der Startseite?',
    a: (
      <>
        Das Spiel erscheint nur, wenn genug der gewählten Vögel eine Aufnahme
        haben. Lieber keine Kachel als eine, hinter der nichts klingt.
      </>
    ),
  },
  {
    q: 'Woher kommen die Fotos und die Vogelrufe?',
    a: (
      <>
        Von iNaturalist und xeno-canto, alle unter freier Lizenz (CC0, CC BY
        oder CC BY-SA). Wer was beigesteuert hat, steht in der App unter
        „Über ZilpZalp“.
      </>
    ),
  },
  {
    q: 'Welche Daten erhebt die App?',
    a: (
      <>
        Keine. Kein Konto, keine Werbung, kein Tracking. Mehr dazu in der{' '}
        <Link href="/datenschutz">Datenschutzerklärung</Link>.
      </>
    ),
  },
]

export default function Support() {
  return (
    <LegalPage title="Hilfe und Support">
      <h2>Kontakt</h2>
      <p>Fragen, Probleme oder Rückmeldungen? Schreib uns:</p>
      <address>
        <a href={`mailto:${SUPPORT_MAIL}`}>{SUPPORT_MAIL}</a>
      </address>
      <p className="fine-print">
        Rechtliches an die schnaq GmbH, Adresse im{' '}
        <Link href="/impressum">Impressum</Link>.
      </p>

      <h2>Häufige Fragen</h2>
      {FAQ.map((entry) => (
        <div className="faq" key={entry.q}>
          <h3>{entry.q}</h3>
          <p>{entry.a}</p>
        </div>
      ))}

      <h2>Einen Fehler melden</h2>
      <p>
        Schreib an <a href={`mailto:${SUPPORT_MAIL}`}>{SUPPORT_MAIL}</a>:
      </p>
      <ul>
        <li>was passiert ist und wie es dazu kam</li>
        <li>Gerät und iOS-Version</li>
        <li>wenn möglich ein Bildschirmfoto</li>
      </ul>
      <p>
        Die App sendet uns keine Daten. Ohne deine Nachricht erfahren wir von
        einem Fehler nichts.
      </p>
    </LegalPage>
  )
}
