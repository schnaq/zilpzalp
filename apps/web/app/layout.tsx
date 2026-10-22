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
    'Vögel kennenlernen, ohne lesen zu können: zwei Spiele, über 300 Arten, für Kinder und alle Großen, die mitlernen wollen. Kein Konto, keine Werbung, kein Tracking.',
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
