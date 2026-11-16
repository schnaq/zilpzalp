import ZilpZalpCore
import ZilpZalpData

/// What the look-back card needs from a round: the questions already
/// answered, as they stood when they were answered, and a way to ask one of
/// them again. See `docs/superpowers/specs/2026-11-16-look-back-in-round-design.md`.
///
/// Its own file because `QuizSession.swift` is at SwiftLint's length; that is
/// also why the session's pack, recordings and voice are not private.
extension QuizSession {
    /// How many questions of this round are answered; see
    /// ``RoundPlay/answeredCount``. The card pages through exactly these.
    var answeredCount: Int {
        play.answeredCount
    }

    /// The birds `question` offered, in the order the round put them; empty
    /// for a question outside the round.
    func choices(inQuestion question: Int) -> [Bird] {
        self.question(question)?.choices.compactMap { birds[$0] } ?? []
    }

    /// The bird `question` asked for, `nil` outside the round.
    func answer(ofQuestion question: Int) -> Bird? {
        self.question(question).flatMap { birds[$0.answer] }
    }

    private func question(_ index: Int) -> Round.Question? {
        round.questions.indices.contains(index) ? round.questions[index] : nil
    }

    /// Holds the round for the card and says where it opens: the question
    /// being spoken or played stops, and so does the pause after an answer —
    /// the last answer's too, so the round end never opens behind the card.
    /// `nil` once the round is over and the round end is on its way.
    func startLookBack(at question: Int) -> LookBack? {
        guard !isFinished else { return nil }
        suspend()
        return LookBack(question: question)
    }

    /// Asks `question` again from the card, because the sound button was
    /// tapped: game 1 says the name, game 2 plays the call. Never on its own,
    /// never the tricky warning, and it does not start the round's clock.
    func askAgain(question: Int) {
        guard let answer = answer(ofQuestion: question) else { return }
        switch game {
        case .names:
            announcer.announce(.name(answer), unprompted: false)
        case .calls:
            if let call = calls[answer.id] {
                player.play(call)
            }
        }
    }

    /// Picks the round up once the card is closed, as after the feedback
    /// sheet: a call started from the card stops, an open question waits for
    /// a tap, and an answered one finishes its move on.
    func endLookBack() {
        suspend()
        carryOn()
    }
}
