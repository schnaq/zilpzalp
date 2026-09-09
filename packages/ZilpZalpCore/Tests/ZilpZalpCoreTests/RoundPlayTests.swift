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

// MARK: - What the round recognised

@Test("Only clean answers are recognitions, in the order they happened")
func recognitionsAreTheCleanAnswersInOrder() throws {
    var play = try dealt()
    let fumbled = try answer(of: play)
    let wrong = try distractor(of: play)

    // The first question is fumbled, so it is no recognition at all.
    #expect(play.tap(wrong) == .wrong)
    #expect(play.tap(fumbled) == .correct(firstTry: false))
    play.advance()
    let second = try answer(of: play)
    #expect(play.tap(second) == .correct(firstTry: true))
    play.advance()
    let third = try answer(of: play)
    #expect(play.tap(third) == .correct(firstTry: true))

    #expect(play.firstTryRecognitions == [second, third])
    #expect(play.recognitions == [second: 1, third: 1])
    // The number the stars come from is that list's length, so the two can
    // never fall out of step.
    #expect(play.firstTryCorrect == 2)
}

@Test("A bird the round asks for twice is recognised twice")
func recognitionsCountRepeatedQuestions() throws {
    // Four species and eight questions: every bird comes round again, which
    // is what `Round.make` promises for a pool smaller than the round.
    var generator = SplitMix64(seed: 7)
    var play = try RoundPlay(
        round: Round.make(from: distinctGenera(4), questionCount: 8, using: &generator),
    )
    let askedFor = play.round.questions.map(\.answer)

    while !play.isFinished {
        let asked = try answer(of: play)
        #expect(play.tap(asked) == .correct(firstTry: true))
        play.advance()
    }

    #expect(play.firstTryRecognitions == askedFor)
    #expect(play.recognitions[askedFor[0]] == askedFor.count { $0 == askedFor[0] })
    #expect(play.recognitions.values.reduce(0, +) == 8)
    // Four species asked eight times: at least one of them stands twice, or
    // this test is not testing what it says.
    #expect(play.recognitions.count < askedFor.count)
}

// MARK: - Which bird the round end celebrates

/// Two questions of a fresh round, both answered at the first attempt.
///
/// The two species are the answers of ``Round/questions`` 0 and 1, so each
/// test reads them off the play rather than being handed a tuple of three.
private func twoRecognitions() throws -> RoundPlay {
    var play = try dealt()
    let first = try answer(of: play)
    #expect(play.tap(first) == .correct(firstTry: true))
    play.advance()
    let second = try answer(of: play)
    #expect(play.tap(second) == .correct(firstTry: true))
    #expect(first != second)
    return play
}

@Test("A sticker completed in this round is the news of it")
func celebratedSpeciesIsTheCompletedSticker() throws {
    let play = try twoRecognitions()
    let first = play.round.questions[0].answer
    let second = play.round.questions[1].answer

    // The second bird reaches its fifth recognition here. The first is the
    // closer of the two to nothing, and stood first, and neither counts
    // against a sticker that has just been earned.
    #expect(play.celebratedSpecies(recognisedBefore: [first: 3, second: 4]) == second)
}

@Test("Without a sticker earned, the bird closest to one is celebrated")
func celebratedSpeciesIsTheClosestToASticker() throws {
    let play = try twoRecognitions()
    let first = play.round.questions[0].answer
    let second = play.round.questions[1].answer

    // Three of five beats one of five, whichever came first in the round.
    #expect(play.celebratedSpecies(recognisedBefore: [first: 0, second: 2]) == second)
    #expect(play.celebratedSpecies(recognisedBefore: [first: 2, second: 0]) == first)
    // A tie goes to the bird recognised first, so the answer never depends on
    // how a dictionary happens to iterate.
    #expect(play.celebratedSpecies(recognisedBefore: [:]) == first)
}

@Test("A bird already collected yields to one still collecting")
func celebratedSpeciesPrefersAStickerStillToBeEarned() throws {
    let play = try twoRecognitions()
    let first = play.round.questions[0].answer
    let second = play.round.questions[1].answer

    // The first bird has been known for a while and has nothing left to show;
    // the second is on its way, and that row of markers is worth seeing.
    #expect(play.celebratedSpecies(recognisedBefore: [first: 9, second: 1]) == second)
    // With every bird of the round long since collected, the first one
    // recognised is celebrated — as it was before any of this.
    #expect(play.celebratedSpecies(recognisedBefore: [first: 6, second: 8]) == first)
}

@Test("A round nothing was won in still celebrates its first question")
func celebratedSpeciesFallsBackToTheFirstQuestion() throws {
    var play = try dealt()
    let first = try answer(of: play)
    let wrong = try distractor(of: play)

    #expect(play.celebratedSpecies(recognisedBefore: [:]) == first)

    #expect(play.tap(wrong) == .wrong)
    #expect(play.tap(first) == .correct(firstTry: false))

    // Found in the end is not recognised, so the round has nothing to go on
    // but the bird it began with.
    #expect(play.celebratedSpecies(recognisedBefore: [first: 4]) == first)
}

@Test("A round without questions is over before it starts")
func anEmptyRoundIsFinished() throws {
    var play = try dealt(questionCount: 0)

    #expect(play.isFinished)
    #expect(play.question == nil)
    #expect(play.celebratedSpecies(recognisedBefore: [:]) == nil)
    #expect(play.tap("species-0") == .ignored)

    play.advance()

    #expect(play.index == 0)
    #expect(play.firstTryCorrect == 0)
}
