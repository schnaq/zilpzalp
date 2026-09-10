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
    a: (
      <>
        Nein. Jede Aufgabe wird vorgelesen, und auf den Antwortkacheln steht
        kein Name. Ein Kind, das noch kein Wort erkennt, kommt durch die ganze
        App.
      </>
    ),
  },
  {
    q: 'Wie öffne ich den Elternbereich?',
    a: (
      <>
        Auf der Startseite oben rechts, neben dem Avatar des Kindes: der runde
        Knopf mit der Figur und dem Zahnrad. Er fragt Face ID, Touch ID oder
        den Gerätecode ab — je nachdem, was das Gerät kann. Ist
        auf dem Gerät kein Code eingerichtet, stellt die App stattdessen eine
        kleine Rechenaufgabe, die ein Kind nicht löst.
      </>
    ),
  },
  {
    q: 'Wie begrenze ich die Spielzeit?',
    a: (
      <>
        Im Elternbereich lässt sich eine tägliche Spielzeit in Minuten
        einstellen. Eine laufende Runde wird immer noch zu Ende gespielt, danach
        sagt die App „Zeit fürs Nest“ und zeigt, wie viele Sterne der Tag
        gebracht hat. Die Einstellung gilt für alle Profile auf dem Gerät.
      </>
    ),
  },
  {
    q: 'Können mehrere Kinder auf einem Gerät spielen?',
    a: (
      <>
        Ja. Jedes Kind bekommt ein Profil mit Namen und Vogel-Avatar, und jedes
        sammelt für sich. Ein Vorname oder Spitzname genügt; alles bleibt auf
        dem Gerät.
      </>
    ),
  },
  {
    q: 'Braucht die App Internet?',
    a: (
      <>
        Zum Spielen nicht. Alle 70 Vogelarten stecken in der App. Eine
        Verbindung entsteht nur, wenn Erwachsene im Elternbereich ausdrücklich
        ein weiteres Artenpaket laden.
      </>
    ),
  },
  {
    q: 'Welche Geräte werden unterstützt?',
    a: (
      <>
        iPhone und iPad ab iOS beziehungsweise iPadOS 18. Auf Macs mit
        Apple Silicon läuft ZilpZalp über „Designed for iPad“ mit, ohne eigenes
        Mac-Layout.
      </>
    ),
  },
  {
    q: 'Es kommt kein Ton',
    a: (
      <>
        Beide Spiele brauchen Ton: Spiel 1 liest den Vogelnamen vor, Spiel 2
        spielt eine Aufnahme. Prüfe die Lautstärke; der Stummschalter des
        iPhones muss nicht umgelegt werden, die App spielt auch dann. Hilft das
        nicht, schließe die App vollständig und öffne sie erneut.
      </>
    ),
  },
  {
    q: 'Warum fehlt „Wer singt da?“ auf der Startseite?',
    a: (
      <>
        Spiel 2 erscheint nur, wenn genug Arten des geladenen Pakets eine
        Aufnahme haben. Lieber keine Kachel als eine, hinter der nichts klingt.
      </>
    ),
  },
  {
    q: 'Woher kommen die Fotos und die Vogelstimmen?',
    a: (
      <>
        Die Fotos von Naturbeobachtungen auf iNaturalist, die Stimmen von
        Aufnahmen auf xeno-canto — jedes Medium unter einer freien Lizenz (CC0,
        CC BY oder CC BY-SA). Wer was beigesteuert hat, steht in der App unter
        „Fotos &amp; Dank“.
      </>
    ),
  },
  {
    q: 'Welche Daten erhebt die App?',
    a: (
      <>
        Keine. Es gibt kein Konto, keine Anmeldung, keine Werbung und kein
        Analysewerkzeug. Ausführlich steht das in der{' '}
        <Link href="/datenschutz">Datenschutzerklärung</Link>.
      </>
    ),
  },
]

export default function Support() {
  return (
    <LegalPage title="Hilfe und Support">
      <h2>Kontakt</h2>
      <p>
        Bei Fragen, Problemen oder Rückmeldungen zu ZilpZalp schreib uns eine
        E-Mail:
      </p>
      <address>
        <a href={`mailto:${SUPPORT_MAIL}`}>{SUPPORT_MAIL}</a>
      </address>
      <p>
        Rechtliche Anfragen und alles, was die schnaq GmbH als Anbieter betrifft,
        gehen an die Adresse im <Link href="/impressum">Impressum</Link>.
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
        Wenn etwas nicht funktioniert, hilft uns eine E-Mail an{' '}
        <a href={`mailto:${SUPPORT_MAIL}`}>{SUPPORT_MAIL}</a> mit:
      </p>
      <ul>
        <li>was passiert ist und was du erwartet hättest</li>
        <li>Gerät und iOS-Version</li>
        <li>welche Schritte dahin geführt haben</li>
        <li>wenn möglich ein Bildschirmfoto</li>
      </ul>
      <p>
        Weil die App keine Daten sendet, sehen wir von einem Problem nichts,
        solange niemand es uns erzählt. Jede Meldung hilft also wirklich.
      </p>
    </LegalPage>
  )
}
