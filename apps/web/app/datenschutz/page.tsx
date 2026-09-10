import type { Metadata } from 'next'
import Link from 'next/link'
import { LegalPage } from '../legal-page'
import { COMPANY_MAIL, SUPPORT_MAIL } from '../site-chrome'

export const metadata: Metadata = {
  title: 'Datenschutz',
  description:
    'Was die App ZilpZalp und diese Website mit Daten machen: die App erhebt keine, die Website setzt keine Cookies.',
}

// Every statement about the app is checked against the repository:
// apps/ZilpZalp/Resources/PrivacyInfo.xcprivacy (no tracking, no collected data
// types), ProfileStore and ParentalSettingsStore (JSON in Application Support),
// ParentsLock (LocalAuthentication), SpeechAnnouncer (AVSpeechSynthesizer on the
// device), PackDownloader (downloads a grown-up starts). A grep for MetricKit
// over apps and packages finds nothing, so no diagnostics claim appears here.
export default function Datenschutz() {
  return (
    <LegalPage title="Datenschutzerklärung">
      <h2>Kurz gesagt</h2>
      <p>
        Die App ZilpZalp erhebt keine personenbezogenen Daten. Es gibt kein
        Konto, keine Anmeldung, keine Werbung, kein Tracking und kein
        Analysewerkzeug. Was ein Kind in der App anlegt, bleibt auf dem Gerät.
        Diese Website setzt keine Cookies, bindet nichts von fremden Servern ein
        und misst nichts.
      </p>

      <h2>1. Verantwortlicher</h2>
      <p>
        Verantwortlicher im Sinne der Datenschutz-Grundverordnung (DSGVO) und
        anderer nationaler Datenschutzgesetze sowie sonstiger
        datenschutzrechtlicher Bestimmungen ist:
      </p>
      <address>
        schnaq GmbH
        <br />
        c/o TechHub.K67
        <br />
        Kasernenstr. 67
        <br />
        40213 Düsseldorf
        <br />
        E-Mail: <a href={`mailto:${COMPANY_MAIL}`}>{COMPANY_MAIL}</a>
      </address>
      <p>
        Fragen zur App beantwortet{' '}
        <a href={`mailto:${SUPPORT_MAIL}`}>{SUPPORT_MAIL}</a>. Anfragen zum
        Datenschutz richten Sie bitte an die Adresse oben.
      </p>

      <h2>2. Die App ZilpZalp</h2>

      <h3>2.1 Keine Erhebung personenbezogener Daten</h3>
      <p>
        ZilpZalp erhebt keine personenbezogenen Daten und gibt keine an Dritte
        weiter. Das Privacy Manifest der App (<code>PrivacyInfo.xcprivacy</code>)
        deklariert dementsprechend: kein Tracking, keine erhobenen Datenarten,
        keine Tracking-Domains.
      </p>

      <h3>2.2 Was auf dem Gerät bleibt</h3>
      <p>
        Damit ein Kind sein Profil wiederfindet, legt die App Daten lokal im
        Bereich „Application Support“ der App ab:
      </p>
      <ul>
        <li>
          Profile: der Vorname oder Spitzname, den Erwachsene eingeben, ein
          ausgewählter Vogel-Avatar, gesammelte Sterne, eine kleine Statistik und
          die schon erkannten Vogelarten
        </li>
        <li>
          Einstellungen des Elternbereichs: die tägliche Spielzeit und ob der
          Vogelname unter dem Foto angezeigt wird
        </li>
        <li>Heruntergeladene Artenpakete, falls Erwachsene welche laden</li>
      </ul>
      <p>
        Diese Daten verlassen das Gerät nicht. Sie werden nicht an uns und nicht
        an Dritte übertragen, und wir haben keinen Zugriff darauf. Wer sie
        loswerden will, löscht das Profil in der App oder die App selbst.
      </p>
      <p>
        Ein Hinweis für Erwachsene: Der Name eines Profils erscheint in der App
        und ist damit für alle sichtbar, die das Gerät benutzen. Ein Vorname oder
        ein Spitzname genügt.
      </p>

      <h3>2.3 Elternbereich, Face ID und Gerätecode</h3>
      <p>
        Der Elternbereich ist mit der Geräteauthentifizierung von iOS geschützt
        (<code>LocalAuthentication</code>, Richtlinie{' '}
        <code>deviceOwnerAuthentication</code>). Je nach Gerät ist das Face ID,
        Touch ID oder der Gerätecode. Die App bekommt von iOS ausschließlich die
        Antwort „erfolgreich“ oder „nicht erfolgreich“. Biometrische Daten
        verlassen die Sicherheitshardware des Geräts nie und sind für die App
        nicht zugänglich.
      </p>

      <h3>2.4 Sprachausgabe</h3>
      <p>
        Die gesprochenen Aufgaben erzeugt die Sprachausgabe von iOS
        (<code>AVSpeechSynthesizer</code>) auf dem Gerät. Es wird nichts an einen
        Sprachdienst gesendet, und es wird nichts aufgezeichnet: Die App fragt
        weder das Mikrofon noch die Kamera, den Standort oder die Kontakte ab.
      </p>

      <h3>2.5 Wann die App überhaupt ins Netz geht</h3>
      <p>
        Zum Spielen braucht ZilpZalp kein Internet. Alle 70 Arten der
        Grundausstattung stecken in der App. Eine Verbindung entsteht nur, wenn
        eine erwachsene Person im Elternbereich ausdrücklich ein zusätzliches
        Artenpaket lädt. Dann holt die App die Dateien von unserem Medienserver;
        technisch bedingt sieht dessen Betreiber dabei die IP-Adresse des Geräts
        und die angefragten Dateien.
      </p>
      <p>
        Der Medienserver ist ein Object-Storage-Bereich bei der Scaleway SAS
        (8 rue de la Ville l’Evêque, 75008 Paris, Frankreich), Region „fr-par“ in
        Frankreich. Die Dateien liegen ausschließlich in der EU. Mit Scaleway
        besteht ein Auftragsverarbeitungsvertrag als Teil der
        Vertragsbedingungen. Die Zugriffsprotokolle des Medienservers bewahrt
        Scaleway 30 Tage auf.
      </p>
      <p>
        Die Dienste, aus denen die Fotos und Tonaufnahmen stammen — iNaturalist
        und xeno-canto — spricht die App nie an. Beide werden nur bei der
        Vorbereitung der Pakete abgefragt, lange bevor die App ausgeliefert
        wird.
      </p>

      <h3>2.6 Keine Analyse, kein Absturzmelder, keine Werbung</h3>
      <p>
        Die App enthält kein Analysewerkzeug, keinen Absturzmelder eines
        Drittanbieters, keine Werbe-Bibliothek und keine In-App-Käufe. Es gibt
        keine Werbe-Kennung (IDFA) und keine Profilbildung.
      </p>

      <h3>2.7 Kinder</h3>
      <p>
        ZilpZalp erscheint in der Kids Category des App Store und ist für Kinder
        gebaut, die noch nicht lesen können. Deshalb: keine Daten von Kindern,
        keine Werbung, keine Käufe. Links, die aus der App hinausführen, öffnen
        sich erst, nachdem eine kleine Rechenaufgabe gelöst wurde, die für
        Erwachsene gedacht ist.
      </p>

      <h2>3. Diese Website</h2>

      <h3>3.1 Hosting</h3>
      <p>
        Diese Website wird bei der Vercel Inc. (440 N Barranca Avenue #4133,
        Covina, CA 91723, USA) gehostet. Beim Aufruf einer Seite verarbeitet
        Vercel als Auftragsverarbeiter die Daten, die jeder Webserver zur
        Auslieferung braucht: IP-Adresse, Zeitpunkt, aufgerufene Adresse,
        übertragene Datenmenge, Referrer sowie Browser- und Systemangaben. Für
        Übermittlungen in die USA stützt sich Vercel auf das EU-U.S. Data Privacy
        Framework und ergänzend auf Standardvertragsklauseln. Datenschutzhinweise
        von Vercel:{' '}
        <a href="https://vercel.com/legal/privacy-policy">
          vercel.com/legal/privacy-policy
        </a>
        . Mit Vercel besteht ein Auftragsverarbeitungsvertrag. Die Server-Logs
        bewahrt Vercel 24 Stunden auf.
      </p>

      <h3>3.2 Keine Cookies, keine Statistik, nichts von fremden Servern</h3>
      <p>
        Diese Website setzt keine Cookies und speichert nichts im Browser. Es
        gibt keine Reichweitenmessung, keine Einbindung sozialer Netzwerke und
        keine Inhalte von fremden Servern. Die Schriften Baloo 2 und Nunito
        liegen auf demselben Server wie die Seite und werden nicht von Google
        Fonts geladen. Deshalb braucht diese Seite auch keinen Cookie-Banner.
      </p>

      <h3>3.3 Kontakt per E-Mail</h3>
      <p>
        Wenn Sie uns schreiben, verarbeiten wir Ihre E-Mail-Adresse und den
        Inhalt Ihrer Nachricht, um sie zu beantworten. Rechtsgrundlage ist
        Art. 6 Abs. 1 lit. f DSGVO, unser berechtigtes Interesse an der
        Beantwortung Ihrer Anfrage, beziehungsweise Art. 6 Abs. 1 lit. b DSGVO,
        wenn es um ein Vertragsverhältnis geht. Wir löschen die Nachricht, sobald
        sie erledigt ist und keine Aufbewahrungspflicht entgegensteht.
      </p>

      <h2>4. Rechtsgrundlagen</h2>
      <ul>
        <li>
          Bereitstellung dieser Website und der Server-Logs: Art. 6 Abs. 1 lit. f
          DSGVO (berechtigtes Interesse an einem sicheren, funktionierenden
          Angebot)
        </li>
        <li>
          Auslieferung eines Artenpakets, das Erwachsene selbst anstoßen: Art. 6
          Abs. 1 lit. b DSGVO (Erfüllung der angefragten Leistung)
        </li>
        <li>E-Mail-Kontakt: Art. 6 Abs. 1 lit. f bzw. lit. b DSGVO</li>
      </ul>
      <p>
        Für die App selbst gibt es keine Verarbeitung durch uns, weil sie keine
        Daten an uns übermittelt.
      </p>

      <h2>5. Speicherdauer</h2>
      <ul>
        <li>
          Daten in der App: bleiben auf dem Gerät, bis das Profil oder die App
          gelöscht wird
        </li>
        <li>Server-Logs dieser Website: 24 Stunden</li>
        <li>Zugriffsprotokolle des Medienservers: 30 Tage</li>
        <li>E-Mails: bis die Anfrage erledigt ist</li>
      </ul>

      <h2>6. Ihre Rechte</h2>
      <p>
        Sie haben das Recht auf Auskunft (Art. 15 DSGVO), Berichtigung
        (Art. 16 DSGVO), Löschung (Art. 17 DSGVO), Einschränkung der
        Verarbeitung (Art. 18 DSGVO), Datenübertragbarkeit (Art. 20 DSGVO) und
        Widerspruch gegen eine Verarbeitung, die auf einem berechtigten Interesse
        beruht (Art. 21 DSGVO). Wenden Sie sich dafür an{' '}
        <a href={`mailto:${COMPANY_MAIL}`}>{COMPANY_MAIL}</a>.
      </p>
      <p>
        Weil die App weder ein Konto noch eine Kennung führt, können wir zu einem
        einzelnen Gerät oder Kind keine Auskunft geben — es gibt bei uns nichts,
        was sich zuordnen ließe. Die Daten in der App haben Sie selbst in der
        Hand.
      </p>

      <h2>7. Aufsichtsbehörde</h2>
      <p>
        Sie haben das Recht, sich bei einer Datenschutz-Aufsichtsbehörde zu
        beschweren. Für uns zuständig ist:
      </p>
      <address>
        Landesbeauftragte für Datenschutz und Informationsfreiheit
        Nordrhein-Westfalen
        <br />
        Postfach 20 04 44
        <br />
        40102 Düsseldorf
        <br />
        <a href="https://www.ldi.nrw.de">https://www.ldi.nrw.de</a>
      </address>

      <h2>8. Änderungen dieser Erklärung</h2>
      <p>
        Wenn die App oder diese Website sich ändern, ändert sich diese Erklärung
        mit. Es gilt die Fassung, die hier steht; das Datum oben sagt, wann sie
        zuletzt bearbeitet wurde. Was ZilpZalp mit Daten macht, steht außerdem in{' '}
        <Link href="/agb">den AGB</Link> und im{' '}
        <Link href="/support">Support-Bereich</Link>.
      </p>
    </LegalPage>
  )
}
