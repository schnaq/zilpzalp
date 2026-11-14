# In-app feedback on a bird, from inside a round

Status: approved by Christian, 2026-11-14.

## Intent

When a grown-up plays along and a tile is bad — a poor photo, a crop that cuts
the bird off, the wrong bird, a bad call — they want to report it right there,
from inside the game, without TestFlight and without remembering it for later.
The report reaches us with a screenshot of the app if they agree, and with
enough context that we can find the exact asset in `data/packs/` and fix it.

## Goals

- Report from inside a round (game 1 „Erkenne den Vogel" and game 2 „Wer singt
  da?"), at the moment the problem is on screen.
- Say which tile is meant, and what is wrong with it, in two or three taps.
- A screenshot only with explicit consent, each time.
- No new server, no new network traffic from the app.

## Non-goals

- Reports from the album, the round end or the parents' area. Possible later
  with the same sheet; not in this change.
- An inbox, ticket system, GitHub issues created from the app, or any automatic
  sending.
- Free-form bug reports about the app itself (crashes, layout). Mail via the
  About screen stays for that.

## Anti-goals (a failure even if it works)

- A child can send anything, or lands in a mail app, without solving the
  parental gate.
- Anything leaves the device without the grown-up pressing „Senden" in their
  own mail app.
- The profile name, a photo from the device, or anything outside the app's own
  window is attached.
- The round is lost or restarted because someone reported a tile.

## Constraints

- Kids Category (AGENTS.md): no third-party SDKs, external hand-offs only
  behind the parental gate, `PrivacyInfo.xcprivacy` declares no data
  collection.
- The app talks only to its own S3 bucket at runtime. Mail composed by the user
  is sent by the system's mail app, not by ZilpZalp.
- App Store privacy label: Apple's "optional disclosure" rule
  (developer.apple.com/app-store/app-privacy-details) exempts data from
  optional feedback forms when it is infrequent, not primary functionality,
  optional, provided by the user in the app's interface with their account
  shown in the submission form, and affirmatively chosen each time. The system
  mail composer shows the sender's address and needs „Senden" every time, so
  the label stays "Data Not Collected". Re-check this when submitting.
- Product copy German, code and docs English.

## Approaches

1. **Mail from the app (chosen).** After the parental gate, a short feedback
   sheet, then the system mail composer pre-filled to
   `zilpzalp-app@posteo.net` with the screenshot attached and a context block.
   Without a mail account, the share sheet with the same text and image.
   *Trade-off:* the grown-up sends it themselves and needs a mail app or the
   share sheet; we read reports in the support inbox. No server, no secret,
   no new network path, privacy policy section 3.3 already covers e-mail.
2. **Upload to an endpoint of our own** (a route on the Vercel site storing to
   S3 or forwarding to mail). One tap, works without a mail app. *Rejected:*
   breaks "the app talks only to S3", needs spam/abuse protection and a
   server-side secret, and the privacy label would have to declare user
   content — a heavier App Review story for a Kids Category app.
3. **Create GitHub issues from the app.** *Rejected:* needs a token in the
   binary.

Trigger, also decided with Christian's use case („im Spiel, wenn der Vogel
oder der Ausschnitt schlecht ist"):

- **A normal iOS screenshot inside a round (chosen).** No extra button for
  children to see; works on every quiz screen.
- A report button on each tile or in the album — rejected: visible clutter for
  children, and the album misses problems that only show in a round.
- „Vogel melden" in the parents' area — rejected: no screenshot of the actual
  problem, and the grown-up must find the bird again.

## The flow

1. During a round, someone takes a system screenshot (side button + volume
   up). The app observes `UIApplication.userDidTakeScreenshotNotification`
   and, at that moment, renders its **own window** into an image — it never
   reads the Photos library and needs no permission.
2. A small, quiet hint slides in at the top for a few seconds:
   „Feedback zu diesem Bild?" — dismisses itself; a child who ignores it loses
   nothing. Nothing is spoken.
3. Tapping it pauses the round where it is and shows the existing parental
   gate (`ParentalGate`).
4. The feedback sheet (for grown-ups, text is fine):
   - the screenshot, small;
   - „Welches Bild?" — the round's tiles as thumbnails to tap one, plus „Der
     Ruf" in game 2 and „Etwas anderes";
   - „Was stimmt nicht?" — one of: Foto unscharf/schlecht, Ausschnitt
     schlecht, Falscher Vogel, Ruf schlecht, Name/Aussprache, Sonstiges;
   - an optional text field;
   - a toggle „Screenshot mitschicken", **on** only after the grown-up has
     seen it, and explained in one line;
   - „E-Mail schreiben".
5. The system mail composer opens: to `zilpzalp-app@posteo.net`, subject
   „ZilpZalp-Feedback: Amsel – Ausschnitt schlecht", the screenshot attached if
   the toggle is on, and a body with the grown-up's text followed by a context
   block meant for us:

   ```
   pack: deutschland · bird: amsel · photo: <observation>/<photo> (sha256 …)
   game: names · difficulty: medium · screen: question 3 of 10
   tiles: amsel, kohlmeise, rotkehlchen, star
   app: 1.3.0 (231) · iOS 27.1 · iPhone17,3
   ```

   No profile name, no stars, no stickers.
6. Sent, cancelled or failed — the sheet closes and the round continues where
   it stopped.

Without a configured mail account (`MFMailComposeViewController.canSendMail()`
is false), step 5 is the share sheet with the same text and image instead.

## Privacy policy (apps/web, German)

- The app section („erhebt keine personenbezogenen Daten") gains one sentence:
  unless a grown-up sends us feedback by e-mail themselves.
- Section 3.3 „Kontakt per E-Mail" gains feedback from the app: what the mail
  contains (their text, the chosen tile and reason, technical details of app
  and device, a screenshot of the app's screen if they choose), that it goes
  through their own mail provider, legal basis (Art. 6 Abs. 1 lit. f, as for
  e-mail today), and deletion when the report is dealt with.
- `PrivacyInfo.xcprivacy` unchanged (see constraints).
- Spec (`2026-08-01-zilpzalp-v1-design.md`) gets the feature and the privacy
  reasoning.

## Calls made while writing this up

- **The report describes the moment of the screenshot.** The image and the
  context block (tiles, photo, call, question number) are captured together in
  the notification handler. A child may answer before the hint is tapped; the
  report still shows what the grown-up saw.
- **No tile chosen** → reported as „Etwas anderes", and the subject carries no
  bird name.
- **Share-sheet fallback** cannot preset a recipient, so the body starts with
  the address as a line of text.
- **Mac („Designed for iPad")**: if a Mac screenshot does not fire the
  notification, the feature is simply unreachable there. No extra button.

## Left to the builder

- Where the context assembly lives: building the context block from the
  round state is pure and testable — a package (ZilpZalpData or Core) rather
  than the app target, if it fits the boundaries in AGENTS.md.
- How the round pauses (the quiz has its own state machine in
  `QuizSession`); calls and speech stop while the sheet is up and do not
  replay automatically afterwards.
- Exact copy of the hint and sheet (short, warm — see the copy style), and
  the reason list wording.
- How long the hint stays and how it looks, using ZilpZalpUI tokens.
- Whether the photo identifier in the context block is the manifest's
  observation/photo pair or the file path — whatever finds the asset fastest.
