# Difficulty Levels Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

Status: approved 2026-11-13. Spec: [../specs/2026-11-13-difficulty-levels-design.md](../specs/2026-11-13-difficulty-levels-design.md).

**Goal:** A child picks Leicht, Mittel, Schwer or Klassisch on the home screen; Mittel and Schwer now and then deal a *tricky* question with look-alike birds, marked by a binoculars badge.

**Architecture:** `ZilpZalpCore` gets `Difficulty` and the distractor rules inside `Round.make` (Klassisch stays byte-identical). `ZilpZalpData` stores plain strings: `Bird.lookalike` from the manifests and `Profile.difficulty`. A Python gate keeps the curated look-alike groups consistent. `ZilpZalpUI` gets two picture-only components; the app target wires profile → level → round and draws the pill, the picker and the cue.

**Tech Stack:** Swift 6.2 language mode, SwiftUI (iOS 18), Swift Testing, Python 3.13 (unittest) for tools.

## Global Constraints

- Everything in the repository is English; German only in `apps/ZilpZalp/Resources/Localizable.xcstrings` (AGENTS.md "Sprache").
- `ZilpZalpCore` imports no SwiftUI, UIKit or networking; `ZilpZalpUI` knows no game logic; `ZilpZalpData` does not depend on Core.
- New Core logic ships with Swift Testing tests (`@Test`), deterministic through `SplitMix64`.
- No new dependencies. Icons only from Lucide 1.28.0, vendored as template imagesets.
- Kid screens: no text under 20 pt (grown-up hint lines may use `caption` only if marked grown-up), touch targets ≥ 64 pt, chosen = olive rim **and** check, never colour alone, reduced motion respected.
- Persisted values are raw strings decoded with `decodeIfPresent ?? default`; schema versions stay 1.
- Conventional Commits, subject ≤ 50 chars, imperative, no trailing period; body wrapped at 72.
- Verification here (Linux): `docker run --rm -v "$PWD":/repo -w /repo swift:6.2 bash -c 'cp -r packages/ZilpZalpCore /tmp/c && cd /tmp/c && swift test'` for Core; `python3 -m unittest discover -s tools/tests -t tools` (stdlib tests) for tools; SwiftUI compiles only in CI (`mise run check` on the macOS runner).

## File map

| File | Change | Responsibility |
|---|---|---|
| `packages/ZilpZalpCore/Sources/ZilpZalpCore/Difficulty.swift` | new | The four levels and their numbers |
| `packages/ZilpZalpCore/Sources/ZilpZalpCore/QuizSpecies.swift` | modify | `lookalike`, `looksLike(_:)` |
| `packages/ZilpZalpCore/Sources/ZilpZalpCore/Round.swift` | modify | `difficulty:` parameter, tricky questions, `Question.isTricky` |
| `packages/ZilpZalpCore/Tests/ZilpZalpCoreTests/DifficultyTests.swift` | new | Engine rules per level |
| `packages/ZilpZalpData/Sources/ZilpZalpData/PackSchema.swift` | modify | `Bird.lookalike` |
| `packages/ZilpZalpData/Sources/ZilpZalpData/Profile.swift` | modify | `difficulty`, `defaultDifficulty`, `difficultySamples` |
| `packages/ZilpZalpData/Tests/ZilpZalpDataTests/ProfileDifficultyTests.swift` | new | Decode, default, merge, samples |
| `packages/ZilpZalpData/Tests/ZilpZalpDataTests/PackManifestTests.swift` | modify | `lookalike` decodes |
| `tools/lookalike_gate.py` | new | Vocabulary + consistency gate |
| `tools/tests/test_lookalike_gate.py` | new | Gate tests |
| `mise.toml` | modify | `lookalike-gate` task, called from `check` |
| `data/packs/*/manifest.json` + bundled copy | modify | One `lookalike` per bird |
| `packages/ZilpZalpUI/Sources/ZilpZalpUI/ZIcon.swift` + `Resources/Icons.xcassets/binoculars.imageset` | modify/new | Glyph |
| `packages/ZilpZalpUI/Sources/ZilpZalpUI/Components/PhotoQuartet.swift` | new | 2×2 (or single) photo picture |
| `packages/ZilpZalpUI/Sources/ZilpZalpUI/Components/GlyphBadge.swift` | new | Round glyph badge on a ledge |
| `packages/ZilpZalpUI/Tests/ZilpZalpUITests/DifficultyComponentTests.swift` | new | Component values |
| `apps/ZilpZalp/Sources/Home/DifficultyLevel.swift` | new | Levels → words, photos, tone; `AppModel` difficulty API |
| `apps/ZilpZalp/Sources/Home/DifficultyChip.swift` | new | The home pill |
| `apps/ZilpZalp/Sources/Home/DifficultyPicker.swift` | new | „Wie schwer?" card |
| `apps/ZilpZalp/Sources/Home/HomeScreen.swift`, `HomeScreenPreviews.swift`, `RootView.swift` | modify | Wiring |
| `apps/ZilpZalp/Sources/Quiz/QuizSession.swift`, `QuizScreen.swift`, `QuizScreenPreviews.swift` | modify | Difficulty into the round, the cue |
| `apps/ZilpZalp/Resources/Localizable.xcstrings` | modify | German copy |

