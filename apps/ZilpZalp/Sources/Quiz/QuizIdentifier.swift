/// The names the screenshot run finds a question and its answers by.
///
/// Identifiers, never labels. A label is what VoiceOver reads out, and the one
/// thing a child playing either game must not be told is which photo the
/// question is about — ``ChoiceTile`` says so in as many words, and its label
/// is a position for exactly that reason. An identifier is neither drawn nor
/// spoken; it only lets `ZilpZalpScreenshots` answer ten questions correctly
/// instead of tapping around until a round happens to earn three stars.
///
/// Written by ``QuizScreen`` and read by `ZilpZalpScreenshots`. A UI test
/// target links nothing of the app, but this file imports nothing either, so
/// `project.yml` compiles it into both rather than have the run spell the two
/// prefixes a second time — a rename here is then a compile error there.
enum QuizIdentifier {
    /// The question in writing, carrying the species it asks for — empty once
    /// the round is over and there is nothing left to ask.
    static func question(_ species: String?) -> String {
        "quiz.question.\(species ?? "")"
    }

    /// One answer, carrying the species whose photo it shows.
    static func tile(_ species: String) -> String {
        "quiz.tile.\(species)"
    }
}
