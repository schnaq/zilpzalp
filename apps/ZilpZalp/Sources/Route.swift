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
    /// until then its tile leads to the same placeholder as game 1.
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

/// Everywhere the shell can go.
///
/// Home is the stack's root and therefore not a case. The round end (#26) is
/// pushed by the quiz screen and joins this enum with that issue.
enum Route: Hashable {
    case quiz(Game)
    case parents
}
