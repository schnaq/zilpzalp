import type { Metadata } from 'next'
import Link from 'next/link'
import { LegalPage, Todo } from '../legal-page'

export const metadata: Metadata = {
  title: 'AGB',
  description:
    'Nutzungsbedingungen für die kostenlose App ZilpZalp — ohne Konto, ohne Käufe, mit Apples Standard-Lizenzvereinbarung für die Store-Fassung.',
}

export default function AGB() {
  return (
    <LegalPage title="Allgemeine Geschäftsbedingungen">
      <h2>1. Geltungsbereich</h2>
      <p>
        Diese Allgemeinen Geschäftsbedingungen (AGB) gelten für die Nutzung der
        App „ZilpZalp“ für iPhone und iPad, die von der schnaq GmbH
        (nachfolgend „Anbieter“) über den App Store angeboten wird, und für diese
        Website. Mit der Nutzung der App erklärt sich die Nutzerin oder der
        Nutzer mit diesen AGB einverstanden.{' '}
        <Todo>
          bestätigen, dass die App im App Store unter dem Entwicklerkonto der
          schnaq GmbH erscheint — steht die Veröffentlichung auf Johanna
          Hillebrand, muss dieser Absatz das sagen
        </Todo>
      </p>

      <h2>2. Leistungsbeschreibung</h2>
      <p>
        ZilpZalp ist eine Lern-App, mit der Kinder heimische Vögel
        kennenlernen. Sie enthält:
      </p>
      <ul>
        <li>zwei Spiele, in denen ein vorgelesener Name oder eine Vogelstimme dem richtigen von vier Fotos zugeordnet wird</li>
        <li>zehn heimische Vogelarten, die mit der App ausgeliefert werden</li>
        <li>mehrere lokale Profile mit Namen und Vogel-Avatar</li>
        <li>Sterne pro Runde und eine Sammlung, in die ein Vogel als Sticker wandert, sobald ein Kind ihn fünfmal auf Anhieb erkannt hat</li>
        <li>einen Elternbereich hinter der Geräteauthentifizierung mit einer einstellbaren täglichen Spielzeit</li>
        <li>die Möglichkeit, weitere Artenpakete zu laden</li>
      </ul>
      <p>
        Die App ist kostenlos. Sie enthält keine Werbung, keine In-App-Käufe und
        keine Abonnements.
      </p>

      <h2>3. Kein Konto, keine Registrierung</h2>
      <p>
        Die Nutzung der App erfordert weder eine Registrierung noch ein Konto
        bei uns oder bei Dritten. Profile werden lokal auf dem Gerät angelegt.
        Was dabei gespeichert wird, steht in der{' '}
        <Link href="/datenschutz">Datenschutzerklärung</Link>.
      </p>

      <h2>4. Nutzung durch Kinder</h2>
      <p>
        ZilpZalp ist für Kinder gemacht, die noch nicht lesen können, und
        erscheint in der Kids Category des App Store. Die App wird von einer
        erwachsenen Person geladen und eingerichtet; sie ist damit auch unser
        Vertragspartner. Erwachsene entscheiden über die tägliche Spielzeit, und
        Links, die aus der App hinausführen, öffnen sich erst nach einer
        Rechenaufgabe für Erwachsene.
      </p>

      <h2>5. Lizenzvereinbarung für die App aus dem App Store</h2>
      <p>
        Für die über den App Store bezogene Fassung der App gilt Apples
        Standard-Lizenzvereinbarung für Programme (Licensed Application End User
        License Agreement):{' '}
        <a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">
          apple.com/legal/internet-services/itunes/dev/stdeula
        </a>
        . Eine eigene Endnutzer-Lizenzvereinbarung gibt es nicht. Diese AGB
        treten nicht an die Stelle jener Vereinbarung, sondern ergänzen sie um
        das, was ZilpZalp selbst betrifft.
      </p>

      <h2>6. Quellcode, Fotos und Tonaufnahmen</h2>
      <p>
        ZilpZalp ist quelloffen. Der Quellcode steht unter der MIT-Lizenz und
        darf entsprechend genutzt, verändert und weitergegeben werden.
      </p>
      <p>
        Die Fotos und Tonaufnahmen in der App stammen von Dritten und stehen
        ausschließlich unter freien Creative-Commons-Lizenzen: CC0, CC BY oder
        CC BY-SA. Wer sie weiterverwendet, hält sich an die jeweilige Lizenz,
        insbesondere an die Pflicht zur Namensnennung. Urheberin oder Urheber,
        Lizenz und Quelle jedes einzelnen Mediums stehen in der App unter
        „Fotos &amp; Dank“ und im Repository.
      </p>
      <p>
        Nicht von diesen Lizenzen erfasst sind der Name „ZilpZalp“ und die
        Bildmarke. Beide bleiben dem Anbieter und Johanna Hillebrand
        vorbehalten; eine Nutzung, die den Eindruck erweckt, ein fremdes Angebot
        sei diese App, ist nicht gestattet.
      </p>

      <h2>7. Haftung</h2>
      <p>
        Der Anbieter haftet unbeschränkt für Vorsatz und grobe Fahrlässigkeit
        sowie für Schäden aus der Verletzung des Lebens, des Körpers oder der
        Gesundheit. Bei leichter Fahrlässigkeit haftet der Anbieter nur für die
        Verletzung wesentlicher Vertragspflichten und begrenzt auf den
        vorhersehbaren, vertragstypischen Schaden. Im Übrigen ist die Haftung
        ausgeschlossen. Da die App kostenlos und ohne Konto nutzbar ist, wird
        insbesondere keine ununterbrochene Verfügbarkeit einzelner Funktionen
        oder des Servers für zusätzliche Artenpakete zugesagt.
      </p>
      <p>
        ZilpZalp ist ein Lernspiel und keine Bestimmungshilfe: Fotos und
        Aufnahmen zeigen typische, aber nicht alle Erscheinungsformen einer Art.
        Für Entscheidungen, die eine sichere Artbestimmung brauchen, ist die App
        nicht gedacht.
      </p>

      <h2>8. Änderungen der App und dieser AGB</h2>
      <p>
        Die App wird weiterentwickelt; Funktionen können hinzukommen, sich
        ändern oder wegfallen. Diese AGB können angepasst werden, wenn die App
        oder die Rechtslage sich ändern. Es gilt die Fassung, die zum Zeitpunkt
        der Nutzung auf dieser Seite steht. Wer mit einer Änderung nicht
        einverstanden ist, kann die App löschen — mehr ist nicht nötig, weil es
        kein Konto und kein Abonnement gibt.
      </p>

      <h2>9. Datenschutz</h2>
      <p>
        Wie mit Daten umgegangen wird, steht in der{' '}
        <Link href="/datenschutz">Datenschutzerklärung</Link>. Sie ist
        Bestandteil dieser AGB.
      </p>

      <h2>10. Schlussbestimmungen</h2>
      <h3>10.1 Geltendes Recht</h3>
      <p>
        Es gilt das Recht der Bundesrepublik Deutschland unter Ausschluss des
        UN-Kaufrechts. Zwingende Verbraucherschutzvorschriften des Staates, in
        dem eine Verbraucherin oder ein Verbraucher ihren gewöhnlichen Aufenthalt
        hat, bleiben unberührt.
      </p>
      <h3>10.2 Gerichtsstand</h3>
      <p>
        Gerichtsstand für alle Streitigkeiten aus oder im Zusammenhang mit
        diesen AGB ist Düsseldorf, sofern die Nutzerin oder der Nutzer Kaufmann,
        juristische Person des öffentlichen Rechts oder öffentlich-rechtliches
        Sondervermögen ist.
      </p>
      <h3>10.3 Salvatorische Klausel</h3>
      <p>
        Sollten einzelne Bestimmungen dieser AGB unwirksam sein oder werden,
        bleibt die Wirksamkeit der übrigen Bestimmungen unberührt. An die Stelle
        der unwirksamen Bestimmung tritt eine wirksame Bestimmung, die dem
        wirtschaftlichen Zweck der unwirksamen Bestimmung am nächsten kommt.
      </p>
    </LegalPage>
  )
}
