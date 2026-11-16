# Look Back in a Round Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A tap on an answered leaf of the quiz's progress row opens a card that pages through the round's answered questions as they were answered; closing it carries the round on where it stood.

**Architecture:** Core gains one count (`RoundPlay.answeredCount`). `ZilpZalpUI.QuizProgress` reports taps on done leaves and offers one VoiceOver action, with no game logic. The app's `QuizSession` gains read access to any answered question plus "ask that one again", and a new `LookBackCard` sheet on `QuizScreen` uses them; pausing and carrying on reuse `suspend()` / `carryOn()` exactly like the feedback sheet.

**Tech Stack:** Swift 6, SwiftUI, Swift Testing, mise.

**Spec:** `docs/superpowers/specs/2026-11-16-look-back-in-round-design.md`

## Global Constraints

- Run everything through mise (`mise run test`, `mise run check`, `mise run build`); never `xcodebuild`/`swift` directly. Local `mise run check` stops at the Xcode gate ("Xcode 27.0 expected, active is 27.2") — CI on Gimli is the full gate; locally run `mise run test` and `mise run format`, and build/run the app in the simulator.
- Do not change the Xcode pin.
- `ZilpZalpCore`: no SwiftUI/UIKit. `ZilpZalpUI`: no game logic, no German copy (caller passes strings).
- Product copy German in `apps/ZilpZalp/Resources/Localizable.xcstrings`; code, comments, commits, PR English. Conventional Commits, subject ≤ 50 chars.
- No digits anywhere a child looks (page indicator included).
- `SpeechMode.speaks(unprompted:)` holds: nothing in the card is spoken unprompted.
- Tap targets ≥ 44 pt (`ZSpacing.touchMinimum`).

## Review Focus

1. Card opened during the **last** answer's pause: the round end must not open behind the card; on close it opens. (Task 3, simulator check a.)
2. Game 2: a call played from the card, then the card closed — the call stops; nothing sounds over the live question. (Task 3, check b.)
3. iPhone SE (24 pt leaves, 10 questions): each answered leaf opens on *its* question, the live/upcoming leaves do nothing. (Task 2 test + Task 3, check c.)
4. „Nur auf Knopfdruck": closing the card on an open question speaks nothing. (Task 3, check d.)
5. Card closed after a wrong tap on the live question: the live question still shows its retry state. (Task 3, check e.)

---

### Task 1: `RoundPlay.answeredCount`

**Files:**
- Modify: `packages/ZilpZalpCore/Sources/ZilpZalpCore/RoundPlay.swift`
- Test: `packages/ZilpZalpCore/Tests/ZilpZalpCoreTests/RoundPlayTests.swift`

**Interfaces:**
- Produces: `public var answeredCount: Int` — the questions answered so far, `index` plus one while the current question is answered, never above `round.questions.count`. Questions `0 ..< answeredCount` are exactly the ones whose answer was found (every `advance()` follows a correct tap — doc comment says so).

- [ ] **Step 1: Failing tests** (use the file's `dealt()` / `answer(of:)` / `distractor(of:)` helpers)

```swift
@Test("Nothing is answered before the first right tap")
func answeredCountStartsAtZero() throws {
    var play = try dealt()
    #expect(play.answeredCount == 0)
    _ = try play.tap(distractor(of: play))
    #expect(play.answeredCount == 0)
}

@Test("A right answer counts at once, before the round moves on")
func answeredCountCountsTheAnswer() throws {
    var play = try dealt()
    _ = try play.tap(answer(of: play))
    #expect(play.answeredCount == 1)
    play.advance()
    #expect(play.answeredCount == 1)
}

@Test("A finished round has every question answered")
func answeredCountOfAFinishedRound() throws {
    var play = try dealt(questionCount: 3)
    while !play.isFinished {
        _ = try play.tap(answer(of: play))
        play.advance()
    }
    #expect(play.answeredCount == 3)
}
```

- [ ] **Step 2:** `mise run test` → the three fail (no member `answeredCount`).
- [ ] **Step 3:** Implement `answeredCount` (`min(index + (isAnswered ? 1 : 0), round.questions.count)`).
- [ ] **Step 4:** `mise run test` → pass.
- [ ] **Step 5:** Commit `feat(core): count the answered questions`.

### Task 2: `QuizProgress` opens answered leaves

**Files:**
- Modify: `packages/ZilpZalpUI/Sources/ZilpZalpUI/Components/QuizProgress.swift`
- Test: `packages/ZilpZalpUI/Tests/ZilpZalpUITests/QuizComponentTests.swift`

**Interfaces:**
- Produces: two new trailing init parameters, both defaulted so existing callers compile unchanged:
  - `openLabel: String? = nil` — the VoiceOver action's name (caller's copy).
  - `onOpen: ((Int) -> Void)? = nil` — called with the index of a tapped `.done` leaf.
