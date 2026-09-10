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
    'ZilpZalp bringt Kindern die Vögel vor der eigenen Haustür nahe. Zwei Spiele, 70 heimische Arten, ohne Lesen, ohne Konto, ohne Werbung, ohne Datenerhebung.',
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
