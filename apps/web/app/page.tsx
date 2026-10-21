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

const SOURCE_URL = 'https://github.com/schnaq/zilpzalp'

const FACTS = [
  {
    term: 'Über 300 Vögel',
    detail:
      '70 aus Deutschland sind schon dabei. Mehr gibt es in Paketen aus aller Welt, und mehrere Pakete lassen sich zusammen spielen.',
  },
  {
    term: 'Sterne und Sticker',
    detail:
      'Jede Runde bringt bis zu drei Sterne. Wer einen Vogel oft genug auf Anhieb erkennt, bekommt seinen Sticker.',
  },
  {
    term: 'Mehrere Kinder',
    detail:
      'Jedes hat ein eigenes Profil mit Namen und Vogel-Avatar und darf beides selbst ändern.',
  },
]

const PARENTS_CAN = [
  'Pakete ansehen und neue Vögel laden.',
  'Pro Kind wählen: Sticker nach drei oder fünf Treffern auf Anhieb.',
  'Das Vorlesen ausschalten. Die Vogelrufe bleiben.',
  'Eine tägliche Spielzeit. Danach heißt es „Zeit fürs Nest“.',
]

const APP_DOES_NOT = [
  'Kein Konto und keine Datenerhebung.',
  'Keine Werbung, keine In-App-Käufe, kein Tracking.',
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
              ZilpZalp zeigt Kindern die Vögel vor der Haustür — und auf Wunsch
              die aus aller Welt.
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
          <div className="section-head">
            <h2>Zwei Spiele</h2>
            <p className="lead">
              Die Vogelnamen spricht eine KI-Stimme, geantwortet wird mit
              Fotos. Lesen muss niemand.
            </p>
          </div>

          <div className="games">
            <article className="game">
              <span className="game-mark">
                <SpeechIcon />
              </span>
              <h3>Erkenne den Vogel</h3>
              <p>
                Die Stimme nennt einen Vogel, das Kind tippt auf das passende
                von vier Fotos. Daneben? Dann heißt es freundlich „Versuchs
                nochmal“.
              </p>
            </article>
            <article className="game">
              <span className="game-mark">
                <CallIcon />
              </span>
              <h3>Wer singt da?</h3>
              <p>
                Ein echter Vogelruf erklingt. Welcher der vier Vögel war das?
                Anhören geht so oft, wie das Kind mag.
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
              Große Knöpfe, kräftige Farben, keine Menüs zum Verlaufen.
            </p>
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
              <h3>Was Eltern einstellen</h3>
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
              <h3>Was es nicht gibt</h3>
              <ul className="ticks ticks--none">
                {APP_DOES_NOT.map((item) => (
                  <li key={item}>
                    <NoneIcon />
                    <span>{item}</span>
                  </li>
                ))}
              </ul>
              <p>
                Mehr dazu in der{' '}
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
            Die Fotos kommen von iNaturalist, die Vogelrufe von xeno-canto,
            alle unter freier Lizenz (CC0, CC BY oder CC BY-SA). Wer sie
            beigesteuert hat, steht in der App unter „Über ZilpZalp“. Der
            Quellcode von ZilpZalp liegt offen auf{' '}
            <a href={SOURCE_URL}>GitHub</a>.
          </p>
        </div>
      </section>
    </main>
  )
}
