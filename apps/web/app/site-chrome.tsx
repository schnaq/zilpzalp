import Image from 'next/image'
import Link from 'next/link'

/// Contact for questions about the app. Johanna's mailbox, deliberately not the
/// company address in the Impressum: parents write to whoever can answer.
export const SUPPORT_MAIL = 'zilpzalp-app@posteo.net'

/// The legal entity behind the site. `info@schnaq.com` is the controller's
/// address and belongs in the Impressum and the privacy policy only.
export const COMPANY_MAIL = 'info@schnaq.com'

export function Masthead() {
  return (
    <header className="masthead">
      <div className="wrap">
        <Link href="/" className="wordmark">
          <Image src="/logo.svg" alt="" width={40} height={40} unoptimized priority />
          ZilpZalp
        </Link>
      </div>
    </header>
  )
}

export function Footer() {
  return (
    <footer className="footer">
      <div className="wrap">
        <div className="footer-grid">
          <div>
            <p>
              <strong>ZilpZalp</strong> ist ein Projekt von Johanna Hillebrand,
              zusammen mit der schnaq GmbH.
            </p>
            <p>
              Fragen zur App? <a href={`mailto:${SUPPORT_MAIL}`}>{SUPPORT_MAIL}</a>
            </p>
          </div>
          <nav aria-label="Rechtliches">
            <ul>
              <li>
                <Link href="/support">Support</Link>
              </li>
              <li>
                <Link href="/datenschutz">Datenschutz</Link>
              </li>
              <li>
                <Link href="/agb">AGB</Link>
              </li>
              <li>
                <Link href="/impressum">Impressum</Link>
              </li>
            </ul>
          </nav>
        </div>
        <div className="footer-legal">
          <span>© 2026 Johanna Hillebrand</span>
          <span>
            Fotos von iNaturalist, Vogelstimmen von xeno-canto — alle unter
            freien Lizenzen, alle in der App genannt.
          </span>
        </div>
      </div>
    </footer>
  )
}
