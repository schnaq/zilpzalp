import type { SVGProps } from 'react'

// A handful of drawn marks in one stroke weight — 24px grid, 2px stroke, round
// caps and joins, the same drawing rules as the Lucide set the app uses. They
// are decoration next to a label that already says the thing, so every one of
// them is aria-hidden and none carries a title.

function Icon({ size = 24, ...props }: SVGProps<SVGSVGElement> & { size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth={2}
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden
      focusable="false"
      {...props}
    />
  )
}

/// A spoken question — game 1 reads the bird's name aloud.
export function SpeechIcon(props: SVGProps<SVGSVGElement> & { size?: number }) {
  return (
    <Icon {...props}>
      <path d="M21 12a8 8 0 0 1-8 8H5l-2 2v-9a8 8 0 0 1 8-8h2a8 8 0 0 1 8 7z" />
      <path d="M9 11h.01M13 11h.01" />
    </Icon>
  )
}

/// A call — game 2 plays a recording of the bird.
export function CallIcon(props: SVGProps<SVGSVGElement> & { size?: number }) {
  return (
    <Icon {...props}>
      <path d="M11 5 6 9H3v6h3l5 4z" />
      <path d="M15.5 8.5a5 5 0 0 1 0 7" />
      <path d="M19 5a9 9 0 0 1 0 14" />
    </Icon>
  )
}

/// The reward star, filled — the app's own currency.
export function StarIcon({ size = 20, ...props }: SVGProps<SVGSVGElement> & { size?: number }) {
  return (
    <svg
      width={size}
      height={size}
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden
      focusable="false"
      {...props}
    >
      <path d="m12 2.6 2.9 5.9 6.5.9-4.7 4.6 1.1 6.5-5.8-3-5.8 3 1.1-6.5L2.6 9.4l6.5-.9z" />
    </svg>
  )
}

/// Present. Never a red cross anywhere on this site — the app's feedback rule
/// holds here too.
export function CheckIcon(props: SVGProps<SVGSVGElement> & { size?: number }) {
  return (
    <Icon size={20} {...props}>
      <path d="m4 12.5 5 5 11-11" />
    </Icon>
  )
}

/// Absent, as a plain dash in a ring: "there is none of this", not "wrong".
export function NoneIcon(props: SVGProps<SVGSVGElement> & { size?: number }) {
  return (
    <Icon size={20} {...props}>
      <circle cx="12" cy="12" r="9" />
      <path d="M8 12h8" />
    </Icon>
  )
}
