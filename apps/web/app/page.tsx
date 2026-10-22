import Image from 'next/image'
import Link from 'next/link'
import { CallIcon, CheckIcon, NoneIcon, SpeechIcon, StarIcon } from './icons'
import { Screenshots } from './screenshots'

// Every feature claim on this page is checked against the app on main.

/// The published listing. The German storefront on purpose: the app and its
/// App Store metadata are German.
const APP_STORE_URL = 'https://apps.apple.com/de/app/zilpzalp/id6797092155'

const SOURCE_URL = 'https://github.com/schnaq/zilpzalp'

const FACTS = [
  {
    term: 'Über 300 Vögel',
    detail:
      '70 aus Deutschland sind dabei. Mehr gibt es in Paketen aus aller Welt, die sich mischen lassen.',
  },
  {
    term: 'Sticker',
    detail: 'Wer einen Vogel oft genug auf Anhieb erkennt, bekommt seinen Sticker.',
  },
  {
    term: 'Profile',
    detail: 'Jedes Kind spielt mit eigenem Namen und eigener Sammlung.',
  },
]

const PARENTS_CAN = [
  'Neue Pakete laden.',
  'Sticker nach drei oder fünf Treffern.',
  'Vorlesen von selbst oder auf Antippen.',
  'Eine tägliche Spielzeit.',
]

const APP_DOES_NOT = [
  'Kein Konto, keine Werbung, keine Käufe, kein Tracking.',
  'Kein Internet zum Spielen nötig.',
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
              Gemacht für Kinder. Aber wer erkennt schon über 300 Vögel? Da
              lernen Erwachsene gern mit.
            </p>
            <div className="hero-actions rise rise-3">
              <a className="pill" href={APP_STORE_URL}>
                <StarIcon />
                Im App Store laden
              </a>
              <p className="hero-note">Kostenlos für iPhone und iPad.</p>
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
          <div className="section-head section-head--tight">
            <h2>Zwei Spiele</h2>
          </div>

          <div className="games">
            <article className="game">
              <span className="game-mark">
                <SpeechIcon />
              </span>
              <h3>Erkenne den Vogel</h3>
              <p>Eine KI-Stimme nennt einen Vogel. Welches der vier Fotos passt?</p>
            </article>
            <article className="game">
              <span className="game-mark">
                <CallIcon />
              </span>
              <h3>Wer singt da?</h3>
              <p>Ein echter Vogelruf erklingt. Welcher Vogel war das?</p>
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
          <div className="section-head section-head--tight">
            <h2>Ein Blick in die App</h2>
          </div>
          <Screenshots />
        </div>
      </section>

      <section>
        <div className="wrap">
          <div className="section-head">
            <h2>Für Eltern</h2>
            <p className="lead">
              Der Elternbereich ist mit Face ID, Touch ID oder dem Gerätecode
              gesichert.
            </p>
          </div>

          <div className="columns">
            <div className="column">
              <h3>Einstellbar</h3>
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
              <h3>Gibt es nicht</h3>
              <ul className="ticks ticks--none">
                {APP_DOES_NOT.map((item) => (
                  <li key={item}>
                    <NoneIcon />
                    <span>{item}</span>
                  </li>
                ))}
              </ul>
              <p>
                Mehr in der{' '}
                <Link href="/datenschutz">Datenschutzerklärung</Link>.
              </p>
            </div>
          </div>
        </div>
      </section>

      <section>
        <div className="wrap">
          <div className="section-head section-head--tight">
            <h2>Freie Fotos, offener Code</h2>
          </div>
          <p>
            Fotos und Vogelrufe stehen unter freier Lizenz (CC). Der Code liegt
            offen auf <a href={SOURCE_URL}>GitHub</a>.
          </p>
        </div>
      </section>
    </main>
  )
}
