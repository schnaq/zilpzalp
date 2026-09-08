/// Who owns the speaker: the spoken question or a recorded call.
///
/// "Kein Vorlesen und Ruf gleichzeitig" (#30). Neither sound maker can enforce
/// that on its own, because there is no single announcer to route everything
/// through: every screen that reads its headline builds one of its own (see
/// ``ReadAloudOnce``) and ``QuizSession`` builds another. So the two agree on
/// one place rather than on one owner.
///
/// A call wins. It is what the child asked for by tapping, in game 2 it *is*
/// the question, and a sentence cut off can always be asked for again — while
/// a call that refused to start would make the one big button on the screen
/// feel broken.
///
/// Both references are weak, and neither is ever cleared. They mean "the last
/// one that started", which is all the two rules need: stopping an announcer
/// that has finished is a no-op, and a player that is no longer playing says
/// so itself. Clearing them would be bookkeeping that can disagree with the
/// hardware, which is the one thing this file exists to prevent.
///
/// Main-actor isolated, like both its users, so the shared state needs no lock.
@MainActor
enum AudioFocus {
    /// The announcer that last began a sentence. A starting call stops it.
    weak static var speech: SpeechAnnouncer?

    /// The player that last began a call. Nothing is spoken while this one
    /// reports that it is still playing.
    weak static var call: CallPlayer?
}
