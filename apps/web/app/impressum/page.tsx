import type { Metadata } from 'next'
import Link from 'next/link'
import { LegalPage } from '../legal-page'

export const metadata: Metadata = {
  title: 'Impressum',
  description: 'Angaben gemäß § 5 DDG für zilpzalp.schnaq.com und die App ZilpZalp.',
}

// The entity data below is copied, never rewritten: it is the same block the
// sibling site foxhunt.schnaq.com carries for the same company.
export default function Impressum() {
  return (
    <LegalPage title="Impressum">
      <h2>Angaben gemäß § 5 DDG</h2>
      <address>
        schnaq GmbH
        <br />
        c/o TechHub.K67
        <br />
        Kasernenstr. 67
        <br />
        40213 Düsseldorf
        <br />
        Deutschland
      </address>

      <h2>Vertreten durch</h2>
      <p>
        Geschäftsführung: Dr. Alexander Schneider, Dr. Christian Meter, Michael
        Birkhoff
      </p>

      <h2>Kontakt</h2>
      <p>
        Telefon: +49 156 78354553
        <br />
        E-Mail: <a href="mailto:info@schnaq.com">info@schnaq.com</a>
      </p>

      <h2>Registereintrag</h2>
      <p>
        Eintragung im Handelsregister.
        <br />
        Registergericht: Amtsgericht Düsseldorf
        <br />
        Registernummer: HRB 95753
      </p>

      <h2>Umsatzsteuer-ID</h2>
      <p>
        Umsatzsteuer-Identifikationsnummer gemäß Paragraph 27 a
        Umsatzsteuergesetz: DE349912851
      </p>

      <h2>EU-Streitschlichtung</h2>
      <p>
        Die Europäische Kommission stellt eine Plattform zur
        Online-Streitbeilegung (OS) bereit:{' '}
        <a href="https://ec.europa.eu/consumers/odr/">
          https://ec.europa.eu/consumers/odr/
        </a>
        . Unsere E-Mail-Adresse finden Sie oben im Impressum.
      </p>

      <h2>Verbraucherstreitbeilegung / Universalschlichtungsstelle</h2>
      <p>
        Wir sind nicht bereit oder verpflichtet, an Streitbeilegungsverfahren vor
        einer Verbraucherschlichtungsstelle teilzunehmen.
      </p>

      <h2>Haftung für Inhalte</h2>
      <p>
        Als Diensteanbieter sind wir gemäß § 7 Abs. 1 DDG für eigene Inhalte auf
        diesen Seiten nach den allgemeinen Gesetzen verantwortlich. Nach §§ 8 bis
        10 DDG sind wir als Diensteanbieter jedoch nicht verpflichtet,
        übermittelte oder gespeicherte fremde Informationen zu überwachen oder
        nach Umständen zu forschen, die auf eine rechtswidrige Tätigkeit
        hinweisen. Verpflichtungen zur Entfernung oder Sperrung der Nutzung von
        Informationen nach den allgemeinen Gesetzen bleiben hiervon unberührt.
        Eine diesbezügliche Haftung ist jedoch erst ab dem Zeitpunkt der Kenntnis
        einer konkreten Rechtsverletzung möglich. Bei Bekanntwerden von
        entsprechenden Rechtsverletzungen werden wir diese Inhalte umgehend
        entfernen.
      </p>

      <h2>Haftung für Links</h2>
      <p>
        Unser Angebot enthält Links zu externen Websites Dritter, auf deren
        Inhalte wir keinen Einfluss haben. Deshalb können wir für diese fremden
        Inhalte auch keine Gewähr übernehmen. Für die Inhalte der verlinkten
        Seiten ist stets der jeweilige Anbieter oder Betreiber der Seiten
        verantwortlich. Die verlinkten Seiten wurden zum Zeitpunkt der
        Verlinkung auf mögliche Rechtsverstöße überprüft. Rechtswidrige Inhalte
        waren zum Zeitpunkt der Verlinkung nicht erkennbar. Eine permanente
        inhaltliche Kontrolle der verlinkten Seiten ist jedoch ohne konkrete
        Anhaltspunkte einer Rechtsverletzung nicht zumutbar. Bei Bekanntwerden
        von Rechtsverletzungen werden wir derartige Links umgehend entfernen.
      </p>

      <h2>Urheberrecht</h2>
      <p>
        Die durch die Seitenbetreiber erstellten Inhalte und Werke auf diesen
        Seiten unterliegen dem deutschen Urheberrecht. Die Vervielfältigung,
        Bearbeitung, Verbreitung und jede Art der Verwertung außerhalb der
        Grenzen des Urheberrechtes bedürfen der schriftlichen Zustimmung des
        jeweiligen Autors bzw. Erstellers. Downloads und Kopien dieser Seite sind
        nur für den privaten, nicht kommerziellen Gebrauch gestattet. Soweit die
        Inhalte auf dieser Seite nicht vom Betreiber erstellt wurden, werden die
        Urheberrechte Dritter beachtet. Insbesondere werden Inhalte Dritter als
        solche gekennzeichnet. Sollten Sie trotzdem auf eine
        Urheberrechtsverletzung aufmerksam werden, bitten wir um einen
        entsprechenden Hinweis. Bei Bekanntwerden von Rechtsverletzungen werden
        wir derartige Inhalte umgehend entfernen.
      </p>
      <p>
        Für die App selbst gelten eigene, freiere Regeln: Der Quellcode steht
        unter der MIT-Lizenz, die Fotos und Tonaufnahmen in der App unter
        Creative-Commons-Lizenzen. Welche das im Einzelnen sind, steht in den{' '}
        <Link href="/agb">AGB</Link> und in der App unter „Fotos &amp; Dank“.
      </p>
    </LegalPage>
  )
}
