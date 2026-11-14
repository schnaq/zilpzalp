import ZilpZalpData

/// What the feedback sheet needs from a round: the moment on screen as a
/// report describes it, and a way back into play that stays quiet.
extension QuizSession {
    /// The question on screen as a feedback report describes it, `nil` once
    /// the round is over. Frozen at the screenshot, so the report shows what
    /// the grown-up saw even if the child answers before the hint is tapped.
    func feedbackSnapshot(app: String, system: String, device: String) -> FeedbackSnapshot? {
        guard !isFinished else { return nil }
        return FeedbackSnapshot(
            game: game.rawValue,
            difficulty: difficulty.rawValue,
            question: index + 1,
            questionCount: round.questions.count,
            tiles: choices.map { photos.feedbackTile(for: $0, question: index) },
            answer: answer?.id,
            call: game == .calls ? answer?.call : nil,
            app: app,
            system: system,
            device: device,
        )
    }

    /// Picks the round up after the feedback sheet closes.
    ///
    /// Not a plain ``resume()``: that asks an open question again, and the
    /// design says speech and calls do not replay once a grown-up has
    /// reported a tile. Only a question the child answered meanwhile goes
    /// through it, because there ``resume()`` finishes the move to the next
    /// question — asked as usual — instead of repeating this one, so the round
    /// never hangs on a check mark. An open question simply waits for the
    /// sound button or a tap.
    func carryOn() {
        if isAnswered {
            resume()
        }
    }
}
