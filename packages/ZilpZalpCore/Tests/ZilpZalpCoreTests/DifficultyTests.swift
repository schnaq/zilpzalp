import Testing
import ZilpZalpCore

// MARK: - Pools

/// Owls, tits and ducks, five of each, every species its own genus — so
/// only the look-alike group can make two of them alike.
private func groupedPool() -> [QuizSpecies] {
    (["owl", "tit", "duck"] as [String]).flatMap { group in
        (0 ..< 5).map { QuizSpecies(
            id: "\(group)-\($0)",
            genus: "\(group)-genus-\($0)",
            lookalike: group,
        ) }
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

@Test(
    "Without any look-alike in the pool no question is tricky",
    arguments: [Difficulty.medium, .hard],
)
func noLookalikesNoTricks(level: Difficulty) throws {
    let pool = distinctGenera(25)
    var generator = SplitMix64(seed: 3)

    let round = try Round.make(from: pool, difficulty: level, using: &generator)

    expectWellFormed(round, pool: pool)
    #expect(round.questions.allSatisfy { !$0.isTricky })
}

@Test(
    "Mittel and Schwer deal their plain questions by Klassisch's rule",
    arguments: [Difficulty.medium, .hard],
)
func plainQuestionsAreClassic(level: Difficulty) throws {
    // Every species is its own genus, so Klassisch lets a same-group bird
    // stand beside the answer where Leicht never would.
    let pool = groupedPool()
    var generator = SplitMix64(seed: 42)
    let round = try Round.make(from: pool, difficulty: level, using: &generator)
    #expect(round.questions
        .contains { !$0.isTricky && lookalikes(in: $0, pool: byIdentifier(pool)) > 0 })
}

@Test("Schwer takes the one look-alike there is and fills up with others")
func hardWithOneLookalike() throws {
    // Pairs only: every answer has exactly one look-alike.
    let pool = (0 ..< 6).flatMap { pair in
        (0 ..< 2).map { QuizSpecies(
            id: "p\(pair)-\($0)",
            genus: "g\(pair)-\($0)",
            lookalike: "pair-\(pair)",
        ) }
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
    let pool = (0 ..< 4).map { QuizSpecies(
        id: "s\($0)",
        genus: "g\($0)",
        lookalike: $0 < 2 ? "a" : "b",
    ) }
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
