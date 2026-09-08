/// A ``Round`` while it is being played: where in it the child is, and what
/// has been tapped so far.
///
/// One tap in, the next state out. The type holds no clock, no photos and no
/// speech — a tap is a pure transition, and everything a screen wants to know
/// about a tile is derived from the three facts below rather than stored a
/// fourth time where it could disagree with them.
public struct RoundPlay: Hashable, Sendable {
    /// What a tap came to.
    public enum Tap: Hashable, Sendable {
        /// The bird the question asked for. `firstTry` is true when nothing
        /// wrong had been tapped on this question yet — the only tap that
        /// earns anything.
        case correct(firstTry: Bool)

        /// Another bird. It costs the first try and nothing else: no lock, no
        /// counter the child sees, and the same tile may be tapped again.
        case wrong

        /// Nothing left to answer — the question is already answered, or the
        /// round is over. The state is unchanged.
        case ignored
    }

    /// Where one species' tile stands in the question being asked.
    public enum Phase: Hashable, Sendable {
        /// Untouched, waiting.
        case idle

        /// Already tried on this question: go round again.
        case retry

        /// The answer, once it has been found.
        case correct
    }

    /// The round being played. A play never changes its round; a new round is
    /// a new play.
    public let round: Round

    /// Which question is being asked, `round.questions.count` once the round
    /// is over.
    public private(set) var index = 0

    /// The species tapped on the current question that were not the answer.
    /// Cleared by every ``advance()``; it is what makes a tile show
    /// ``Phase/retry`` and what decides whether the answer still counts as a
    /// first try.
    public private(set) var wrongTaps: Set<String> = []

    /// True from the moment the answer is tapped until the next question is
    /// asked. Locks nothing a child can feel — it only stops a second tap
    /// from scoring twice.
    public private(set) var isAnswered = false

    /// Answers right at the first attempt. The one number the stars come
    /// from; see ``Scoring/stars(firstTryCorrect:)``.
    public private(set) var firstTryCorrect = 0

    /// The first species answered right at the first attempt, `nil` until one
    /// is. Only ever set once — the round end celebrates the first such bird,
    /// not the latest.
    private var firstTrySpecies: String?

    /// Starts `round` at its first question, with nothing tapped.
    public init(round: Round) {
        self.round = round
    }

    /// The question being asked, `nil` once the round is over.
    public var question: Round.Question? {
        index < round.questions.count ? round.questions[index] : nil
    }

    /// True once the round has moved past its last question.
    public var isFinished: Bool {
        index >= round.questions.count
    }

    /// The species the round end puts on its sticker: the first one answered
    /// right at the first attempt, or the round's first question when there
    /// was none. `nil` only for a round without questions.
    ///
    /// A round always earns a sticker, which is why the fallback is a species
    /// and not nothing: the celebration shows what was met, never how well it
    /// went.
    public var celebratedSpecies: String? {
        firstTrySpecies ?? round.questions.first?.answer
    }

    /// Where `species`' tile stands: the answer once it has been found, a "go
    /// round again" for anything already tried, untouched otherwise.
    ///
    /// The answer is asked about first, so a tile that was tapped wrong and
    /// then turned out to be the answer is impossible — but a wrong tile
    /// stays ``Phase/retry`` while the answer is celebrated beside it.
    public func phase(of species: String) -> Phase {
        if isAnswered, species == question?.answer {
            return .correct
        }
        if wrongTaps.contains(species) {
            return .retry
        }
        return .idle
    }

    /// Whether `species`' tile steps back. Only once the answer is found, and
    /// only for the others — opacity, never a lock.
    public func isDimmed(_ species: String) -> Bool {
        isAnswered && species != question?.answer
    }

    /// A tile was tapped.
    ///
    /// - Parameter species: The identifier of the species tapped.
    /// - Returns: What the tap came to, so the caller can start whatever a
    ///   right answer is worth outside these walls — a sound, a pause, a move
    ///   to the next question.
    public mutating func tap(_ species: String) -> Tap {
        guard let question, !isAnswered else { return .ignored }

        guard species == question.answer else {
            wrongTaps.insert(species)
            return .wrong
        }

        let firstTry = wrongTaps.isEmpty
        if firstTry {
            firstTryCorrect += 1
            firstTrySpecies = firstTrySpecies ?? species
        }
        isAnswered = true
        return .correct(firstTry: firstTry)
    }

    /// Moves the round on by one question.
    ///
    /// A finished round stays where it is: ``index`` is the question being
    /// asked and must never point past the last one, or a progress row would
    /// be told that more questions were answered than the round ever had.
    public mutating func advance() {
        guard !isFinished else { return }
        index += 1
        wrongTaps = []
        isAnswered = false
    }
}
