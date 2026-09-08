import AVFoundation
import Foundation
import os
import ZilpZalpData

/// Speaks the question of game 1 — "Wo ist die Amsel?" — on the device.
///
/// `AVSpeechSynthesizer` needs no audio asset, so there is no licence to clear
/// and no network to wait for. The question is not switchable off: it *is* the
/// task in game 1, and a child who cannot read has nothing else to go by. The
/// "Vogelstimmen" setting (#35) only ever concerns the recorded calls.
@MainActor
final class SpeechAnnouncer: NSObject {
    private static let language = "de-DE"

    /// A notch below the system default of 0.5. The default rattles the
    /// question off faster than a child who is still learning the names can
    /// follow it.
    private static let speechRate = AVSpeechUtteranceDefaultSpeechRate * 0.9

    private let synthesizer = AVSpeechSynthesizer()

    /// `nil` when the device carries no German voice at all. The utterance
    /// then keeps `voice == nil` and the system reads it with its default
    /// voice — a wrong accent is still better than silence.
    private let voice: AVSpeechSynthesisVoice?

    /// The utterance currently on its way to the speaker.
    ///
    /// Held as the object and not merely as its `ObjectIdentifier` so that the
    /// replacement in `announce(_:)` is allocated while this one is still
    /// alive. Two live objects cannot share an address, so the identity check
    /// in `utteranceEnded(_:)` cannot mistake the outgoing utterance for the
    /// incoming one.
    private var spokenUtterance: AVSpeechUtterance?

    /// `true` from the moment `announce(_:)` hands an utterance over until it
    /// finishes or is cancelled. Callers that play a bird call check this
    /// first — the child hears one thing at a time (#30).
    ///
    /// `AVSpeechSynthesizer.isSpeaking` cannot do this job: measured with the
    /// pinned toolchain it stays `false` for about ten milliseconds after
    /// `speak(_:)` — even inside `speechSynthesizer(_:didStart:)` — which is
    /// exactly the window in which a caller would start a call on top of the
    /// question.
    var isSpeaking: Bool {
        spokenUtterance != nil
    }

    override init() {
        voice = AVSpeechSynthesisVoice(language: Self.language)
        super.init()

        if voice == nil {
            Logger.audio.warning("No \(Self.language, privacy: .public) voice, using the default")
        }
        synthesizer.delegate = self
    }

    /// Asks for one bird: "Wo ist die Amsel?"
    ///
    /// Speaks immediately and drops whatever was still running, so tapping the
    /// question again re-reads it instead of queueing a second reading behind
    /// the first.
    func announce(_ bird: Bird) {
        say(prompt(for: bird))
    }

    /// Reads one finished German sentence out loud.
    ///
    /// The screens that ask a child a question in words — "Wer spielt heute?",
    /// "Wie heißt du?" (#28) — need the same voice the game speaks in, so the
    /// text comes in already resolved from the String Catalog rather than each
    /// screen growing its own way of talking.
    ///
    /// This makes the *class* the one voice, not the instance: a screen holds
    /// its own announcer, and two screens that were somehow on stage at once
    /// could still speak over each other. Nothing in the app does that today —
    /// each screen replaces the last — and the cut-off below covers the
    /// handover.
    ///
    /// Cuts off whatever was still being said, exactly as ``announce(_:)``
    /// does, and sets ``isSpeaking`` for as long as it runs.
    func say(_ text: String) {
        AudioSessionConfigurator.activatePlayback()

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = voice
        utterance.rate = Self.speechRate

        _ = synthesizer.stopSpeaking(at: .immediate)
        spokenUtterance = utterance
        synthesizer.speak(utterance)
    }

    /// Stops the question. Speaking again is a fresh `announce(_:)`.
    func stop() {
        _ = synthesizer.stopSpeaking(at: .immediate)
        spokenUtterance = nil
    }

    /// Article and name are positional arguments so that a translation may
    /// reorder them. Where the voice mangles a name, `pronunciation` from the
    /// manifest overrides it — that fix belongs in the pack data, never here.
    private func prompt(for bird: Bird) -> String {
        String(
            format: String(localized: "quiz.prompt.whereIs"),
            bird.article,
            bird.pronunciation ?? bird.name,
        )
    }

    /// Clears the flag only for the utterance that is actually current. A
    /// `didCancel` caused by `announce(_:)` arrives after the next utterance
    /// has already been handed over, and must not clear that one.
    private func utteranceEnded(_ ended: ObjectIdentifier) {
        guard let spokenUtterance, ObjectIdentifier(spokenUtterance) == ended else { return }
        self.spokenUtterance = nil
    }
}

/// The protocol is not main-actor annotated, so the callbacks stay `nonisolated`
/// and hop to the main actor themselves. `AVSpeechUtterance` is not `Sendable`;
/// only its identity crosses.
extension SpeechAnnouncer: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(
        _: AVSpeechSynthesizer,
        didFinish utterance: AVSpeechUtterance,
    ) {
        let ended = ObjectIdentifier(utterance)
        Task { @MainActor in self.utteranceEnded(ended) }
    }

    nonisolated func speechSynthesizer(
        _: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance,
    ) {
        let ended = ObjectIdentifier(utterance)
        Task { @MainActor in self.utteranceEnded(ended) }
    }
}
