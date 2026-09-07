import Testing
import ZilpZalpCore

// MARK: - Pools

private let tit = "Parus"
private let thrush = "Turdus"

/// A pool in which every species is a genus of its own — the case where the
/// genus rule never has to fall back.
private func distinctGenera(_ count: Int) -> [QuizSpecies] {
    (0 ..< count).map { QuizSpecies(id: "species-\($0)", genus: "genus-\($0)") }
}

private func species(_ count: Int, of genus: String) -> [QuizSpecies] {
    (0 ..< count).map { QuizSpecies(id: "\(genus)-\($0)", genus: genus) }
}

private func genusByIdentifier(_ pool: [QuizSpecies]) -> [String: String] {
    Dictionary(uniqueKeysWithValues: pool.map { ($0.id, $0.genus) })
}

/// The invariants that hold for every round, whatever the pool looks like.
private func expectWellFormed(
    _ round: Round,
    questionCount: Int,
    choiceCount: Int,
    pool: [QuizSpecies],
) {
    let identifiers = Set(pool.map(\.id))

    #expect(round.questions.count == questionCount)
    for question in round.questions {
        let choices = Set(question.choices)
        #expect(question.choices.count == choiceCount)
        #expect(question.choices.filter { $0 == question.answer }.count == 1)
        #expect(choices.count == choiceCount)
        #expect(choices.isSubset(of: identifiers))
    }
}

// MARK: - Shape

@Test("Every pool size yields ten questions of four distinct choices", arguments: [4, 9, 10, 25])
func roundIsWellFormed(poolSize: Int) throws {
    var generator = SplitMix64(seed: 1)
    let pool = distinctGenera(poolSize)

    let round = try Round.make(from: pool, using: &generator)

    expectWellFormed(round, questionCount: 10, choiceCount: 4, pool: pool)
}

@Test(
    "A pool below the choice count cannot fill a single question",
    arguments: [(poolSize: 3, choiceCount: 4), (poolSize: 4, choiceCount: 5)],
)
func tooFewSpeciesThrows(poolSize: Int, choiceCount: Int) {
    var generator = SplitMix64(seed: 1)
    let pool = distinctGenera(poolSize)

    #expect(throws: RoundError.insufficientSpecies(required: choiceCount, available: poolSize)) {
        try Round.make(from: pool, choiceCount: choiceCount, using: &generator)
    }
}

@Test("Question and choice count are parameters, not fixed numbers")
func customCounts() throws {
    var generator = SplitMix64(seed: 13)
    let pool = distinctGenera(5)

    let round = try Round.make(from: pool, questionCount: 7, choiceCount: 3, using: &generator)

    expectWellFormed(round, questionCount: 7, choiceCount: 3, pool: pool)
    #expect(Set(round.questions.prefix(5).map(\.answer)).count == 5)
}

// MARK: - Answers

@Test("A pool of at least ten species never asks for the same one twice", arguments: [10, 25])
func answersDoNotRepeat(poolSize: Int) throws {
    var generator = SplitMix64(seed: 7)
    let pool = distinctGenera(poolSize)

    let round = try Round.make(from: pool, using: &generator)

    let answers = round.questions.map(\.answer)
    #expect(Set(answers).count == answers.count)
}

@Test(
    "A small pool is asked through completely before a species returns",
    arguments: [4, 9], [11, 23, 37] as [UInt64],
)
func repeatsComeAfterAFullPass(poolSize: Int, seed: UInt64) throws {
    var generator = SplitMix64(seed: seed)
    let pool = distinctGenera(poolSize)

    let round = try Round.make(from: pool, using: &generator)

    // Every full slice of pool size is one pass through the whole pool, so a
    // species returns only once every other species has been asked for.
    let answers = round.questions.map(\.answer)
    let identifiers = Set(pool.map(\.id))
    for start in stride(from: 0, through: answers.count - poolSize, by: poolSize) {
        #expect(Set(answers[start ..< start + poolSize]) == identifiers)
    }

    // What is left over is a started pass and at least free of repeats.
    let tail = answers.suffix(answers.count % poolSize)
    #expect(Set(tail).count == tail.count)
}

@Test("The answer does not always sit in the same place")
func theAnswerMovesBetweenTheChoices() throws {
    var generator = SplitMix64(seed: 19)
    let pool = distinctGenera(10)

    let round = try Round.make(from: pool, using: &generator)

    // A child who learns "the last tile is right" learns nothing about birds.
    let positions = round.questions.map { $0.choices.firstIndex(of: $0.answer) }
    #expect(Set(positions).count > 1)
}

// MARK: - Determinism

@Test("The same pool and the same seed yield the same round")
func sameSeedYieldsSameRound() throws {
    let pool = distinctGenera(12)
    var first = SplitMix64(seed: 42)
    var second = SplitMix64(seed: 42)

    let firstRound = try Round.make(from: pool, using: &first)
    let secondRound = try Round.make(from: pool, using: &second)

    #expect(firstRound == secondRound)
}

@Test("Two seeds yield two different rounds")
func differentSeedsYieldDifferentRounds() throws {
    let pool = distinctGenera(12)
    var first = SplitMix64(seed: 42)
    var second = SplitMix64(seed: 43)

    let firstRound = try Round.make(from: pool, using: &first)
    let secondRound = try Round.make(from: pool, using: &second)

    #expect(firstRound != secondRound)
    #expect(firstRound.questions.map(\.answer) != secondRound.questions.map(\.answer))
}

// MARK: - Genus

@Test("Distractors avoid the answer's genus while the pool holds enough others")
func distractorsAvoidTheAnswersGenus() throws {
    var generator = SplitMix64(seed: 3)
    let pool = species(3, of: tit) + species(3, of: thrush)
    let genus = genusByIdentifier(pool)

    let round = try Round.make(from: pool, using: &generator)

    for question in round.questions {
        for distractor in question.choices where distractor != question.answer {
            #expect(genus[distractor] != genus[question.answer])
        }
    }
}

@Test("The answer's own genus fills up only what the other genera cannot")
func distractorsFallBackToTheAnswersGenus() throws {
    var generator = SplitMix64(seed: 5)
    let pool = species(4, of: tit) + species(1, of: thrush)
    let genus = genusByIdentifier(pool)
    let onlyThrush = "\(thrush)-0"

    let round = try Round.make(from: pool, using: &generator)

    expectWellFormed(round, questionCount: 10, choiceCount: 4, pool: pool)
    for question in round.questions {
        let distractors = question.choices.filter { $0 != question.answer }
        if question.answer == onlyThrush {
            #expect(distractors.allSatisfy { genus[$0] == tit })
        } else {
            // One thrush exists, so it has to be used before a second tit is.
            #expect(distractors.contains(onlyThrush))
            #expect(distractors.filter { genus[$0] == tit }.count == 2)
        }
    }
}

@Test("A pool of one genus still yields valid questions")
func singleGenusPoolStillWorks() throws {
    var generator = SplitMix64(seed: 17)
    let pool = species(6, of: tit)

    let round = try Round.make(from: pool, using: &generator)

    expectWellFormed(round, questionCount: 10, choiceCount: 4, pool: pool)
}
