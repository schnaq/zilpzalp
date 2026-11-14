/// What the app says to a right answer, and the banner shows: one of four,
/// never the same one twice running.
struct Praise {
    private static let keys = [
        "quiz.feedback.correct",
        "quiz.feedback.correct.right",
        "quiz.feedback.correct.excellent",
        "quiz.feedback.correct.great",
    ]

    /// The latest, a catalog key. Starts at random: the first ``next()`` skips
    /// it, and a fixed start would keep that one from ever coming first.
    private(set) var key = keys.randomElement() ?? keys[0]

    mutating func next() {
        key = Self.keys.filter { $0 != key }.randomElement() ?? key
    }
}
