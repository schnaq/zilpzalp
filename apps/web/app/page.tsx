import Image from 'next/image'
import Link from 'next/link'
import { CallIcon, CheckIcon, NoneIcon, SpeechIcon, StarIcon } from './icons'
import { Screenshots } from './screenshots'

// The claims on this page are the ones App Store Connect already carries
// (scratchpad asc/metadata-de.json) and the specification behind them. Nothing
// here promises a feature the app does not have.

/// The published listing. The German storefront on purpose: the app and its
/// App Store metadata are German.
const APP_STORE_URL = 'https://apps.apple.com/de/app/zilpzalp/id6797092155'

const FACTS = [
  {
    term: '70 Arten',
    detail:
      'Amsel, Blaumeise, Rotkehlchen und der Zilpzalp — bis hin zu Eisvogel, Uhu, Kranich und Weißstorch.',
  },
  {
    term: 'Ohne Lesen',
    detail: 'Jede Aufgabe wird gesprochen, und zur Antwort stehen vier Fotos ohne Namen.',
  },
  {
    term: 'Sterne',
    detail: 'Jede Runde bringt bis zu drei Sterne — je nachdem, wie viel auf Anhieb sitzt.',
  },
  {
    term: 'Die Sammlung',
    detail:
      'Wer einen Vogel fünfmal auf Anhieb erkennt, bekommt seinen Sticker in die Sammlung.',
  },
  {
    term: 'Für mehrere Kinder',
    detail: 'Jedes Kind bekommt ein Profil mit Namen und Vogel-Avatar. Alles bleibt auf dem Gerät.',
  },
  {
    term: 'Offline',
    detail: 'Alle 70 Vögel sind in der App. Zum Spielen braucht sie kein Netz.',
  },
]

const PARENTS_CAN = [
  'Der Elternbereich öffnet sich mit Face ID oder dem Gerätecode — und ohne eingerichteten Code mit einer Rechenaufgabe für Erwachsene.',
  'Die tägliche Spielzeit lässt sich begrenzen. Ist sie aufgebraucht, sagt die App freundlich „Zeit fürs Nest“.',
  'Links, die aus der App hinausführen, öffnen sich erst nach derselben Rechenaufgabe.',
]

const APP_DOES_NOT = [
  'Keine Datenerhebung. Kein Konto, keine Anmeldung, kein Login mit irgendetwas.',
  'Keine Werbung und keine In-App-Käufe.',
  'Kein Analyse- oder Absturzmelde-Werkzeug von Dritten.',
  'Kein Tracking und keine Weitergabe an Dritte.',
]

// Static on purpose. The screenshot section reads the file system while the
// page is prerendered; rendering per request would look in a bundle that has
// no public/ in it, and every frame would fall back to its placeholder.
export const dynamic = 'force-static'

export default function Home() {
  return (
    <main>
      <section className="hero">
        <div className="wrap">
          <div>
            <h1 className="rise">Vögel kennenlernen, bevor man lesen kann.</h1>
            <p className="lead rise rise-2">
              ZilpZalp bringt Kindern die Vögel vor der eigenen Haustür nahe.
              Zwei Spiele, 70 heimische Arten, viele Sterne.
            </p>
            <div className="hero-actions rise rise-3">
              <a className="pill" href={APP_STORE_URL}>
                <StarIcon />
                Im App Store laden
              </a>
              <p className="hero-note">
                Für iPhone und iPad. Kostenlos, ohne Konto, ohne Werbung.
              </p>
            </div>
          </div>
          <div className="hero-art rise rise-2">
            <Image
              src="/logo.svg"
              alt="Die Bildmarke von ZilpZalp: ein Wiedehopf mit aufgestellter Haube."
              width={420}
              height={420}
              unoptimized
              priority
            />
          </div>
        </div>
      </section>

      <section id="inhalt">
        <div className="wrap">
          <div className="section-head">
            <h2>Zwei Spiele, eine Frage</h2>
            <p className="lead">
              Beide Spiele fragen dasselbe auf zwei Arten — und beide kommen ohne
              ein geschriebenes Wort aus.
            </p>
          </div>

          <div className="games">
            <article className="game">
              <span className="game-mark">
                <SpeechIcon />
              </span>
              <h3>Erkenne den Vogel</h3>
              <p>
                Ein Vogelname wird vorgelesen, vier Fotos liegen auf dem Tisch.
                Das Kind tippt den richtigen Vogel an. Beim zweiten Versuch
                klappt es fast immer — und falsch ist nie rot, sondern
                sonnengelb mit „Versuchs nochmal“.
              </p>
            </article>
            <article className="game">
              <span className="game-mark">
                <CallIcon />
              </span>
              <h3>Wer singt da?</h3>
              <p>
                Eine echte Vogelstimme erklingt. Welcher der vier Vögel war das?
                Ein Tipp auf den Lautsprecher spielt die Stimme noch einmal, so
                oft das Kind mag.
              </p>
            </article>
          </div>

          <dl className="facts">
            {FACTS.map((fact) => (
              <div key={fact.term}>
                <dt>{fact.term}</dt>
                <dd>{fact.detail}</dd>
              </div>
            ))}
          </dl>
        </div>
      </section>

      <section>
        <div className="wrap">
          <div className="section-head">
            <h2>Ein Blick in die App</h2>
            <p className="lead">
              Große Flächen, kräftige Farben, keine Menüs zum Verlaufen: alles
              ist für Finger gebaut, die noch nicht sicher zielen.
            </p>
          </div>
          <Screenshots />
        </div>
      </section>

      <section>
        <div className="wrap">
          <div className="section-head">
            <h2>Für Erwachsene</h2>
            <p className="lead">
              ZilpZalp ist eine App für die Kids Category des App Store. Was das
              bedeutet, steht hier — und nicht im Kleingedruckten.
            </p>
          </div>

          <div className="columns">
            <div className="column">
              <h3>Was Erwachsene einstellen</h3>
              <ul className="ticks">
                {PARENTS_CAN.map((item) => (
                  <li key={item}>
                    <CheckIcon />
                    <span>{item}</span>
                  </li>
                ))}
              </ul>
            </div>
            <div className="column">
              <h3>Was die App nicht tut</h3>
              <ul className="ticks ticks--none">
                {APP_DOES_NOT.map((item) => (
                  <li key={item}>
                    <NoneIcon />
                    <span>{item}</span>
                  </li>
                ))}
              </ul>
              <p>
                Ausführlich steht das in der{' '}
                <Link href="/datenschutz">Datenschutzerklärung</Link>.
              </p>
            </div>
          </div>
        </div>
      </section>

      <section>
        <div className="wrap">
          <div className="section-head section-head--tight">
            <h2>Echte Vögel, freie Medien</h2>
          </div>
          <p>
            Die Fotos stammen von Naturbeobachterinnen und Naturbeobachtern auf
            iNaturalist, die Stimmen von Aufnahmen auf xeno-canto — jedes Bild
            und jede Aufnahme unter einer freien Lizenz (CC0, CC BY oder
            CC BY-SA), keine Ausnahme. Wer was beigesteuert hat, steht offen
            einsehbar in der App unter „Über ZilpZalp“ → „Fotos &amp; Dank“,
            und diese Liste wird aus denselben Daten erzeugt wie die Dateien
            selbst. Sie kann also gar nicht veralten.
          </p>
        </div>
      </section>

      <section>
        <div className="wrap">
          <div className="section-head section-head--tight">
            <h2>Ein Spiel von Johanna Hillebrand und Christian Meter</h2>
          </div>
        </div>
      </section>
    </main>
  )
}