---

### Task 1: Engine — `Difficulty` and tricky questions (Core)

**Files:**
- Create: `packages/ZilpZalpCore/Sources/ZilpZalpCore/Difficulty.swift`
- Modify: `packages/ZilpZalpCore/Sources/ZilpZalpCore/QuizSpecies.swift`, `packages/ZilpZalpCore/Sources/ZilpZalpCore/Round.swift`
- Test: `packages/ZilpZalpCore/Tests/ZilpZalpCoreTests/DifficultyTests.swift`

**Interfaces:**
- Produces: `public enum Difficulty: String, CaseIterable, Sendable { case easy, medium, hard, classic }` with `public static let standard: Difficulty = .classic`; `QuizSpecies.init(id:genus:lookalike: String? = nil, canBeAsked: Bool = true)`, `public let lookalike: String?`, `public func looksLike(_ other: QuizSpecies) -> Bool`; `Round.make(from:questionCount:choiceCount:difficulty: Difficulty = .classic, using:)`; `Round.Question.isTricky: Bool`.

- [ ] **Step 1: Write the failing tests** — `DifficultyTests.swift`:

```swift
import Testing
import ZilpZalpCore

// MARK: - Pools

/// Owls, tits and ducks, five of each, every species its own genus — so
/// only the look-alike group can make two of them alike.
private func groupedPool() -> [QuizSpecies] {
    ["owl", "tit", "duck"].flatMap { group in
        (0 ..< 5).map { QuizSpecies(id: "\(group)-\($0)", genus: "\(group)-genus-\($0)", lookalike: group) }
    }
}

private func byIdentifier(_ pool: [QuizSpecies]) -> [String: QuizSpecies] {
    Dictionary(uniqueKeysWithValues: pool.map { ($0.id, $0) })
}

/// How many of a question's distractors look like its answer.
private func lookalikes(in question: Round.Question, pool: [String: QuizSpecies]) -> Int {
    let answer = pool[question.answer]!
    return question.choices.filter { $0 != question.answer && answer.looksLike(pool[$0]!) }.count
}

private func expectWellFormed(_ round: Round, pool: [QuizSpecies]) {
    let identifiers = Set(pool.map(\.id))
    #expect(round.questions.count == 10)
    for question in round.questions {
        #expect(question.choices.count == 4)
        #expect(Set(question.choices).count == 4)
        #expect(question.choices.filter { $0 == question.answer }.count == 1)
        #expect(Set(question.choices).isSubset(of: identifiers))
    }
}

// MARK: - Similarity

@Test("Species look alike by group, and by genus where a group is missing")
func looksLike() {
    let waldkauz = QuizSpecies(id: "waldkauz", genus: "Strix", lookalike: "owl")
    let uhu = QuizSpecies(id: "uhu", genus: "Bubo", lookalike: "owl")
    let amsel = QuizSpecies(id: "amsel", genus: "Turdus", lookalike: "thrush")
    let singdrossel = QuizSpecies(id: "singdrossel", genus: "Turdus")
    let star = QuizSpecies(id: "star", genus: "Sturnus")

    #expect(waldkauz.looksLike(uhu))
    #expect(!waldkauz.looksLike(amsel))
    #expect(amsel.looksLike(singdrossel))
    #expect(!singdrossel.looksLike(star))
    #expect(!waldkauz.looksLike(waldkauz))
}

@Test("The stored names of the levels never change", arguments: zip(
    Difficulty.allCases, ["easy", "medium", "hard", "classic"],
))
func rawValuesAreStable(level: Difficulty, raw: String) {
    #expect(level.rawValue == raw)
}

@Test("Klassisch is the standard level")
func classicIsStandard() {
    #expect(Difficulty.standard == .classic)
}

// MARK: - Klassisch

/// What the engine dealt for this pool and seed **before levels existed**,
/// captured from the unchanged engine on 2026-11-13. Klassisch must deal it
/// draw for draw — otherwise "Klassisch is today's game" would be a claim.
private let goldenClassic: [(answer: String, choices: [String])] = [
    ("tit-3", ["tit-3", "duck-0", "owl-3", "owl-1"]),
    ("duck-4", ["duck-4", "duck-1", "tit-4", "owl-0"]),
    ("tit-1", ["owl-1", "owl-2", "tit-1", "tit-4"]),
    ("tit-4", ["tit-4", "owl-1", "tit-3", "tit-0"]),
    ("owl-0", ["tit-3", "tit-0", "owl-0", "owl-3"]),
    ("duck-2", ["owl-1", "tit-4", "duck-2", "duck-0"]),
    ("duck-0", ["owl-1", "tit-3", "tit-0", "duck-0"]),
    ("owl-2", ["tit-2", "owl-3", "owl-2", "owl-0"]),
    ("owl-1", ["tit-3", "owl-1", "duck-2", "duck-4"]),
    ("duck-3", ["tit-0", "owl-2", "tit-3", "duck-3"]),
]

@Test("Klassisch deals exactly the round the engine dealt before levels")
func classicIsUnchanged() throws {
    var implicit = SplitMix64(seed: 42)
    var explicit = SplitMix64(seed: 42)

    let byDefault = try Round.make(from: groupedPool(), using: &implicit)
    let classic = try Round.make(from: groupedPool(), difficulty: .classic, using: &explicit)

    #expect(byDefault == classic)
    #expect(classic.questions.map(\.answer) == goldenClassic.map(\.answer))
    #expect(classic.questions.map(\.choices) == goldenClassic.map(\.choices))
    #expect(classic.questions.allSatisfy { !$0.isTricky })
}

// MARK: - Leicht

@Test("Leicht never puts a look-alike beside the answer", arguments: [1, 2, 3, 42] as [UInt64])
func easyAvoidsLookalikes(seed: UInt64) throws {
    let pool = groupedPool()
    var generator = SplitMix64(seed: seed)

    let round = try Round.make(from: pool, difficulty: .easy, using: &generator)

    expectWellFormed(round, pool: pool)
    for question in round.questions {
        #expect(lookalikes(in: question, pool: byIdentifier(pool)) == 0)
        #expect(!question.isTricky)
    }
}

@Test("Leicht fills up with look-alikes only when nothing else is left")
func easyFallsBack() throws {
    // Four owls and nothing else: every question is four owls.
    let pool = (0 ..< 4).map { QuizSpecies(id: "owl-\($0)", genus: "g\($0)", lookalike: "owl") }
    var generator = SplitMix64(seed: 7)

    let round = try Round.make(from: pool, difficulty: .easy, using: &generator)

    expectWellFormed(round, pool: pool)
}

// MARK: - Mittel and Schwer

@Test(
    "Mittel deals three tricky questions with one look-alike, Schwer five with two",
    arguments: [(Difficulty.medium, 3, 1), (.hard, 5, 2)],
)
func trickyQuestions(level: Difficulty, tricky: Int, alike: Int) throws {
    let pool = groupedPool()
    for seed in [1, 2, 3, 42] as [UInt64] {
        var generator = SplitMix64(seed: seed)

        let round = try Round.make(from: pool, difficulty: level, using: &generator)

        expectWellFormed(round, pool: pool)
        let trickyOnes = round.questions.filter(\.isTricky)
        #expect(trickyOnes.count == tricky)
        for question in trickyOnes {
            #expect(lookalikes(in: question, pool: byIdentifier(pool)) == alike)
        }
    }
}

@Test("The first question is never tricky", arguments: [Difficulty.medium, .hard])
func firstQuestionIsPlain(level: Difficulty) throws {
    let pool = groupedPool()
    for seed in 0 ..< 50 as Range<UInt64> {
        var generator = SplitMix64(seed: seed)
        let round = try Round.make(from: pool, difficulty: level, using: &generator)
        #expect(round.questions.first?.isTricky == false)
    }
}

@Test("Without any look-alike in the pool no question is tricky", arguments: [Difficulty.medium, .hard])
func noLookalikesNoTricks(level: Difficulty) throws {
    let pool = distinctGenera(25)
    var generator = SplitMix64(seed: 3)

    let round = try Round.make(from: pool, difficulty: level, using: &generator)

    expectWellFormed(round, pool: pool)
    #expect(round.questions.allSatisfy { !$0.isTricky })
}

@Test("Schwer takes the one look-alike there is and fills up with others")
func hardWithOneLookalike() throws {
    // Pairs only: every answer has exactly one look-alike.
    let pool = (0 ..< 6).flatMap { pair in
        (0 ..< 2).map { QuizSpecies(id: "p\(pair)-\($0)", genus: "g\(pair)-\($0)", lookalike: "pair-\(pair)") }
    }
    var generator = SplitMix64(seed: 5)

    let round = try Round.make(from: pool, difficulty: .hard, using: &generator)

    expectWellFormed(round, pool: pool)
    let trickyOnes = round.questions.filter(\.isTricky)
    #expect(trickyOnes.count == 5)
    for question in trickyOnes {
        #expect(lookalikes(in: question, pool: byIdentifier(pool)) == 1)
    }
}

@Test("Every level works on the smallest pool", arguments: Difficulty.allCases)
func smallestPool(level: Difficulty) throws {
    let pool = (0 ..< 4).map { QuizSpecies(id: "s\($0)", genus: "g\($0)", lookalike: $0 < 2 ? "a" : "b") }
    var generator = SplitMix64(seed: 11)

    let round = try Round.make(from: pool, difficulty: level, using: &generator)

    expectWellFormed(round, pool: pool)
}

@Test("The same seed deals the same round on every level", arguments: Difficulty.allCases)
func deterministic(level: Difficulty) throws {
    let pool = groupedPool()
    var first = SplitMix64(seed: 99)
    var second = SplitMix64(seed: 99)

    #expect(try Round.make(from: pool, difficulty: level, using: &first)
        == Round.make(from: pool, difficulty: level, using: &second))
}
```

