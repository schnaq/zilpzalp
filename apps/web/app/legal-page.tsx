import type { ReactNode } from 'react'

/// The date every legal page carries. One constant, because four pages drifting
/// apart is how a reader learns not to trust the date at all.
const LEGAL_DATE = 'September 2026'

/// The frame around a legal text: heading, date, then prose at a readable
/// measure. Deliberately plain — this is a Read surface inside a Persuade site.
export function LegalPage({ title, children }: { title: string; children: ReactNode }) {
  return (
    <main className="legal">
      <div className="wrap">
        <div className="legal-head">
          <h1 id="inhalt">{title}</h1>
          <p className="legal-date">Letzte Aktualisierung: {LEGAL_DATE}</p>
        </div>
        <div className="prose">{children}</div>
      </div>
    </main>
  )
}

/// A gap only Christian can close. Marked loudly on purpose: an unfilled
/// placeholder in a legal text must never read as finished copy.
export function Todo({ children }: { children: ReactNode }) {
  return <span className="todo">[Christian: {children}]</span>
}
