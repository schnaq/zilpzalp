import Foundation
import ZilpZalpCore

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
///
/// An app-target value for as long as nothing outlives the round. The moment
/// `ProfileStore` (#27) wants to write one down it belongs in a package, and
/// this is the type that moves.
struct RoundResult: Hashable {
    /// Answers right at the first attempt — the one number a round produces.
    let firstTryCorrect: Int
    /// How many questions the round had, so the end screen never has to assume
    /// the round length.
    let questionCount: Int

    /// The species the round end puts on its sticker: the first one answered
    /// right at the first attempt, or the round's first question when there
    /// was none. `nil` only for a round without questions.
    ///
    /// Chosen where the round is played rather than where it is celebrated,
    /// because only ``QuizSession`` knows which answers were first tries — and
    /// a round hands over one value, not two. A round always earns a sticker,
    /// which is why the fallback is a species and not nothing: the celebration
    /// shows what was met, never how well it went.
    let celebratedSpecies: String?

    /// One, two or three. Derived rather than stored: `Scoring` is a pure
    /// function of ``firstTryCorrect``, and a second field holding the answer
    /// could only ever disagree with it.
    var stars: Int {
        Scoring.stars(firstTryCorrect: firstTryCorrect)
    }
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
