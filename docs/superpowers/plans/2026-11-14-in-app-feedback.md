# In-App Feedback Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A grown-up takes a system screenshot during a round, taps a quiet hint, passes the parental gate, picks the tile and what is wrong with it, and sends a pre-filled mail (screenshot only if they switch it on) from their own mail app.

**Architecture:** The report itself is a pure value in `ZilpZalpData` (`FeedbackSnapshot` → `FeedbackReport`, which builds the context block and the body), tested with Swift Testing. The app target only wires things up. `QuizSession` freezes a snapshot of the round, and a `QuizScreen` modifier watches for the screenshot notification, renders the app's own window and shows the hint. A sheet then runs gate → form → `MFMailComposeViewController`, or `ShareLink` when no mail account is set up. When the sheet closes, the round carries on without asking the question again.

**Tech Stack:** Swift 6, SwiftUI, UIKit (window snapshot), MessageUI, Swift Testing; Next.js page in `apps/web`.

**Spec:** `docs/superpowers/specs/2026-11-14-in-app-feedback-design.md` (approved 2026-11-14), plus `docs/superpowers/specs/2026-08-01-zilpzalp-v1-design.md` §5/§7 for privacy and the Kids Category.

## Global Constraints

- Kids Category: no third-party SDK and no new network path. Any hand-off out of the app goes behind `ParentalGate`. `PrivacyInfo.xcprivacy` stays unchanged.
- Nothing leaves the device unless the grown-up presses „Senden“ in their own mail app or share target.
- Never attached: the profile name, stars, stickers, anything from Photos, or anything outside the app's own window. `FeedbackSnapshot` has no field for any of these, so this holds by construction.
- The screenshot is attached only with explicit consent, every time. The toggle starts **off** on every presentation and is never persisted.
- A report never loses or restarts the round. The round pauses on the hint tap. Speech and calls stop and are **not** replayed when the sheet closes.
- Product copy is German and lives in `apps/ZilpZalp/Resources/Localizable.xcstrings` (`extractionState: manual`, `comment`, `de` `translated`). Grown-ups are addressed as „Sie“, as in `parents.gate.reason`. Code, comments and commits are English.
- `ZilpZalpData` must not import SwiftUI/UIKit and contains no German copy. Game and difficulty go in as strings, because Data does not depend on Core.
- Recipient: `zilpzalp-app@posteo.net`.
- Local verification: `mise run check`, `mise run test` and `mise run build` all depend on the `xcode-version` gate, which fails locally (active 27.2, pin 27.0). **Never change the pin.** Run the pieces directly:
  - `xcrun swift test --package-path packages/<Package>`
  - `swiftformat apps packages --lint`
  - `swiftlint --strict --quiet`
  - `mise run license-gate` (no Xcode dependency)
  - `xcodegen generate --spec apps/ZilpZalp/project.yml --quiet`, then `xcodebuild build -project apps/ZilpZalp/ZilpZalp.xcodeproj -scheme ZilpZalp -destination "generic/platform=iOS Simulator" -derivedDataPath DerivedData CODE_SIGNING_ALLOWED=NO | xcbeautify`

  CI runs the full check.
