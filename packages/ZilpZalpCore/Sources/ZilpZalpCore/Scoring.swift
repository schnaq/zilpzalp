/// Stars a single round earns.
///
/// Only answers that were right on the first attempt count. A question the
/// child gets right on the second try does not count — that is what makes
/// three stars worth playing for.
public enum Scoring {
    /// The most a round can earn. Public because a screen that draws the
    /// stars has to know how many places to leave for the ones not earned —
    /// an unearned star is drawn dim, never left out.
    public static let maximumStars = 3

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
        case firstTryCorrectForThreeStars...: maximumStars
        case firstTryCorrectForTwoStars...: 2
        default: 1
        }
    }
}
