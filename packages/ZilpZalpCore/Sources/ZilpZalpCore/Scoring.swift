/// Stars a single round earns.
///
/// Only answers that were right on the first attempt count. A question the
/// child gets right on the second try does not count — that is what makes
/// three stars worth playing for.
public enum Scoring {
    /// From this many first-try correct answers on, a round earns three stars.
    private static let firstTryCorrectForThreeStars = 9

    /// From this many first-try correct answers on, a round earns two stars.
    private static let firstTryCorrectForTwoStars = 6

    /// The stars for a round with `firstTryCorrect` answers right on the first
    /// attempt: three from nine on, two from six on.
    ///
    /// Every round earns at least one star. Fewer than six correct answers —
    /// including a nonsensical negative count — therefore yields one star.
    public static func stars(firstTryCorrect: Int) -> Int {
        switch firstTryCorrect {
        case firstTryCorrectForThreeStars...: 3
        case firstTryCorrectForTwoStars...: 2
        default: 1
        }
    }
}