- After every change: `/simplify`, then `/code-review`, before reporting done (owner's rule).

## Review Focus

1. **A screenshot taken while the quiz screen is not the visible round must do nothing.** `QuizScreen` stays alive in the `NavigationStack` under the round end, so this covers the round end, a finished round, the quit card and an already-open feedback sheet. Otherwise the report would snapshot the wrong screen with stale context. Pinned in Task 3 (the `isActive` guard) and checked manually in Task 3 Step 4.
2. **The child answers, or the round moves on, between the screenshot and the hint tap.** The report must still describe the moment of the screenshot, and after the sheet closes the round must go on instead of hanging on an answered question. Covered by the snapshot frozen in the handler (Task 3) and `carryOn()` (Task 2), and checked manually in Task 4 Step 4.
3. **Closing the sheet must not speak the name or play the call again.** Neither `resume()` nor `open()` may run on dismissal. Covered by `carryOn()` (Task 2) and checked manually in Task 4 Step 4.
4. **A tile whose dealt photo file is missing** must report the file the tile actually showed: the portrait fallback, or `none` when nothing opened. Pinned by `shownIndex` in Task 2 and by the `photo: none` test in Task 1.
5. **A note of only whitespace or newlines** must not leave blank lines in front of the context block. Pinned by `bodyWithoutNoteIsTheContextAlone` in Task 1.

Known and accepted: playtime runs from the first question to the last answer, so time spent in the sheet counts toward the child's daily budget. On a Mac (“Designed for iPad”) the notification may never fire, and then the feature is simply unreachable there (design doc).

---

### Task 0: Put the design doc and this plan on the branch

The design doc and this plan are untracked on `main`, so a worktree branched from `main` would not contain them.

- [ ] **Step 1: Mark the design approved.** In `docs/superpowers/specs/2026-11-14-in-app-feedback-design.md`, change the Status line to `Status: approved by Christian, 2026-11-14.`
- [ ] **Step 2: Commit both files** on the feature branch before any code.
  ```bash
  git add docs/superpowers/specs/2026-11-14-in-app-feedback-design.md docs/superpowers/plans/2026-11-14-in-app-feedback.md
  git commit -m "docs: plan in-app feedback"
  ```

### Task 1: Feedback report value and pack lookup (ZilpZalpData)

**Files:**
- Create: `packages/ZilpZalpData/Sources/ZilpZalpData/FeedbackReport.swift`
- Modify: `packages/ZilpZalpData/Sources/ZilpZalpData/PackLibrary.swift` (add `packID(for:)` beside `callURL(for:)`)
- Test: `packages/ZilpZalpData/Tests/ZilpZalpDataTests/FeedbackReportTests.swift`, `packages/ZilpZalpData/Tests/ZilpZalpDataTests/PackLibraryTests.swift`

**Interfaces:**
- Consumes: `MediaAsset` (`file`, `sha256`), `PackLibrary`'s private `catalog(for:)`.
- Produces:

```swift
public struct FeedbackSnapshot: Hashable, Sendable {
    public struct Tile: Hashable, Sendable {
        public let species: String      // "amsel"
        public let name: String         // "Amsel"
        public let pack: String?        // owning pack id
        public let photo: MediaAsset?   // the file the tile showed, nil if none opened
        public init(species: String, name: String, pack: String?, photo: MediaAsset?)
    }
    public let game: String             // "names" | "calls"
    public let difficulty: String       // Difficulty.rawValue
    public let question: Int            // 1-based
    public let questionCount: Int
    public let tiles: [Tile]            // grid order
    public let answer: String?          // species asked for
    public let call: MediaAsset?        // the call the question plays; nil in game 1
    public let app: String              // "1.3.0 (231)"
    public let system: String           // "iOS 27.1"
    public let device: String           // "iPhone17,3"
    public init(...)                    // memberwise, all fields in this order
}
public enum FeedbackTarget: Hashable, Sendable { case tile(String), call, other }
public enum FeedbackReason: String, CaseIterable, Sendable {
    case blurry, crop, wrongBird = "wrong-bird", call, name, other
}
public struct FeedbackReport: Hashable, Sendable {
    public static let recipient = "zilpzalp-app@posteo.net"
    public init(snapshot: FeedbackSnapshot, target: FeedbackTarget, reason: FeedbackReason, note: String)
    public var birdName: String?        // tile's name; answer's name for .call; nil for .other
    public var context: String
    public func body(recipient: String? = nil) -> String
}
extension PackLibrary { public func packID(for bird: Bird) -> String? }
```

The `context` format is fixed, so the code below is the spec (`·` is U+00B7, sha256 is cut to its first 12 characters). For `.tile`:

```
reason: crop
pack: deutschland · bird: amsel · photo: photos/amsel-3.heic (sha256 c8cb5d756971)
game: names · difficulty: medium · screen: question 3 of 10
tiles: amsel, kohlmeise, rotkehlchen, star
app: 1.3.0 (231) · iOS 27.1 · iPhone17,3
```

- For `.call`, line 2 is `pack: … · bird: <answer> · call: <file> (sha256 …)`. The pack comes from the answer's tile.
- For `.other`, line 2 is left out.
- A tile without a photo writes `photo: none`, and a missing pack writes `pack: none`.
- `body(recipient:)` joins its non-empty parts with a blank line (`"\n\n"`), in this order:
  - the recipient
  - the trimmed note (whitespace and newlines)
  - `context`

The subject is not built in the package because it is German copy. The app formats it from `birdName` (Task 4).

- [ ] **Step 1: Write the failing tests** in `FeedbackReportTests.swift` (`@testable import ZilpZalpData`, which provides `MediaAsset`'s memberwise init).
  - Use a fixture snapshot: `deutschland`, game `names`, `medium`, question 3 of 10. The tiles are `amsel` (photo `photos/amsel-3.heic`, sha `c8cb5d7569716cb2…`), `kohlmeise`, `rotkehlchen` and `star`. Answer `amsel`, call nil, app `1.3.0 (231)`, `iOS 27.1`, `iPhone17,3`.
  - `contextFindsThePhoto()`: `#expect(report(.tile("amsel"), .crop).context == <the five lines above>)`
  - `contextForTheCallNamesTheRecording()`: game `calls`, call `audio/amsel.m4a` / `825fde8b3c6c…`. Expect line 2 == `"pack: deutschland · bird: amsel · call: audio/amsel.m4a (sha256 825fde8b3c6c)"`.
  - `contextForSomethingElseHasNoAssetLine()`: `.other`. Expect 4 lines and no line with the prefix `pack:`.
  - `aTileWithoutPhotoSaysSo()`: the `kohlmeise` tile has photo nil, and `.tile("kohlmeise")`. Expect line 2 to contain `photo: none`.
  - `birdNameFollowsTheTarget()`: `.tile("star")` → `"Star"`, `.call` → `"Amsel"`, `.other` → `nil`.
  - `bodyPutsTheNoteFirst()`: note `"  Kopf abgeschnitten\n"`. Expect `body() == "Kopf abgeschnitten\n\n" + context`.
  - `bodyWithoutNoteIsTheContextAlone()`: note `" \n "`. Expect `body() == context`.
  - `shareBodyStartsWithTheAddress()`: `body(recipient: FeedbackReport.recipient).hasPrefix("zilpzalp-app@posteo.net\n\n")`.
- [ ] **Step 2: Add the failing pack test.** In `PackLibraryTests.swift`, add `namesThePackTheShownCopyCameFrom()`, reusing the setup of `prefersTheCopyWithACall`:
  - `library.packID(for: amsel) == "welt"`
  - `library.packID(for: star) == "basis"`
  - `library.narrowed(toPacks: ["basis"])?.packID(for: amsel) == "welt"`, because photos and calls come from that copy.
- [ ] **Step 3: Run to verify the tests fail.** Run `xcrun swift test --package-path packages/ZilpZalpData --filter 'FeedbackReport|namesThePack'`. Expected: compile errors for the missing `FeedbackReport` and `packID`.
- [ ] **Step 4: Implement.** Write `FeedbackReport.swift` with the interfaces above, and `packID(for:)` as `catalog(for: bird)?.pack.id`.
- [ ] **Step 5: Run to verify they pass.** Run the same command. Expected: all pass. Then run the whole package, `swiftformat apps packages --lint` and `swiftlint --strict --quiet`, all clean.
- [ ] **Step 6: Commit.**
  ```bash
  git add packages/ZilpZalpData
  git commit -m "feat: describe a feedback report as a value"
  ```

### Task 2: Round snapshot and quiet continue (app target)

**Files:**
- Modify: `apps/ZilpZalp/Sources/Quiz/QuizSession.swift`
- Modify: `apps/ZilpZalp/Sources/Quiz/QuizPhotos.swift`
- Modify: `apps/ZilpZalp/Sources/Route.swift` (`enum Game: String, Hashable`, raw values `names` and `calls`)
- Modify: `apps/ZilpZalp/Sources/Quiz/QuitConfirmation.swift` (`isAsking`: `fileprivate private(set)` → `private(set)`, so `QuizScreen` can read it)

**Interfaces:**
- Consumes: `FeedbackSnapshot`, `PackLibrary.packID(for:)` (Task 1).
- Produces:
  - `QuizPhotos.shownIndex(_ species: String, question: Int) -> Int?`: the index `photo(_:question:)` actually shows (the dealt one if it opened, else 0 if that opened, else nil). `photo(_:question:)` reads through it, so the two cannot drift.
  - `QuizSession.feedbackSnapshot(app: String, system: String, device: String) -> FeedbackSnapshot?`: nil when `isFinished`. Tiles come from `play.question?.choices` in order, with the photo `bird.photos[shownIndex]`. The pack comes from a `[String: String]` built once in `init` from `library.packID(for:)`. `call` is `answer?.call` only when `game == .calls`. `question` is `index + 1`.
  - `QuizSession.carryOn()`: picks the round up after feedback **without** asking again. If `play.isAnswered`, it calls `nextQuestion()` (whose next question is asked normally). Otherwise it does nothing.

- [ ] **Step 1: Implement `shownIndex` and route `photo(_:question:)` through it.**
- [ ] **Step 2: Implement `packs`, `feedbackSnapshot(app:system:device:)` and `carryOn()`, plus the `Game` and `isAsking` changes.** Doc comments say why `carryOn` is not `resume()`: the design says calls and speech do not replay.
- [ ] **Step 3: Verify.** Generate and build with the `xcodebuild` line from Global Constraints. Expected: `** BUILD SUCCEEDED **`. Run `swiftformat apps packages --lint` and `swiftlint --strict --quiet`, both clean. This app wiring has no unit tests, by design (AGENTS.md). It is exercised in Task 4.
- [ ] **Step 4: Commit.**
  ```bash
  git add apps/ZilpZalp/Sources
  git commit -m "feat: snapshot a round for feedback"
  ```

### Task 3: Screenshot observer, window capture and hint

**Files:**
- Create: `apps/ZilpZalp/Sources/Feedback/FeedbackCapture.swift`
- Create: `apps/ZilpZalp/Sources/Feedback/FeedbackHint.swift`
- Create: `apps/ZilpZalp/Sources/Feedback/FeedbackSheet.swift` (gate only in this task)
- Modify: `apps/ZilpZalp/Sources/Quiz/QuizScreen.swift`
- Modify: `apps/ZilpZalp/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `QuizSession.feedbackSnapshot`, `carryOn()`, `suspend()`, `photo(for:)`, `choices` (Task 2); `ParentalGate(reason:onSuccess:)`.
- Produces:

```swift
struct FeedbackCapture: Identifiable {
    let id = UUID()
    let screenshot: UIImage
    let snapshot: FeedbackSnapshot
    let thumbnails: [String: Image]     // species id → the tile image at that moment
    @MainActor static func take(of session: QuizSession) -> FeedbackCapture?
}
extension View {
    func feedbackOnScreenshot(session: QuizSession?, isActive: Bool) -> some View
}
struct FeedbackSheet: View { let capture: FeedbackCapture; let onDone: () -> Void }
```

- `take(of:)` captures everything synchronously, before any state changes, so the hint is never in the image:
  - Window: the key window of the first `UIWindowScene`, rendered with `UIGraphicsImageRenderer(bounds:)` and `drawHierarchy(in:afterScreenUpdates: false)`. It never touches Photos.
  - App: `"\(CFBundleShortVersionString) (\(CFBundleVersion))"`.
  - System: `UIDevice.current.systemName + " " + systemVersion`.
  - Device: `utsname.machine`, or `ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"]` when that is set.
- `feedbackOnScreenshot` holds `@State pending: FeedbackCapture?` (the hint) and `@State open: FeedbackCapture?` (the sheet):
  - `.onReceive(NotificationCenter.default.publisher(for: UIApplication.userDidTakeScreenshotNotification))`: guard on `isActive`, `open == nil` and `session?.isFinished == false`, then `pending = .take(of:)`.
  - The hint is a `.overlay(alignment: .top)` with `ZButton(String(localized: "feedback.hint"), tone: .quiet, size: .medium, leadingIcon: .mail)`, using `.transition(.move(edge: .top).combined(with: .opacity))`. Animation is nil under Reduce Motion, as in `QuitQuestion`. Nothing is spoken.
  - The hint goes away after `.task(id: pending?.id)` sleeps `.seconds(5)` and then sets `pending = nil`. It is also cleared when `isActive` turns false.
  - A tap calls `session?.suspend()`, then `open = pending` and `pending = nil`.
  - `.sheet(item: $open, onDismiss: { session?.carryOn() })` shows `FeedbackSheet`. It uses a `.sheet`, never a `fullScreenCover`, so `QuizScreen`'s `onAppear`/`open()` (which would re-ask) does not run.
- `QuizScreen` adds `@State isOnScreen`, set true in `open()` and in the existing `.onChange(of: askedFor)` (appearance is not always delivered, #157), and false in `onDisappear`. It applies `.feedbackOnScreenshot(session: session, isActive: isOnScreen && !leaving.isAsking)` **before** `.quitQuestion`, so the quit card covers the hint.
- `FeedbackSheet` in this task: `ParentalGate(reason: String(localized: "feedback.gate.reason")) { onDone() }`, dressed like `ExternalLinkGate` (`.background(ZColor.surfacePage)`, `.presentationSizing(.page)`). Task 4 replaces `onDone()` with the form.

- [ ] **Step 1: Add the catalog keys.**

| Key | de | comment |
|---|---|---|
| `feedback.hint` | Feedback zu diesem Bild? | Quiet hint at the top of a round after a system screenshot; opens the parental gate |
| `feedback.gate.reason` | Hier können Sie uns ein Problem mit einem Bild oder Ruf melden. | Why the parental gate is shown: feedback on a tile from inside a round |

- [ ] **Step 2: Implement the three files and the `QuizScreen` wiring.**
- [ ] **Step 3: Build and lint.** Use the commands from Global Constraints. Expected: build succeeds, lint is clean.
- [ ] **Step 4: Check manually in the simulator (Xcode run).** `xcrun simctl io booted screenshot` and the Simulator/DeviceHub screenshot commands are host captures and are not known to post the notification, so post it from LLDB. Pause the app, then:

  ```
  thread select 1
  expr -l Swift -- import UIKit; NotificationCenter.default.post(name: UIApplication.userDidTakeScreenshotNotification, object: nil)
  ```

  If the Swift expression does not parse, use the Objective-C form instead, which needs no import:

  ```
  e -l objc -- (void)[[NSNotificationCenter defaultCenter] postNotificationName:@"UIApplicationUserDidTakeScreenshotNotification" object:nil]
  ```

  Then continue and check:
  - **In a round:** the hint slides in, disappears after about 5 s, and nothing is spoken.
  - **Tapping the hint:** the call or speech stops and the gate appears. Solving it closes the sheet. The question is **not** spoken again, and the round goes on from the same question.
  - **Round end, quit card up, home screen:** posting the notification shows no hint.

  The real side button + volume up can only be checked on a device or in TestFlight.
- [ ] **Step 5: Commit.**
  ```bash
  git add apps/ZilpZalp
  git commit -m "feat: offer feedback after a screenshot in a round"
  ```

### Task 4: Feedback form, mail composer and share fallback

**Files:**
- Modify: `apps/ZilpZalp/Sources/Feedback/FeedbackSheet.swift`
- Modify: `apps/ZilpZalp/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `FeedbackCapture` (Task 3); `FeedbackReport`, `FeedbackTarget`, `FeedbackReason`, `FeedbackReport.recipient` (Task 1).
- Produces (file-private):
  - `FeedbackSheet` stages: `enum Stage { case gate, form, mail(FeedbackReport) }`. The gate's success leads to `.form`.
  - `extension FeedbackReason { var label: String }`: a `switch` over the six `feedback.reason.*` keys, as literal `String(localized:)` keys.
  - `func subject(for report: FeedbackReport) -> String`: `feedback.mail.subject.bird` with `(birdName, label)` when `birdName` is set, otherwise `feedback.mail.subject` with `(label)`.
  - `struct MailComposer: UIViewControllerRepresentable`, with `(report: FeedbackReport, subject: String, screenshot: UIImage?, onFinish: () -> Void)`. It sets `setToRecipients([FeedbackReport.recipient])`, the subject and `setMessageBody(report.body(), isHTML: false)`. When there is a screenshot, it calls `addAttachmentData(pngData, mimeType: "image/png", fileName: "zilpzalp.png")`. The coordinator's `mailComposeController(_:didFinishWith:error:)` calls `onFinish` whatever the result.

The form is a native `Form` with `.grownUpDynamicType()`. Its sections, in order:
1. The screenshot, small, about 160 pt tall, `scaledToFit`.
2. „Welches Bild?“: a row of the tiles' thumbnails with the bird's name under each (fine for grown-ups, since it sits behind the gate). The selection gets a `ZColor` border. Then „Der Ruf“, only if `snapshot.call != nil`, and „Etwas anderes“. The default is `.other`.
3. „Was stimmt nicht?“: an inline `Picker` over `FeedbackReason.allCases`, default `.other`.
4. A `TextField(axis: .vertical)` with the placeholder `feedback.note`.
5. A `Toggle` „Screenshot mitschicken“, `@State` default `false`, with the one-line hint below it.
6. The action. If `MFMailComposeViewController.canSendMail()`, a button „E-Mail schreiben“ sets `.mail(report)`. Otherwise `ShareLink` „Feedback teilen“ with `report.body(recipient: FeedbackReport.recipient)` and the subject. When the toggle is on, the item is `Image(uiImage: screenshot)` with that text as `message:` and a `SharePreview`.

In the `.mail` stage, `MailComposer`'s `onFinish` calls `onDone()`. The sheet closes, and its `onDismiss` calls `carryOn()` (Task 3).

`ShareLink` gives no completion callback, so after sharing the grown-up is back on the form and swipes the sheet away. That is the one deliberate deviation from “the sheet closes” in the design. Replace it with a `UIActivityViewController` representable only if the owner wants it.

- [ ] **Step 1: Add the catalog keys**, with the `comment` naming the place: the feedback sheet for grown-ups, or the mail subject.

| Key | de |
|---|---|
| `feedback.title` | Feedback |
| `feedback.target.title` | Welches Bild? |
| `feedback.target.call` | Der Ruf |
| `feedback.target.other` | Etwas anderes |
| `feedback.reason.title` | Was stimmt nicht? |
| `feedback.reason.blurry` | Foto unscharf oder schlecht |
| `feedback.reason.crop` | Ausschnitt schlecht |
| `feedback.reason.wrongBird` | Falscher Vogel |
| `feedback.reason.call` | Ruf schlecht |
| `feedback.reason.name` | Name oder Aussprache |
| `feedback.reason.other` | Sonstiges |
| `feedback.note` | Möchten Sie etwas dazuschreiben? |
| `feedback.screenshot.toggle` | Screenshot mitschicken |
| `feedback.screenshot.hint` | Nur dieser Bildschirm von ZilpZalp, sonst nichts. |
| `feedback.send` | E-Mail schreiben |
| `feedback.share` | Feedback teilen |
| `feedback.mail.subject.bird` | ZilpZalp-Feedback: %1$@ – %2$@ |
| `feedback.mail.subject` | ZilpZalp-Feedback: %@ |

- [ ] **Step 2: Implement the form, `MailComposer` and the stage switch.** `import MessageUI` autolinks the framework, so `project.yml` needs no change, and the build proves it.
- [ ] **Step 3: Build and lint**, as in Task 3. Expected: build succeeds, lint is clean.
- [ ] **Step 4: Check manually in the simulator** (trigger as in Task 3 Step 4). `canSendMail()` is false there, so this exercises the share path:
  - **Form after the gate:** the four thumbnails appear, „Der Ruf“ shows in game 2 only, and the toggle is off.
  - **„Feedback teilen“:** the share text starts with `zilpzalp-app@posteo.net`, then the note, then the context block, with the reason, pack, file and tiles as in Task 1.
  - **Screenshot toggle:** with it on, the image is shared. With it off, only the text is.
  - **Closing the sheet:** the round continues silently.
  - **Answered before the hint tap:** answer the question while the hint is up, then tap the hint, pass the gate and close the sheet. The round moves to the next question and does not hang on the check mark.

  Device or TestFlight only:
  - the hardware screenshot,
  - the mail composer (recipient, subject `ZilpZalp-Feedback: Amsel – Ausschnitt schlecht`, attachment present only with the toggle on),
  - back to the round after Senden or Abbrechen.
- [ ] **Step 5: Commit.**
  ```bash
  git add apps/ZilpZalp
  git commit -m "feat: send feedback on a tile by mail"
  ```

### Task 5: Privacy policy and spec

**Files:**
- Modify: `apps/web/app/datenschutz/page.tsx` („Kurz gesagt“, 2.1, 3.3, closing paragraph of 4)
- Modify: `docs/superpowers/specs/2026-08-01-zilpzalp-v1-design.md` (§4, §5, §7)

**Interfaces:** none (copy only).

- [ ] **Step 1: Edit the privacy policy (German).** Without these edits, three existing sentences become untrue.
  - „Kurz gesagt“, after the first sentence: „Nur wenn Sie uns aus der App selbst eine Rückmeldung per E-Mail schicken, erhalten wir, was darin steht.“
  - 2.1, appended: „Eine Ausnahme machen nur Sie selbst: Schicken Sie uns aus der App eine Rückmeldung per E-Mail, erhalten wir diese Nachricht (siehe 3.3).“
  - 3.3, new paragraph: „Aus einer laufenden Runde können Sie uns nach einem Bildschirmfoto eine Rückmeldung zu einem Bild oder Ruf schicken. Die App bereitet dafür eine E-Mail vor; versendet wird sie von Ihrer eigenen Mail-App über Ihren E-Mail-Anbieter, und erst, wenn Sie dort auf „Senden“ tippen. Sie enthält Ihren Text, das gewählte Bild und den Grund, technische Angaben zu App und Gerät (App- und iOS-Version, Gerätemodell, Spiel, Schwierigkeit und Frage) und, nur wenn Sie es einschalten, ein Bildschirmfoto der App. Profilnamen, Sterne oder Sticker enthält sie nicht. Rechtsgrundlage ist Art. 6 Abs. 1 lit. f DSGVO, unser berechtigtes Interesse, Fehler in Bildern und Rufen zu beheben. Wir löschen die Nachricht, sobald die Meldung erledigt ist.“
  - 4, closing paragraph, appended: „Rückmeldungen, die Sie aus der App per E-Mail schicken, sind E-Mail-Kontakt im Sinne von 3.3.“
- [ ] **Step 2: Edit the spec (German).**
  - §4: a new paragraph, „Feedback zu einem Bild“, covering screenshot → hint → gate → sheet → mail/share. It says the round pauses and nothing is spoken again, and links to the design doc.
  - §5: one paragraph saying the app sends nothing itself. The mail goes through the user's mail app with „Senden“ every time, and the screenshot is opt-in, defaulting to off. It also explains why the privacy label stays “Data Not Collected” (Apple's “optional disclosure” rule), to be re-checked at submission.
  - §7, external-links bullet: add „und die Feedback-Mail aus der Runde“.
- [ ] **Step 3: Verify the site.** Run `mise run web:lint` and `mise run web:build`. Expected: both succeed, and `/datenschutz` is in the build output.
- [ ] **Step 4: Commit.**
  ```bash
  git add apps/web/app/datenschutz/page.tsx docs/superpowers/specs/2026-08-01-zilpzalp-v1-design.md
  git commit -m "docs: cover in-app feedback in privacy and spec"
  ```
