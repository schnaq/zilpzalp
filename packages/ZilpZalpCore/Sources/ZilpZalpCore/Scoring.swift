/// What playing is worth: the stars a single round earns, and how often one
/// bird has to be recognised before its sticker is in the album.
///
/// Only answers that were right on the first attempt count, for either of
/// them. A question the child gets right on the second try does not count —
/// that is what makes three stars worth playing for, and what makes a sticker
/// mean the bird is known.
public enum Scoring {
    /// The most a round can earn. Public because a screen that draws the
    /// stars has to know how many places to leave for the ones not earned —
    /// an unearned star is drawn dim, never left out.
    public static let maximumStars = 3

    /// From this many first-try correct answers on, a round earns three stars.
    private static let firstTryCorrectForThreeStars = 9

    /// From this many first-try correct answers on, a round earns two stars.
    private static let firstTryCorrectForTwoStars = 6

    /// How often one species may have to be answered right at the first
    /// attempt before its sticker belongs in the album: three or five, chosen
    /// per child by a grown-up (#260). Five was the only number until then
    /// (#177), and it is what a profile starts with.
    ///
    /// The choice lives on the profile, and so does the tally — this module
    /// holds the rule, and takes the threshold as an argument wherever it
    /// matters. A bird met once was not learned; a bird known three times
    /// over may be, for a younger child.
    public static let stickerThresholds = [3, 5]

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
