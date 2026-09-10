/// A round of the quiz: a fixed number of questions, each asking for one
/// species among several choices.
public struct Round: Hashable, Sendable {
    /// One question of a round.
    public struct Question: Hashable, Sendable {
        /// Identifier of the species that is the correct answer.
        public let answer: String

        /// Identifiers of every species offered, in the order they are shown.
        /// Contains `answer` exactly once and no species twice.
        public let choices: [String]
    }

    /// The questions in the order they are asked.
    public let questions: [Question]

    /// Builds a round from a pool of species.
    ///
    /// The pool carries every species that can appear in a question; the engine
    /// never invents one. Which of them may be asked *for* is
    /// ``QuizSpecies/canBeAsked`` — game 2 asks with a recorded call and cannot
    /// ask for a species that has none, while that species' photo is still a
    /// perfectly good distractor (#31). Two rules shape the result:
    ///
    /// - A species is asked for a second time only once every other askable
    ///   species has been asked for. Fewer askable species than `questionCount`
    ///   therefore still yield `questionCount` questions, with the repeats as
    ///   late in the round as possible.
    /// - Distractors come from a genus other than the answer's. Only when the
    ///   pool holds too few of those does the answer's own genus fill up.
    ///
    /// Randomness comes solely from `generator`, so the same pool in the same
    /// order with the same seed yields the same round.
    ///
    /// - Parameters:
    ///   - species: The pool to draw from. The species must be distinct.
    ///   - questionCount: How many questions the round has.
    ///   - choiceCount: How many choices each question offers, the answer
    ///     included.
    ///   - generator: The source of randomness.
    /// - Throws: ``RoundError/insufficientSpecies(required:available:)`` when
    ///   the pool cannot fill a single question's choices, and
    ///   ``RoundError/noSpeciesToAskFor`` when none of it may be asked for.
    public static func make(
        from species: [QuizSpecies],
        questionCount: Int = 10,
        choiceCount: Int = 4,
        using generator: inout some RandomNumberGenerator,
    ) throws -> Round {
        guard species.count >= choiceCount else {
            throw RoundError.insufficientSpecies(
                required: choiceCount,
                available: species.count,
            )
        }

        // Judged after the choices and on its own count: a question needs four
        // species to fill it and one it may ask for, and those are two
        // different demands on the same pool.
        let askable = species.filter(\.canBeAsked)
        guard !askable.isEmpty else {
            throw RoundError.noSpeciesToAskFor
        }

        var questions: [Question] = []
        questions.reserveCapacity(questionCount)
        for answer in answers(from: askable, questionCount: questionCount, using: &generator) {
            var choices = distractors(
                for: answer,
                from: species,
                count: choiceCount - 1,
                using: &generator,
            )
            choices.append(answer)
            questions.append(
                Question(
                    answer: answer.id,
                    choices: choices.shuffled(using: &generator).map(\.id),
                ),
            )
        }
        return Round(questions: questions)
    }

    /// Draws the species to ask for: a random pass through every askable
    /// species, then the next one, until there are enough. That is what pushes
    /// the repeats of a small askable set to the end of the round, and it is
    /// ``ShuffleBag``'s rule — the same one a tile picks its photo by.
    private static func answers(
        from askable: [QuizSpecies],
        questionCount: Int,
        using generator: inout some RandomNumberGenerator,
    ) -> [QuizSpecies] {
        var bag = ShuffleBag(askable)
        var answers: [QuizSpecies] = []
        answers.reserveCapacity(questionCount)
        for _ in 0 ..< questionCount {
            // Never nil: the caller has refused an empty askable set already.
            guard let answer = bag.next(using: &generator) else { break }
            answers.append(answer)
        }
        return answers
    }

    /// Picks the distractors for one answer from the whole pool, askable or
    /// not: species of another genus first, species of the answer's own genus
    /// only to fill up. The answer itself is never among them, and no species
    /// twice.
    private static func distractors(
        for answer: QuizSpecies,
        from species: [QuizSpecies],
        count: Int,
        using generator: inout some RandomNumberGenerator,
    ) -> [QuizSpecies] {
        let candidates = species.filter { $0 != answer }
        let otherGenus = candidates.filter { $0.genus != answer.genus }
        let sameGenus = candidates.filter { $0.genus == answer.genus }
        let ranked = otherGenus.shuffled(using: &generator) + sameGenus.shuffled(using: &generator)
        return Array(ranked.prefix(count))
    }
}

/// Why a round could not be built.
public enum RoundError: Error, Equatable, Sendable {
    /// The pool holds fewer species than one question needs choices, so the
    /// game cannot be offered at all.
    case insufficientSpecies(required: Int, available: Int)

    /// Every species in the pool has ``QuizSpecies/canBeAsked`` false, so there
    /// is nothing to ask about. The shell decides whether a game can be offered
    /// before it opens a screen for it (#31); reaching this means it offered
    /// one it should not have.
    case noSpeciesToAskFor
}
