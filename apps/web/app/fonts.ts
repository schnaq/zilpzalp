import localFont from 'next/font/local'

// The two faces the app itself uses, served from this site's own origin. Both
// are variable fonts, so one file covers every weight the pages ask for and
// nothing is fetched from Google Fonts at build or at run time.

/// Baloo 2 — headings and the wordmark, as `--font-display`.
export const display = localFont({
  src: '../fonts/Baloo2-VariableFont_wght.ttf',
  weight: '400 800',
  display: 'swap',
  variable: '--font-display',
  // Baloo 2 is a rounded face; the fallbacks keep that character while the
  // file loads instead of flashing a grotesque.
  fallback: ['ui-rounded', 'Avenir Next', 'Trebuchet MS', 'system-ui', 'sans-serif'],
})

/// Nunito — everything that is read as text, as `--font-body`.
export const body = localFont({
  src: '../fonts/Nunito-VariableFont_wght.ttf',
  weight: '200 900',
  display: 'swap',
  variable: '--font-body',
  fallback: ['system-ui', 'Segoe UI', 'Helvetica Neue', 'sans-serif'],
})