- Produces (internal, for tests): `var openableLeaves: Range<Int>` — `0 ..< completed` when `onOpen != nil`, else `0 ..< 0`.

Behaviour: when `onOpen` is set, each `.done` leaf is a plain button (no visual change, no press styling that changes its look) whose hit area is its full slot — leaf width plus half the row spacing on each side — and at least `ZSpacing.touchMinimum` high (`contentShape`). `.current` / `.upcoming` leaves stay inert. The row stays **one** accessibility element (keep `.accessibilityElement(children: .ignore)`, label, value); when `openableLeaves` is non-empty and `openLabel` is set, add `.accessibilityAction(named: openLabel) { onOpen(completed - 1) }`. The row's frame height grows to the 44 pt hit height only via `contentShape`/padding that does not change the visual layout of the top bar — verify on the iPhone SE in Task 3.

- [ ] **Step 1: Failing tests**

```swift
@Test("Only answered leaves open, and only when someone listens")
func openableLeaves() {
    let quiet = QuizProgress(total: 10, completed: 3, current: 3, label: "Fortschritt")
    #expect(quiet.openableLeaves.isEmpty)
    let open = QuizProgress(total: 10, completed: 3, current: 3, label: "Fortschritt", onOpen: { _ in })
    #expect(open.openableLeaves == 0 ..< 3)
    let fresh = QuizProgress(total: 10, completed: 0, current: 0, label: "Fortschritt", onOpen: { _ in })
    #expect(fresh.openableLeaves.isEmpty)
}

@Test("Opening changes nothing the row draws")
func openingKeepsTheLeaves() {
    let plain = QuizProgress(total: 5, completed: 2, current: 2, label: "Fortschritt")
    let open = QuizProgress(total: 5, completed: 2, current: 2, label: "Fortschritt", onOpen: { _ in })
    #expect(plain.leafStates == open.leafStates)
}
```

- [ ] **Step 2:** `mise run test` → fail.
- [ ] **Step 3:** Implement as above. Add a `#Preview` row with `onOpen` set.
- [ ] **Step 4:** `mise run test` → pass; `mise run format`.
- [ ] **Step 5:** Commit `feat(ui): let answered progress leaves open`.

### Task 3: The look-back card in the quiz

**Files:**
- Modify: `apps/ZilpZalp/Sources/Quiz/QuizSession.swift`
- Create: `apps/ZilpZalp/Sources/Quiz/LookBackCard.swift`
- Modify: `apps/ZilpZalp/Sources/Quiz/QuizScreen.swift` (progress row ~352, sheet)
- Modify: `apps/ZilpZalp/Resources/Localizable.xcstrings`
- Modify: `docs/superpowers/specs/2026-08-01-zilpzalp-v1-design.md` (one pointer line in the quiz section, decision 2026-11-16, linking the look-back spec)

