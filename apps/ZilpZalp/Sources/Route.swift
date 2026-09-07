import Foundation

/// The two games of v1.
///
/// Game 3 (feathers) and game 4 (habitat) are not cases: they are out of v1 for
/// want of freely licensed material (spec §1), so nothing can route to them and
/// nothing announces them — see ``HomeScreen``.
enum Game: Hashable {
    /// Game 1: the name is read out, the child taps the bird (#25).
    case names
    /// Game 2: the call plays, the child taps the bird. Playable in M5 (#30);
    /// until then its round is played as game 1 — same questions, same tiles,
    /// the spoken name standing in for the call that is not there yet.
    case calls

    /// The word under the glyph on the home screen, and the name of the
    /// screen the tile opens.
    var title: String {
        switch self {
        case .names: String(localized: "home.game.names.title")
        case .calls: String(localized: "home.game.calls.title")
        }
    }
}

/// What one finished round earned.
///
/// The whole of it: no profile, no history, nothing stored. M3 shows the stars
/// of the round just played and forgets them — `ProfileStore` (#27) is what
/// makes them add up, and a throwaway persistence in the meantime would be a
/// promise to a four-year-old that the next launch breaks.
struct RoundResult: Hashable {
    /// One, two or three, from `Scoring.stars(firstTryCorrect:)`.
    let stars: Int
    /// Answers right at the first attempt — what the stars are derived from.
    let firstTryCorrect: Int
    /// How many questions the round had, so the end screen never has to assume
    /// the round length.
    let questionCount: Int
}

/// Everywhere the shell can go.
///
/// Home is the stack's root and therefore not a case.
enum Route: Hashable {
    case quiz(Game)
    /// Pushed by ``QuizScreen`` once the last question is answered. #26 builds
    /// the screen behind it; the payload is settled here so that both sides of
    /// that seam agree before either is written.
    case roundEnd(RoundResult)
    case parents
}