- [ ] **Step 2: Run, expect compile failure** (`Difficulty`, `lookalike:`, `isTricky` unknown):
`docker run --rm -v "$PWD":/repo -w /repo swift:6.2 bash -c 'cp -r packages/ZilpZalpCore /tmp/c && cd /tmp/c && swift test 2>&1 | tail -20'`

- [ ] **Step 3: Implement.** `Difficulty.swift`:

```swift
/// How alike the four birds of a question may look.
///
/// Klassisch is the game as it always was — distractors from another genus
/// first — and stays the standard: every profile written before levels
/// existed plays it. Leicht keeps look-alikes out altogether; Mittel and
/// Schwer play Klassisch but put look-alikes beside the answer in a few
/// questions, the *tricky* ones. Effective order: Leicht, Klassisch, Mittel,
/// Schwer.
///
/// The raw values are stored in `Profile.difficulty` and must never change.
public enum Difficulty: String, CaseIterable, Sendable {
    case easy
    case medium
    case hard
    case classic

    /// The level of a profile that never chose one.
    public static let standard: Difficulty = .classic

    /// How many questions of a round are dealt tricky, at most — the pool
    /// decides whether there are that many answers with a look-alike.
    var trickyQuestions: Int {
        switch self {
        case .medium: 3
        case .hard: 5
        case .easy, .classic: 0
        }
    }

    /// How many look-alikes stand beside the answer in a tricky question.
    var lookalikesPerTrickyQuestion: Int {
        switch self {
        case .medium: 1
        case .hard: 2
        case .easy, .classic: 0
        }
    }
}
```

