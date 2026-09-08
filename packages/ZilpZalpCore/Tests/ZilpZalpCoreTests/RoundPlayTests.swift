import Testing
import ZilpZalpCore

// MARK: - Rounds to play

/// A play of a freshly dealt round. The seed keeps it the same round on every
/// machine, so an assertion about a particular question stays true. Six
/// species are enough for the first questions to ask for different birds,
/// which is all any of these tests needs of the pool.
private func dealt(questionCount: Int = 10, seed: UInt64 = 1) throws -> RoundPlay {
    var generator = SplitMix64(seed: seed)
    return try RoundPlay(
        round: Round.make(from: distinctGenera(6), questionCount: questionCount, using: &generator),
    )
}

/// The species the current question asks for.
private func answer(of play: RoundPlay) throws -> String {
    try #require(play.question).answer
}

/// A choice of the current question that is not the answer.
private func distractor(of play: RoundPlay) throws -> String {
    let question = try #require(play.question)
    return try #require(question.choices.first { $0 != question.answer })
}

// MARK: - A single question

@Test("A wrong tap costs the first try and nothing else")
func wrongTapMarksTheTile() throws {
    var play = try dealt()
    let wrong = try distractor(of: play)

    #expect(play.tap(wrong) == .wrong)

    #expect(play.wrongTaps == [wrong])
    #expect(!play.isAnswered)
    #expect(play.firstTryCorrect == 0)
    #expect(play.phase(of: wrong) == .retry)
    #expect(!play.isDimmed(wrong))
}

@Test("The same wrong tile may be tapped again")
func wrongTapsRepeat() throws {
    var play = try dealt()
    let wrong = try distractor(of: play)

    #expect(play.tap(wrong) == .wrong)
    #expect(play.tap(wrong) == .wrong)

    #expect(play.wrongTaps == [wrong])
    #expect(play.firstTryCorrect == 0)
}

@Test("Wrong and then right is not a first try")
func wrongThenRightIsNoFirstTry() throws {
    var play = try dealt()
    let right = try answer(of: play)
    let wrong = try distractor(of: play)

    #expect(play.tap(wrong) == .wrong)
    #expect(play.tap(right) == .correct(firstTry: false))

    #expect(play.isAnswered)
    #expect(play.firstTryCorrect == 0)
}

@Test("The tile tapped wrong stays a retry beside the answer, and steps back")
func phasesOnceTheAnswerIsFound() throws {
    var play = try dealt()
    let question = try #require(play.question)
    let wrong = try distractor(of: play)
    let untouched = try #require(
        question.choices.first { $0 != question.answer && $0 != wrong },
    )

    #expect(play.tap(wrong) == .wrong)
    #expect(play.tap(question.answer) == .correct(firstTry: false))

    #expect(play.phase(of: question.answer) == .correct)
    #expect(play.phase(of: wrong) == .retry)
    #expect(play.phase(of: untouched) == .idle)
    #expect(!play.isDimmed(question.answer))
    #expect(play.isDimmed(wrong))
    #expect(play.isDimmed(untouched))
}

@Test("A second tap on the answer scores once")
func doubleTapOnTheAnswerScoresOnce() throws {
    var play = try dealt()
    let right = try answer(of: play)

    #expect(play.tap(right) == .correct(firstTry: true))
    #expect(play.tap(right) == .ignored)

    #expect(play.firstTryCorrect == 1)
}

@Test("Every tap after the answer is ignored")
func tapsAfterTheAnswerAreIgnored() throws {
    var play = try dealt()
    let right = try answer(of: play)
    let wrong = try distractor(of: play)

    #expect(play.tap(right) == .correct(firstTry: true))
    #expect(play.tap(wrong) == .ignored)

    #expect(play.wrongTaps.isEmpty)
    #expect(play.phase(of: wrong) == .idle)
}

// MARK: - Moving on

@Test("Moving on clears the question's taps")
func advanceClearsTheQuestion() throws {
    var play = try dealt()
    let right = try answer(of: play)
    let wrong = try distractor(of: play)
    #expect(play.tap(wrong) == .wrong)
    #expect(play.tap(right) == .correct(firstTry: false))

    play.advance()

    #expect(play.index == 1)
    #expect(play.wrongTaps.isEmpty)
    #expect(!play.isAnswered)
    #expect(!play.isFinished)
}

@Test("Moving past the last question finishes the round")
func advancePastTheLastQuestionFinishes() throws {
    var play = try dealt(questionCount: 2)

    for _ in 0 ..< 2 {
        let right = try answer(of: play)
        #expect(play.tap(right) == .correct(firstTry: true))
        play.advance()
    }

    #expect(play.isFinished)
    #expect(play.index == 2)
    #expect(play.question == nil)
    #expect(play.firstTryCorrect == 2)
}

@Test("A finished round neither answers nor moves on")
func aFinishedRoundStandsStill() throws {
    var play = try dealt(questionCount: 1)
    let right = try answer(of: play)
    #expect(play.tap(right) == .correct(firstTry: true))
    play.advance()

    #expect(play.tap(right) == .ignored)
    play.advance()

    #expect(play.index == 1)
    #expect(play.firstTryCorrect == 1)
    #expect(play.phase(of: right) == .idle)
    #expect(!play.isDimmed(right))
}

// MARK: - What the round comes to

@Test("Only answers right at the first attempt are counted")
func firstTryCorrectCountsOnlyCleanQuestions() throws {
    var play = try dealt()
    var expected = 0

    while let question = play.question {
        // Every third question is tapped wrong once first.
        let fumbled = play.index % 3 == 2
        if fumbled {
            let wrong = try distractor(of: play)
            #expect(play.tap(wrong) == .wrong)
        } else {
            expected += 1
        }
        #expect(play.tap(question.answer) == .correct(firstTry: !fumbled))
        play.advance()
    }

    #expect(play.firstTryCorrect == expected)
    #expect(expected == 7)
}

@Test("The celebrated species is the first one answered at the first attempt")
func celebratedSpeciesIsTheFirstCleanAnswer() throws {
    var play = try dealt()
    let first = try answer(of: play)
    let wrong = try distractor(of: play)

    // The first question is fumbled, the second and third are not.
    #expect(play.tap(wrong) == .wrong)
    #expect(play.tap(first) == .correct(firstTry: false))
    play.advance()
    let second = try answer(of: play)
    #expect(play.tap(second) == .correct(firstTry: true))

    #expect(second != first)
    #expect(play.celebratedSpecies == second)

    // And it stays that one, however well the rest of the round goes.
    play.advance()
    let third = try answer(of: play)
    #expect(play.tap(third) == .correct(firstTry: true))

    #expect(play.celebratedSpecies == second)
}

@Test("A round nothing was won in still celebrates its first question")
func celebratedSpeciesFallsBackToTheFirstQuestion() throws {
    var play = try dealt()
    let first = try answer(of: play)
    let wrong = try distractor(of: play)

    #expect(play.celebratedSpecies == first)

    #expect(play.tap(wrong) == .wrong)
    #expect(play.tap(first) == .correct(firstTry: false))

    #expect(play.celebratedSpecies == first)
}

@Test("A round without questions is over before it starts")
func anEmptyRoundIsFinished() throws {
    var play = try dealt(questionCount: 0)

    #expect(play.isFinished)
    #expect(play.question == nil)
    #expect(play.celebratedSpecies == nil)
    #expect(play.tap("species-0") == .ignored)

    play.advance()

    #expect(play.index == 0)
    #expect(play.firstTryCorrect == 0)
}
