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

    /// Every species answered right at the first attempt, in the order those
    /// answers happened. A species the round asks for twice and the child
    /// knows twice stands in here twice — a pack with few species to ask for
    /// repeats them late in the round, see ``Round/make(from:questionCount:choiceCount:using:)``.
    ///
    /// The one record behind everything the round has to say about
    /// recognition: how many stars it earned, how often each bird was known,
    /// which bird was known first, and which of two birds came first when the
    /// sticker rule has to choose between them. One fact rather than four, so
    /// that none of them can disagree with the others.
    public private(set) var firstTryRecognitions: [String] = []

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

    /// Answers right at the first attempt. The one number the stars come
    /// from; see ``Scoring/stars(firstTryCorrect:)``.
    public var firstTryCorrect: Int {
        firstTryRecognitions.count
    }

    /// How often each species was answered right at the first attempt in this
    /// round — what the round hands over to be added onto the child's
    /// counters, five of which earn a sticker.
    public var recognitions: [String: Int] {
        firstTryRecognitions.reduce(into: [:]) { counts, species in
            counts[species, default: 0] += 1
        }
    }

    /// The species the round end puts on its sticker, judged against what the
    /// child had recognised before this round (#177).
    ///
    /// In this order:
    ///
    /// 1. a bird whose fifth recognition happened in this round — its sticker
    ///    was just earned, and that is the news of the round
    /// 2. otherwise the bird that came closest to its fifth without reaching
    ///    it, among those recognised in this round: the one whose row of
    ///    markers has the most to show
    /// 3. otherwise the first bird recognised in this round, whose sticker was
    ///    in the album already
    /// 4. otherwise the first question's answer
    ///
    /// A round always shows a bird, which is why the last step is a species
    /// and not nothing: the celebration shows what was met, never how badly it
    /// went. `nil` only for a round without questions.
    ///
    /// Ties go to the bird recognised first — the order of
    /// ``firstTryRecognitions`` throughout, so the answer never depends on how
    /// a dictionary happens to iterate.
    ///
    /// - Parameter recognisedBefore: how often the child had recognised each
    ///   species before this round, as ``recognitions`` counts them. The play
    ///   does not store it: a round is played by whoever is holding the iPad,
    ///   and asking at the end is what keeps the answer from being one round
    ///   out of date.
    public func celebratedSpecies(recognisedBefore: [String: Int]) -> String? {
        let inRound = recognitions
        let total = { (species: String) in
            (recognisedBefore[species] ?? 0) + (inRound[species] ?? 0)
        }
        let recognised = firstTryRecognitions.reduce(into: [String]()) { seen, species in
            if !seen.contains(species) {
                seen.append(species)
            }
        }

        let completed = recognised.first { species in
            (recognisedBefore[species] ?? 0) < Scoring.recognitionsForSticker
                && total(species) >= Scoring.recognitionsForSticker
        }
        let underway = recognised.filter { total($0) < Scoring.recognitionsForSticker }
        // The most recognitions among them, then the first bird that has that
        // many. Not `max(by:)`, which does not promise which of two equals it
        // answers with — and here that decides which bird a child sees.
        let furthest = underway.map(total).max()

        return completed
            ?? underway.first { total($0) == furthest }
            ?? recognised.first
            ?? round.questions.first?.answer
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
    /// - Parameter species: The identifier of the species tapped. One of the
    ///   current question's ``Round/Question/choices``; anything else is
    ///   recorded as a wrong tap, since a play cannot tell a bird it was
    ///   never offered from one it was.
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
            firstTryRecognitions.append(species)
        }
        isAnswered = true
        return .correct(firstTry: firstTry)
    }

    /// Moves the round on by one question, answered or not — a question a
    /// child walked away from is a question that is over.
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