`QuizSpecies.swift` — add the stored property, init parameter and method (keep the existing doc comments, extend the type's doc with one paragraph on `lookalike`):

```swift
    /// The look-alike group the pack curates for this species — `"owl"`,
    /// `"tit"` — or `nil` for a pack from before groups existed. Two species
    /// of one group are what a child confuses at a glance.
    public let lookalike: String?

    public init(id: String, genus: String, lookalike: String? = nil, canBeAsked: Bool = true) {
        self.id = id
        self.genus = genus
        self.lookalike = lookalike
        self.canBeAsked = canBeAsked
    }

    /// Whether a child could take `other` for this species at a glance: the
    /// same look-alike group, or — where a pack names none — the same genus.
    /// Never true of the species itself.
    public func looksLike(_ other: QuizSpecies) -> Bool {
        guard other.id != id else { return false }
        if let lookalike, lookalike == other.lookalike { return true }
        return genus == other.genus
    }
```

`Round.swift` — `Question` gains `public let isTricky: Bool` (doc: "Whether the question was dealt with look-alikes on purpose — the app marks it."). `make` gains `difficulty: Difficulty = .classic` before `using:`; document it in the parameter list. Replace the loop and `distractors` with:

```swift
        let asked = answers(from: askable, questionCount: questionCount, using: &generator)
        let tricky = trickyQuestions(among: asked, in: species, difficulty: difficulty, using: &generator)

        var questions: [Question] = []
        questions.reserveCapacity(questionCount)
        for (index, answer) in asked.enumerated() {
            let isTricky = tricky.contains(index)
            var choices = distractors(
                for: answer,
                from: species,
                count: choiceCount - 1,
                rule: rule(for: difficulty, isTricky: isTricky),
                using: &generator,
            )
            choices.append(answer)
            questions.append(
                Question(
                    answer: answer.id,
                    choices: choices.shuffled(using: &generator).map(\.id),
                    isTricky: isTricky,
                ),
            )
        }
        return Round(questions: questions)
```

```swift
    /// How one question picks its distractors: what counts as alike, and how
    /// many of the alike ones it wants.
    private struct Rule {
        let isAlike: (QuizSpecies, QuizSpecies) -> Bool
        let lookalikes: Int
    }

    /// Klassisch's genus rule for every plain question, so that Mittel and
    /// Schwer are Klassisch plus their tricky questions; Leicht's look-alike
    /// rule with none wanted; a tricky question's look-alikes on purpose.
    private static func rule(for difficulty: Difficulty, isTricky: Bool) -> Rule {
        if isTricky {
            return Rule(isAlike: { $0.looksLike($1) }, lookalikes: difficulty.lookalikesPerTrickyQuestion)
        }
        if difficulty == .easy {
            return Rule(isAlike: { $0.looksLike($1) }, lookalikes: 0)
        }
        return Rule(isAlike: { $0.genus == $1.genus }, lookalikes: 0)
    }

    /// Which questions are dealt tricky: never the first, only one whose
    /// answer has a look-alike in the pool, and at most as many as the level
    /// asks for. Klassisch and Leicht draw nothing here, which is what keeps
    /// a Klassisch round the round the same seed always dealt.
    private static func trickyQuestions(
        among answers: [QuizSpecies],
        in species: [QuizSpecies],
        difficulty: Difficulty,
        using generator: inout some RandomNumberGenerator,
    ) -> Set<Int> {
        guard difficulty.trickyQuestions > 0 else { return [] }
        let eligible = answers.indices.dropFirst().filter { index in
            species.contains { answers[index].looksLike($0) }
        }
        return Set(eligible.shuffled(using: &generator).prefix(difficulty.trickyQuestions))
    }

    /// Picks the distractors for one answer from the whole pool, askable or
    /// not: the look-alikes the rule wants first, then unlike species, then —
    /// only to fill up — the remaining alike ones. The answer itself is never
    /// among them, and no species twice. With no look-alikes wanted this is
    /// exactly the genus rule the engine always had, draw for draw.
    private static func distractors(
        for answer: QuizSpecies,
        from species: [QuizSpecies],
        count: Int,
        rule: Rule,
        using generator: inout some RandomNumberGenerator,
    ) -> [QuizSpecies] {
        let candidates = species.filter { $0 != answer }
        let unlike = candidates.filter { !rule.isAlike(answer, $0) }.shuffled(using: &generator)
        let alike = candidates.filter { rule.isAlike(answer, $0) }.shuffled(using: &generator)
        let wanted = alike.prefix(min(rule.lookalikes, count))
        let rest = unlike + alike.dropFirst(wanted.count)
        return Array(wanted) + rest.prefix(count - wanted.count)
    }
```

Update the doc comment of `make` (the bullet "Distractors come from a genus other than the answer's…") to name the level: Klassisch keeps that rule, the other levels are described in ``Difficulty``.

- [ ] **Step 4: Run all Core tests, expect PASS** (the existing `RoundTests` untouched): same docker command.
- [ ] **Step 5: Commit** `feat(core): deal rounds by difficulty level`

---

### Task 2: Data — `Bird.lookalike` and `Profile.difficulty`

**Files:**
- Modify: `packages/ZilpZalpData/Sources/ZilpZalpData/PackSchema.swift` (stored property after `speech`, `CodingKeys`, `init(from:)`)
- Modify: `packages/ZilpZalpData/Sources/ZilpZalpData/Profile.swift`
- Test: `packages/ZilpZalpData/Tests/ZilpZalpDataTests/ProfileDifficultyTests.swift` (new), `PackManifestTests.swift` (one case)

**Interfaces:**
- Produces: `Bird.lookalike: String?`; `Profile.difficulty: String` (var), `Profile.defaultDifficulty = "classic"`, `Profile.difficultySamples: [String: [String]]` (raw level → bundled species ids), init parameter `difficulty: String = Profile.defaultDifficulty` placed after `stickerThreshold`.

- [ ] **Step 1: Failing tests** — `ProfileDifficultyTests.swift`, modelled on `ProfileStickerTests.swift` (read it first and reuse its helpers for encoding/decoding a profile file and opening a `ProfileStore` in a temporary directory):
  - a profile JSON without `difficulty` decodes to `"classic"`;
  - `"hard"` round-trips through encode/decode;
  - a value this build does not know (`"nightmare"`) is kept as written (the app maps it to the standard level; Data does not judge);
  - `ProfileStore.update` persists a changed difficulty (reread from disk);
  - `merged(with:)` takes `difficulty` from the copy with the newer `modifiedAt`, in both directions;
  - every id in every list of `Profile.difficultySamples` exists in the bundled Deutschland pack (copy the lookup the `avatarChoices` test in `ProfileTests.swift` uses), the keys are exactly `easy, medium, hard, classic`, Klassisch has one id and the others four.
  In `PackManifestTests.swift`: a bird with `"lookalike": "owl"` decodes to `"owl"`; one without decodes to `nil`.
- [ ] **Step 2: Implement.**
  `PackSchema.swift`:

```swift
    /// The look-alike group a child would confuse this species with —
    /// `"owl"`, `"tit"`; the vocabulary lives in `tools/lookalike_gate.py`.
    /// `nil` in a pack curated before groups existed: the round engine then
    /// falls back to the genus.
    public let lookalike: String?
```
  add `lookalike` to `CodingKeys` (`case photos, call, speech, lookalike`) and `lookalike = try container.decodeIfPresent(String.self, forKey: .lookalike)` in `init(from:)`.

  `Profile.swift`: add after `stickers`:

```swift
    /// How alike the birds of this child's questions may look: the raw value
    /// of `Difficulty` in `ZilpZalpCore` — `"easy"`, `"medium"`, `"hard"` or
    /// `"classic"`. A taste of the child like ``collections``, chosen on the
    /// home screen. Stored as written; a value a newer build wrote is the
    /// app's to map, not this module's to reject.
    public var difficulty: String

    /// Klassisch: the game as it was before levels existed.
    public static let defaultDifficulty = "classic"

    /// The bundled species each level's picture shows, keyed by level: four
    /// birds that look like that level's questions, and for Klassisch the
    /// Zilpzalp alone. Checked against the bundled pack by the tests, as
    /// ``avatarChoices`` is.
    public static let difficultySamples: [String: [String]] = [
        "easy": ["waldkauz", "weissstorch", "eisvogel", "stockente"],
        "medium": ["amsel", "star", "eisvogel", "weissstorch"],
        "hard": ["kohlmeise", "blaumeise", "haubenmeise", "rotkehlchen"],
        "classic": ["zilpzalp"],
    ]
```
  init parameter + assignment, `CodingKeys.difficulty`, `difficulty = try container.decodeIfPresent(String.self, forKey: .difficulty) ?? Self.defaultDifficulty`. Extend the doc comments of `modifiedAt` and `merged(with:)` to list the difficulty among the fields taken from the copy changed last (no code change in `merged`).
- [ ] **Step 3: Verify.** Data cannot build on Linux as-is (`CryptoKit`, `os`); review by reading, CI runs it. If a local Linux shim is available (see the session notes), run it.
- [ ] **Step 4: Commit** `feat(data): store look-alikes and difficulty`

---

### Task 3: Tools — the look-alike gate

**Files:**
- Create: `tools/lookalike_gate.py`, `tools/tests/test_lookalike_gate.py`
- Modify: `mise.toml` (new `[tasks.lookalike-gate]` after `license-gate`; `mise run lookalike-gate` in `check` right after `mise run license-gate`)

**Interfaces:**
- Produces: `GROUPS: dict[str, str]` (slug → what belongs in it), `check(packs_dir: Path) -> list[str]` (problems, empty when fine), `main(argv: list[str] | None = None) -> int` with `--packs` defaulting to `data/packs`. Standard library only, like `license_gate.py` (read it for the CLI and message style).

- [ ] **Step 1: Failing tests** (unittest, temp directory with two tiny manifests): passes on a consistent pair; reports a bird without `lookalike` (message names pack and bird id); reports an unknown group; reports the same id with two groups across packs (names both packs); `main` returns 1 on problems and 0 otherwise; the real `data/packs` passes — this last test is added in Task 4, after the curation.
- [ ] **Step 2: Implement** with this vocabulary (descriptions are part of the documentation; keep them):

```python
GROUPS = {
    "owl": "owls",
    "raptor": "eagles, hawks, buzzards, kites, harriers, falcons, caracaras, osprey, secretarybird",
    "vulture": "Old and New World vultures, condors, the bearded vulture",
    "heron": "long-legged waders: herons, egrets, bitterns, storks, cranes, ibises, spoonbills, flamingos, shoebill, hamerkop",
    "shorebird": "sandpipers, plovers, lapwings, curlews, godwits, snipes, woodcocks, oystercatchers, avocets, turnstones, jacanas",
    "gull": "gulls, terns, kittiwakes, skuas",
    "seabird": "albatrosses, fulmars, petrels, gannets, boobies, frigatebirds, tropicbirds, cormorants, anhingas, pelicans",
    "diver": "auks, puffins, guillemots, loons, grebes",
    "penguin": "penguins",
    "duck": "ducks, mergansers, eiders, shelducks, goldeneyes",
    "goose": "geese, swans, screamers",
    "rail": "rails, coots, moorhens, gallinules, swamphens",
    "gamebird": "pheasants, grouse, partridges, peafowl, junglefowl, guineafowl, turkeys, bustards",
    "ratite": "ostrich, emu, cassowaries, rheas",
    "pigeon": "pigeons and doves",
    "parrot": "parrots, cockatoos, macaws, lorikeets, budgerigars, keas",
    "woodpecker": "woodpeckers and wrynecks",
    "kingfisher": "kingfishers, kookaburras, bee-eaters, rollers, hoopoes",
    "hornbill": "hornbills, toucans, aracaris",
    "hummingbird": "hummingbirds and sunbirds",
    "swallow": "swallows, martins, swifts",
    "corvid": "crows, ravens, jackdaws, choughs, magpies, jays, nutcrackers, the Australian magpie",
    "tit": "tits, chickadees, titmice, nuthatches, treecreepers, wallcreepers, long-tailed tits",
    "finch": "finches, sparrows, buntings, cardinals, grosbeaks, crossbills, weavers, larks, tanagers",
    "thrush": "thrushes, robins, chats, redstarts, nightingales, bluebirds, wheatears, starlings, mynas, orioles, New World blackbirds",
    "warbler": "warblers, wrens, kinglets, white-eyes, bulbuls, fantails, fairywrens, flycatchers, waxwings, wagtails, shrikes, dippers",
    "cuckoo": "cuckoos, roadrunners, turacos, hoatzin",
}
```
  The module docstring explains why look-alike groups are curated (what a child confuses at a glance, not phylogeny — see the spec) and that every bird in `data/packs` must carry one.
- [ ] **Step 3: Run** `python3 -m unittest tools.tests.test_lookalike_gate` from the repo root with `-t tools` as `mise run test` does: `python3 -m unittest discover -s tools/tests -t tools -p 'test_lookalike_gate.py'` → PASS.
- [ ] **Step 4: Commit** `feat(tools): gate the look-alike groups`

---

### Task 4: Data — curate the groups

**Files:** `data/packs/*/manifest.json` (11), then `python3 tools/sync_bundled_packs.py` refreshes `packages/ZilpZalpData/Sources/ZilpZalpData/Resources/Packs/deutschland/manifest.json`; `tools/tests/test_lookalike_gate.py` gains `test_the_curated_packs_pass`.

- [ ] **Step 1:** For every bird in every manifest, insert `"lookalike": "<slug>"` directly after `"article"` (key order of the existing manifests otherwise unchanged, 2-space indent, trailing newline, `ensure_ascii=False` — byte-compare an untouched manifest after a load/dump round trip first, so the script provably changes nothing but the new key). Decide from the species' look (scientific name + German name), using the vocabulary descriptions; one species id gets one group everywhere.
- [ ] **Step 2:** `python3 tools/lookalike_gate.py` → exit 0; `python3 tools/license_gate.py` → exit 0; `python3 tools/sync_bundled_packs.py` once (heals), then again → exit 0; `python3 tools/generate_credits.py` → exit 0 (credits do not change).
- [ ] **Step 3:** Print a per-pack summary of group sizes and check that the difficulty samples hold: `amsel` and `star` share a group, `kohlmeise`, `blaumeise`, `haubenmeise` share one, the four Leicht samples are four different groups.
- [ ] **Step 4: Commit** `feat(data): curate look-alike groups for all packs`

---

### Task 5: Design system — glyph, quartet, badge

**Files:**
- Create: `packages/ZilpZalpUI/Sources/ZilpZalpUI/Resources/Icons.xcassets/binoculars.imageset/{binoculars.svg,Contents.json}` — the SVG is Lucide 1.28.0 `binoculars` in the same file shape as `bird.svg` (paths: `M10 10h4`, `M19 7V4a1 1 0 0 0-1-1h-2a1 1 0 0 0-1 1v3`, `M20 21a2 2 0 0 0 2-2v-3.851c0-1.39-2-2.962-2-4.829V8a1 1 0 0 0-1-1h-4a1 1 0 0 0-1 1v11a2 2 0 0 0 2 2z`, `M 22 16 L 2 16`, `M4 21a2 2 0 0 1-2-2v-3.851c0-1.39 2-2.962 2-4.829V8a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v11a2 2 0 0 1-2 2z`, `M9 7V4a1 1 0 0 0-1-1H6a1 1 0 0 0-1 1v3`); `Contents.json` copied from `bird.imageset`.
- Modify: `ZIcon.swift` (`case binoculars`, alphabetical).
- Create: `Components/PhotoQuartet.swift`, `Components/GlyphBadge.swift`; Test: `Tests/ZilpZalpUITests/DifficultyComponentTests.swift`.

**Interfaces:**
- Produces:
  - `public struct PhotoQuartet: View` — `init(photos: [Image?], tone: PhotoQuartet.Tone, size: CGFloat, chosen: Bool = false)`; `public enum Tone: CaseIterable, Sendable { case sun, clay, bark, sand }` with `var palette: (field: Color, edge: Color)` = sun200/sun400, clay100/clay300, bark100/bark300, sand200/sand400. One photo fills the square; four make a 2×2 with a gap of `size * 0.04` and inner radius `size * 0.11`; the square has radius `size * 0.2`, padding `size * 0.07`, a `ZBorder.width` edge and a ledge of `ZShadow.ledgeOffset` in the edge colour. A missing photo (`nil`) draws `Icon(.bird)` on the field colour. `chosen` swaps edge and ledge to `ZColor.primary`/`ZColor.primaryShadow` at `ZBorder.widthThick` and adds the same check badge `RewardSticker` uses (olive disc, cream check, top trailing). Static `public static func layout(photoCount: Int) -> (columns: Int, cells: Int)` returns `(1, 1)` for one photo, `(2, 4)` otherwise — the testable part.
  - `public struct GlyphBadge: View` — `init(_ icon: ZIcon, diameter: CGFloat)`, a `ZColor.reward` disc with `ZColor.textOnReward` glyph at 55 % of the diameter, a 3 pt `ZColor.surfaceCard` outline, a ledge in `ZColor.rewardShadow`, tilted −10°; hidden from accessibility (the caller labels).
- [ ] **Step 1: Failing tests**: `ZIcon.binoculars.rawValue == "binoculars"` (the existing `IconAssetCatalogTests` then covers the imageset); `PhotoQuartet.layout(photoCount:)` for 1 and 4; `PhotoQuartet.Tone.allCases` palettes are four distinct field colours and none of them is `ZColor.primary` (olive is "chosen"); contrast of `ZColor.textOnReward` on `ZColor.reward` ≥ 4.5 using the helper in `ContrastTests.swift`.
- [ ] **Step 2: Implement**, with `#Preview`s for both components (one, four, a missing photo, chosen).
- [ ] **Step 3: Commit** `feat(ui): add binoculars, photo quartet and badge`

---

### Task 6: App — the level on the home screen

**Files:**
- Create: `apps/ZilpZalp/Sources/Home/DifficultyLevel.swift`, `DifficultyChip.swift`, `DifficultyPicker.swift`
- Modify: `HomeScreen.swift`, `HomeScreenPreviews.swift`, `RootView.swift`, `Localizable.xcstrings`

**Interfaces:**
- Consumes: Tasks 1, 2, 5.
- Produces: `struct DifficultyLevel: Identifiable { let difficulty: Difficulty; let title: String; let hint: String; let photos: [Image?]; let tone: PhotoQuartet.Tone; let spoken: SpokenLine; var id: Difficulty { difficulty } }`; `extension AppModel { var difficulty: Difficulty; var difficultyLevels: [DifficultyLevel]; func choose(difficulty: Difficulty) async }`.

- [ ] **Step 1: `DifficultyLevel.swift`.** Levels in the order Leicht, Mittel, Schwer, Klassisch. `title` = `String(localized: "home.difficulty.<raw>")`, `hint` = `"home.difficulty.<raw>.hint"`, `spoken` = `.fixed("home.difficulty.<raw>")`, `photos` = `Profile.difficultySamples[raw].map { packs.photos[$0] }`, tone sun/clay/bark/sand. `AppModel.difficulty` = `activeProfile.flatMap { Difficulty(rawValue: $0.difficulty) } ?? .standard`. `choose(difficulty:)` copies `choose(collections:)` (in-memory first, `store.update`, failure logged on `Logger.profiles`, no `storeFailed`), and returns early when the level is unchanged.
- [ ] **Step 2: `DifficultyChip.swift`.** A 64 pt capsule like `CollectionChip` (`surfaceCard`, `borderCard` outline): `PhotoQuartet(size: 48)` of the current level, the title in `.label`/display/bold when `showsTitle`, the chevron. `showsTitle: Bool` so the home screen can drop the word on a phone. Accessibility label `home.difficulty.change.accessibility` with the title.
- [ ] **Step 3: `DifficultyPicker.swift`.** Copy the structure of `CollectionPicker` (scrim tap closes, card, title + `SpeakerButton`, one `SpeechAnnouncer` built on first use, question said once on appear, `accessibilityAddTraits(.isModal)`, transition, reduced motion): title `home.difficulty.title`; a grid of four level cards — four columns when the card is regular width, two otherwise — each a `Button` with `PhotoQuartet(size:chosen:)`, the title (`.headline` display extra bold) and the hint (`.body` regular, `textMuted`, two lines max, centred); chosen scales 1.06 with `ZMotion.easeBounce`; tap = `choose(level.difficulty)` + `say(level.spoken)`; `ZButton("home.collection.done", size: .medium, leadingIcon: .play, action: close)` at the foot. Card max width 900 pt. Previews for iPhone and iPad.
- [ ] **Step 4: Home screen.** New stored properties `difficulty: Difficulty = .standard`, `difficultyLevels: [DifficultyLevel] = []`, `chooseDifficulty: (Difficulty) -> Void = { _ in }`, `@State isPickingDifficulty`. In `intro`, the pills sit in `ViewThatFits(in: .horizontal) { pills(showsTitle: true); pills(showsTitle: false) }` where `pills` is an `HStack(spacing: ZSpacing.step3)` of `CollectionChip` (when there is one) and `DifficultyChip` (when `difficultyLevels` is not empty). Second overlay for the picker; `.animation` keyed on both flags. Update the screen's doc comment. `RootView` passes `model.difficulty`, `model.difficultyLevels`, `{ level in Task { await model.choose(difficulty: level) } }`. Previews pass sample levels.
- [ ] **Step 5: Strings.** Add to `Localizable.xcstrings` (each with a `comment`, `extractionState: manual`, German `translated`): `home.difficulty.title` „Wie schwer?", `home.difficulty.easy` „Leicht", `.medium` „Mittel", `.hard` „Schwer", `.classic` „Klassisch", the four `.hint`s „Ganz verschiedene Vögel", „Ab und zu ähnliche", „Oft sehr ähnliche", „Wie immer", `home.difficulty.change.accessibility` „Schwierigkeit: %@. Ändern". Keep the file's key order (alphabetical) and formatting.
- [ ] **Step 6: Commit** `feat(app): let a child choose how hard`

---

### Task 7: App — the level in the round

**Files:** `apps/ZilpZalp/Sources/Quiz/QuizSession.swift`, `QuizScreen.swift`, `QuizScreenPreviews.swift`, `RootView.swift`, `Localizable.xcstrings`

- [ ] **Step 1:** `QuizSession.init(library:game:difficulty: Difficulty = .standard)`; store it; map `lookalike: bird.lookalike` into `QuizSpecies`; pass `difficulty:` to both `Round.make` calls. New `var isTricky: Bool { play.question?.isTricky ?? false }`. In `askQuestion(unprompted:)`, game 1: `unprompted && isTricky` announces `[.fixed("quiz.tricky"), .name(answer)]`, otherwise `.name(answer)` as before; game 2 unchanged. Doc comments say why game 2 stays silent.
- [ ] **Step 2:** `QuizScreen` takes `let difficulty: Difficulty`, hands it to `QuizSession`. `soundButton` gets `.overlay(alignment: .topTrailing) { if session.isTricky { GlyphBadge(.binoculars, diameter: diameter * 0.4).offset(x: diameter * 0.1, y: -diameter * 0.06).transition(.scale.combined(with: .opacity)) } }` animated with `ZMotion.easeBounce` keyed on the question (nil under reduced motion), and the sound button's accessibility label gains `quiz.tricky.accessibility` while tricky. `RootView.quiz(_:)` passes `model.difficulty`; previews pass `.standard` (and one tricky preview with `.hard`).
- [ ] **Step 3: Strings.** `quiz.tricky` „Schau genau hin!", `quiz.tricky.accessibility` „Knifflige Frage".
- [ ] **Step 4: Commit** `feat(app): mark tricky questions in a round`

---

### Task 8: Finish

- [ ] Run `/simplify` over the branch diff and apply what holds.
- [ ] Self-review of the whole diff (`superpowers:requesting-code-review`), visual review of the mockup against the implemented values.
- [ ] Open the pull request with the post-merge steps: render the new speech clips (`fetch-media speech render --sentence home.difficulty.title` and the level names and `quiz.tricky`), upload the ten bucket packs with their new manifests and the index, check the home screen on a 375 pt iPhone, an iPad and „Designed for iPad" on a Mac.
