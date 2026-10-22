import type { Metadata } from 'next'
import type { ReactNode } from 'react'
import { body, display } from './fonts'
import { Footer, Masthead } from './site-chrome'
import './globals.css'

export const metadata: Metadata = {
  metadataBase: new URL('https://zilpzalp.schnaq.com'),
  title: {
    default: 'ZilpZalp — Vögel entdecken für Kinder',
    template: '%s — ZilpZalp',
  },
  description:
    'Vögel kennenlernen mit zwei Spielen und über 300 Arten. Für Kinder, die noch nicht lesen, und für Große, die mitlernen. Kein Konto, keine Werbung, kein Tracking.',
  openGraph: {
    type: 'website',
    locale: 'de_DE',
    siteName: 'ZilpZalp',
  },
}

export default function RootLayout({ children }: { children: ReactNode }) {
  return (
    <html lang="de" className={`${display.variable} ${body.variable}`}>
      <body>
        <a className="skip" href="#inhalt">
          Zum Inhalt springen
        </a>
        <Masthead />
        {children}
        <Footer />
      </body>
    </html>
  )
}
