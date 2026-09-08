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

/// What one finished round earned, and everything ``ProfileStore`` needs to
/// book it onto the child who played it.
///
/// An app-target value: it is the seam between the quiz and the round end,
/// and neither of those lives in a package. `PlayedRound` in `ZilpZalpData`
/// is the shape the store keeps — deliberately a different type, because it
/// carries what a profile remembers rather than what a round produced, and
/// ``AppModel/record(_:)`` is the one place that translates between them.
struct RoundResult: Hashable {
    /// This round, told apart from the one before it.
    ///
    /// The round end books the round it celebrates, and `onAppear` and
    /// `.task` both run again when the child comes back from the collection.
    /// Identity is what makes "once" true, and it has to come from the round
    /// rather than from the screen: two rounds can earn the same stars with
    /// the same birds in the same seconds, and those are not the same round.
    let id: UUID

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

    /// Every species the round asked about, right or wrong.
    ///
    /// All of them go into the album: it is a memory of what the child has
    /// seen, never a record of what it got wrong. The set comes from the
    /// round because only ``QuizSession`` holds the questions.
    let species: Set<String>

    /// Seconds from the first question going up to the last answer.
    ///
    /// Wall clock, which is what the daily budget (#36) counts and what a
    /// parent means by "played for twenty minutes". A round is over the
    /// moment the screen is left, so there is no pause to subtract.
    let playtime: TimeInterval

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
    /// The sticker album (#29), from the round end and from the home screen.
    case collection
    /// "Deine Vogel-Leiter" (#29), from the album and from the ascent.
    case ladder
    /// "Du bist jetzt eine Amsel!" (#29), pushed by the round end once the
    /// round it just booked has carried the child over a threshold.
    case rankAscent(RankAscent)
}

/// A rank the child has just reached, and where it sits on the ladder.
///
/// A value rather than a look-up on arrival: the screen celebrates the step
/// that was taken, and by the time it is drawn the profile has already been
/// written, so asking the store again could only ever answer with the state
/// after some *other* round.
struct RankAscent: Hashable {
    /// The rank held before the round. The mini ladder starts here.
    let from: Rank
    /// The rank reached. Everything on the screen is about this one.
    let reached: Rank
    /// The star count the round left behind, for "Noch 33 Sterne bis zur
    /// Blaumeise". Kept rather than derived so the bar and the sentence
    /// cannot disagree with the rank beside them.
    let stars: Int
}
