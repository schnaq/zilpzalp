import { existsSync } from 'node:fs'
import { join } from 'node:path'
import Image from 'next/image'

// The five screens from issue #168, in store order. Each frame draws a warm
// placeholder until the PNG named here lies in public/screenshots — the file
// check runs while the page is prerendered, so dropping the images in and
// building again is the entire swap. See public/screenshots/README.md.
const SHOTS = [
  {
    file: '01-start.png',
    title: 'Start',
    text: 'Zwei Kacheln, zwei Spiele. Mehr steht hier nicht.',
    alt: 'Der Startbildschirm von ZilpZalp mit den Kacheln für beide Spiele.',
  },
  {
    file: '02-erkenne-den-vogel.png',
    title: 'Erkenne den Vogel',
    text: 'Der Name wird vorgelesen, vier Fotos warten.',
    alt: 'Spiel 1: eine vorgelesene Frage über vier Vogelfotos.',
  },
  {
    file: '03-wer-singt-da.png',
    title: 'Wer singt da?',
    text: 'Die Stimme lässt sich beliebig oft wiederholen.',
    alt: 'Spiel 2: der Lautsprecher-Knopf über vier Vogelfotos.',
  },
  {
    file: '04-sterne.png',
    title: 'Sterne',
    text: 'Am Ende jeder Runde: bis zu drei Sterne.',
    alt: 'Das Rundenende mit drei Sternen und einem neuen Sticker.',
  },
  {
    file: '05-sammlung.png',
    title: 'Sammlung',
    text: 'Fünfmal auf Anhieb erkannt — dann klebt der Sticker hier.',
    alt: 'Die Sammlung mit den Stickern der schon erkannten Vögel.',
  },
]

export function Screenshots() {
  return (
    <div className="shots">
      {SHOTS.map((shot) => {
        const shipped = existsSync(join(process.cwd(), 'public', 'screenshots', shot.file))
        return (
          <figure className="shot" key={shot.file}>
            <div className="shot-frame">
              {shipped ? (
                <Image
                  src={`/screenshots/${shot.file}`}
                  alt={shot.alt}
                  width={560}
                  height={1216}
                  unoptimized
                />
              ) : (
                <span>Screenshot folgt</span>
              )}
            </div>
            <figcaption>
              <b>{shot.title}</b>
              {shot.text}
            </figcaption>
          </figure>
        )
      })}
    </div>
  )
}
