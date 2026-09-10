/// Which photo of a species each tile of a round shows.
///
/// A species may carry several photos (#194), and a child that meets the same
/// picture in every question learns the picture rather than the bird. So every
/// tile of a round draws one, under one rule: **a species does not show a
/// photo twice in a round while it has one it has not shown yet.**
///
/// Dealt once for the whole round rather than asked per draw, because a tile is
/// rebuilt on every layout pass and a photo that changed under a child's finger
/// would be the most visible thing on the screen. Randomness comes solely from
/// the generator handed in, so the same round with the same seed yields the same
/// photos — which is what makes the rule testable.
public struct RoundPhotos: Hashable, Sendable {
    /// Per question, the photo index of every species offered in it. Only
    /// species with more than one photo are in the dictionaries: everything
    /// else answers with the first photo anyway, and leaving them out is what
    /// keeps a pack of single-photo species from consuming any randomness at
    /// all.
    private let questions: [[String: Int]]

    /// Deals the photos of one round.
    ///
    /// - Parameters:
    ///   - round: the round, whose questions and choices are walked in order —
    ///     never `photoCounts`, whose order a dictionary does not have.
    ///   - photoCounts: how many photos each species carries, by species id. A
    ///     species that is missing, or carries one, shows its first photo.
    ///   - generator: the source of randomness.
    public init(
        round: Round,
        photoCounts: [String: Int],
        using generator: inout some RandomNumberGenerator,
    ) {
        // What a species has left to show before it may repeat itself. Refilled
        // with a fresh shuffle once it runs out, exactly as ``Round`` deals the
        // species to ask for — which pushes a repeat as late as the photos
        // allow.
        var decks: [String: [Int]] = [:]

        var questions: [[String: Int]] = []
        questions.reserveCapacity(round.questions.count)
        for question in round.questions {
            var chosen: [String: Int] = [:]
            for species in question.choices {
                guard let count = photoCounts[species], count > 1 else { continue }
                if decks[species]?.isEmpty ?? true {
                    decks[species] = Array(0 ..< count).shuffled(using: &generator)
                }
                chosen[species] = decks[species]?.removeLast()
            }
            questions.append(chosen)
        }
        self.questions = questions
    }

    /// Which photo `species` shows in the question at `question`.
    ///
    /// - Returns: an index into the species' photos, 0 for a species that carries
    ///   one photo, was not in the round, or a question the round does not
    ///   have. The first photo is the curated portrait and always exists, so
    ///   there is nothing to report and nobody who could act on it.
    public func photo(for species: String, question: Int) -> Int {
        guard questions.indices.contains(question) else { return 0 }
        return questions[question][species] ?? 0
    }
}
