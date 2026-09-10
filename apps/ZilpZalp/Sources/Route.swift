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
    /// Game 2: the bird's recorded call plays and the child taps the bird
    /// (#31). Nothing is spoken — the name would be the answer — and the sound
    /// button plays the call again. Only species that carry a call are asked
    /// for; the others keep their photos among the choices.
    ///
    /// Offered only where it can be played: four species with a call, see
    /// ``AppModel/games``.
    case calls

    /// The word under the glyph on the home screen, and the name of the
    /// screen the tile opens — which is why game 2's is also the question
    /// written beside its sound button (see ``QuizSession/writtenQuestion``).
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

    /// How many questions the round had, so the end screen never has to assume
    /// the round length.
    let questionCount: Int

    /// The species the round end puts on its sticker; which one that is, and
    /// why a round without a single first try still names one, is
    /// ``RoundPlay/celebratedSpecies(recognisedBefore:)``.
    ///
    /// Settled where the round is played rather than where it is celebrated:
    /// a round hands over one value, not two, and the celebration would
    /// otherwise have to be told how the round went in order to work out what
    /// to show.
    let celebratedSpecies: String?

    /// How often the round recognised each species — answered right at the
    /// first attempt. What the profile's counters are raised by, and five of
    /// them earn that bird's sticker (#177).
    ///
    /// A bird the round only asked about is not in here. The album says what
    /// a child knows, not what it has been shown.
    let recognitions: [String: Int]

    /// Seconds from the first question going up to the last answer.
    ///
    /// Wall clock, which is what the daily budget (#36) counts and what a
    /// parent means by "played for twenty minutes". A round is over the
    /// moment the screen is left, so there is no pause to subtract.
    let playtime: TimeInterval

    /// Answers right at the first attempt: the recognitions added up, since
    /// every one of them is one such answer. Derived rather than carried
    /// beside them, where the two could disagree.
    var firstTryCorrect: Int {
        recognitions.values.reduce(0, +)
    }

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
    /// „Über ZilpZalp" (#199): what the app is, who publishes it, and the
    /// credits. A case of its own and not a room inside ``parents``, because
    /// nothing on it is private — the attribution the photo licences ask for
    /// has to be reachable without a device code.
    case about
    /// The sticker album (#29), from the round end and from the home screen.
    case collection
    /// "Zeit fürs Nest" (#36), screen 1k: where a tapped game tile and
    /// "Nochmal spielen" both lead once the day's budget is spent. Carries no
    /// payload — what it shows is read off the profile when it is drawn, and
    /// a number on the path could only go stale behind it.
    case timeForTheNest
}
