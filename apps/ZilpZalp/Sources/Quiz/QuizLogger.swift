import os

extension Logger {
    /// Playing a round.
    ///
    /// The third copy of the bundle identifier in this target, after
    /// `Logger.packs` and `Logger.audio`. `AppModel.swift` asks the third one
    /// to pull all three into a single constant; that means editing `Audio/`,
    /// which this pull request has no other business in, so it is left as a
    /// follow-up rather than smuggled in here.
    static let quiz = Logger(subsystem: "com.schnaq.zilpzalp", category: "quiz")
}
