import SwiftUI
import ZilpZalpCore
import ZilpZalpData

/// One level as the home screen draws it: which level it is, what it is
/// called, the picture that stands for it, how many binoculars it wears and
/// what the app says when a child taps it.
///
/// The view's half of ``ZilpZalpCore/Difficulty``: the German names and the
/// photo files are the app's business, and `ZilpZalpCore` carries neither.
struct DifficultyLevel: Identifiable {
    let difficulty: Difficulty

    /// The level's quartet — ``ZilpZalpData/Profile/difficultySamples``,
    /// look-alikes first — or the Zilpzalp alone for Klassisch. A `nil` keeps
    /// the cell's bird glyph, which is what a photo that would not open looks
    /// like.
    let photos: [Image?]

    /// What the app says when this level is tapped: its name.
    let spoken: SpokenLine

    var id: Difficulty {
        difficulty
    }

    /// The word under the picture: „Leicht", „Mittel", „Schwer", „Klassisch".
    /// The text the spoken name falls back on, so the word on the screen and
    /// the word said cannot be two different words.
    var title: String {
        spoken.text
    }

    /// How many binoculars stickers the level's tile carries: one per
    /// look-alike a tricky question puts beside the answer. A child who cannot
    /// read can count them, and meets the badge of a tricky question before a
    /// round shows it.
    var lookalikes: Int {
        difficulty.lookalikesPerTrickyQuestion
    }
}

extension DifficultyLevel {
    /// The levels in the order the picker draws them: the ramp from easy to
    /// hard, then Klassisch — which is not a rung, and stands underneath.
    static let order: [Difficulty] = [.easy, .medium, .hard, .classic]

    /// Every level in ``order``, each sample species' photo looked up by
    /// `photo`.
    static func all(photo: (String) -> Image?) -> [DifficultyLevel] {
        order.map { level in
            DifficultyLevel(
                difficulty: level,
                photos: Profile.difficultySamples[level.rawValue, default: []].map(photo),
                spoken: .fixed("home.difficulty.\(level.rawValue)"),
            )
        }
    }

    /// Every level with a glyph in place of each photo — for the previews.
    static var previews: [DifficultyLevel] {
        all { _ in nil }
    }
}

extension AppModel {
    /// How hard the playing child's rounds are.
    ///
    /// A stored level this build does not know — written by a newer one — and
    /// a missing child both play Klassisch, the game as it always was, rather
    /// than guess at something harder.
    var difficulty: Difficulty {
        activeProfile.flatMap { Difficulty(rawValue: $0.difficulty) } ?? .standard
    }

    /// What the level picker offers, in ``DifficultyLevel/order``.
    ///
    /// The photos are each species' portrait from ``PackModel/photos``, the
    /// same cache the album and the collection pill draw from, so the picker
    /// opens no file of its own.
    var difficultyLevels: [DifficultyLevel] {
        DifficultyLevel.all { packs.photos[$0] }
    }
}
