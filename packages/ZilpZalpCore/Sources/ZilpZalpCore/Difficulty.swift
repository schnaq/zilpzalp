/// How alike the four birds of a question may look.
///
/// Klassisch is the game as it always was — distractors from another genus
/// first — and stays the standard: every profile written before levels
/// existed plays it. Leicht keeps look-alikes out altogether; Mittel and
/// Schwer play Klassisch but put look-alikes beside the answer in a few
/// questions, the *tricky* ones. Effective order: Leicht, Klassisch, Mittel,
/// Schwer.
///
/// The raw values are stored in `Profile.difficulty` and must never change.
public enum Difficulty: String, CaseIterable, Sendable {
    case easy
    case medium
    case hard
    case classic

    /// The level of a profile that never chose one.
    public static let standard: Difficulty = .classic

    /// How many questions of a round are dealt tricky, at most — the pool
    /// decides whether there are that many answers with a look-alike.
    var trickyQuestions: Int {
        switch self {
        case .medium: 3
        case .hard: 5
        case .easy, .classic: 0
        }
    }

    /// How many look-alikes stand beside the answer in a tricky question.
    var lookalikesPerTrickyQuestion: Int {
        switch self {
        case .medium: 1
        case .hard: 2
        case .easy, .classic: 0
        }
    }
}