**Interfaces:**
- Consumes: `RoundPlay.answeredCount` (Task 1); `QuizProgress(openLabel:onOpen:)` (Task 2).
- Produces on `QuizSession`:
  - `var answeredCount: Int` — passes `play.answeredCount` through.
  - `func choices(inQuestion question: Int) -> [Bird]` — that question's birds in round order; `[]` out of range.
  - `func answer(ofQuestion question: Int) -> Bird?`
  - `func photo(for bird: Bird, question: Int) -> Image?` — `photos.photo(bird.id, question:)`; the existing `photo(for:)` calls it with `play.index`.
  - `func askAgain(question: Int)` — prompted: game 1 `announcer.announce([.name(answer)], unprompted: false)`, game 2 `player.play(calls[answer.id])`. Does not touch `askedFirstQuestion`, never says „Schau genau hin!".
  - `func endLookBack()` — `suspend()` then `carryOn()`, so a call started in the card stops and an answered live question moves on.
- Produces: `struct LookBackCard: View` with `let session: QuizSession`, `@State var page: Int` (initialised from the tapped index), `let close: () -> Void`.

Wiring in `QuizScreen`: `@State private var lookingBack: LookBack?` where `struct LookBack: Identifiable { let id = UUID(); let question: Int }`. `progress(session)` passes `openLabel: String(localized: "quiz.lookBack.action")` and `onOpen: { session.suspend(); lookingBack = LookBack(question: $0) }`. `.sheet(item: $lookingBack, onDismiss: { session?.endLookBack() }) { LookBackCard(session:, page: $0.question) { lookingBack = nil } }` — a sheet like the feedback one, never a full-screen cover (the screen's `onAppear` must not re-run). The feedback screenshot hint must not fire while the card is up: pass `isActive: … && lookingBack == nil` to the feedback modifier.

Card layout: top row — the `SoundButton` (rings from `session.isCallPlaying`, action `session.askAgain(question: page)`), the written name for game 1 only (`answer(ofQuestion:).name`, same type style as the quiz), and an `IconButton(.x …)` close with label `quiz.lookBack.close`. Below, `TabView(selection: $page)` with `.tabViewStyle(.page(indexDisplayMode: .always))` over `0 ..< session.answeredCount`, each page a 2×2 grid of `QuizTile` (reuse the quiz's tone rotation; make `QuizScreen.tones` reachable rather than copying it): phase `.correct` for the answer, `.idle` + `dimmed: true` for the others, action `{}`, tile labels `quiz.tile.accessibility` as in the quiz. Sheet detents: `.large` on compact width; default form sheet on iPad. Turning a page or opening speaks nothing.

Strings (German):
- `quiz.lookBack.action` = „Frühere Fragen ansehen"
- `quiz.lookBack.close` = „Schließen" (reuse an existing close key instead if the catalog has one)

- [ ] **Step 1:** Implement the session API, `LookBackCard`, the wiring and strings.
- [ ] **Step 2:** `mise run format`, `mise run test`, `mise run build` → clean, no new warnings.
- [ ] **Step 3: Simulator checks** (iPhone SE 3rd gen and an 11" iPad; screenshots to the scratchpad, reported in the PR):
  a. Answer the last question, tap a leaf during the pause → card stays, no round end; close → round end opens.
  b. Game 2: open card, play a call, close → silence, live question waits.
  c. iPhone SE, after 4 answers: tap leaves 1–4 → each opens on its own question; leaf 5 and later do nothing; swipe pages through 1–4 and no further.
  d. Speech mode „Nur auf Knopfdruck", game 1, open question: open/close card → nothing spoken.
  e. Wrong tap on the live question, open/close card → retry banner and tile state unchanged.
  f. VoiceOver: progress row offers „Frühere Fragen ansehen" only after the first answer.
- [ ] **Step 4:** Commit `feat: look back at answered questions in a round`.
- [ ] **Step 5:** `/simplify`, then `/code-review`; fix; push branch `feat/look-back`, open PR (English, with the simulator results, the spec and plan linked, and the device checklist: real taps on leaves on iPhone, page swipe vs. sheet dismissal on iPad).
