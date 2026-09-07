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
    /// The pool carries every species that can be asked for and every species
    /// that can serve as a distractor; the engine never invents one. Two rules
    /// shape the result:
    ///
    /// - A species is asked for a second time only once every other species
    ///   has been asked for. A pool smaller than `questionCount` therefore
    ///   still yields `questionCount` questions, with the repeats as late in
    ///   the round as possible.
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
    ///   the pool cannot fill a single question's choices.
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

        var questions: [Question] = []
        questions.reserveCapacity(questionCount)
        for answer in answers(from: species, questionCount: questionCount, using: &generator) {
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

    /// Draws the species to ask for: a random pass through the whole pool,
    /// then the next one, until there are enough. That is what pushes the
    /// repeats of a small pool to the end of the round.
    private static func answers(
        from species: [QuizSpecies],
        questionCount: Int,
        using generator: inout some RandomNumberGenerator,
    ) -> [QuizSpecies] {
        var answers: [QuizSpecies] = []
        answers.reserveCapacity(questionCount)
        var pass: [QuizSpecies] = []
        for _ in 0 ..< questionCount {
            if pass.isEmpty {
                pass = species.shuffled(using: &generator)
            }
            answers.append(pass.removeLast())
        }
        return answers
    }

    /// Picks the distractors for one answer: species of another genus first,
    /// species of the answer's own genus only to fill up. The answer itself is
    /// never among them, and no species twice.
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
}
