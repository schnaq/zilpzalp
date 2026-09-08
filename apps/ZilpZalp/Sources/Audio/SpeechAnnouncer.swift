import AVFoundation
import Foundation
import os
import ZilpZalpData

/// Speaks the question of game 1 — "Wo ist die Amsel?" — on the device.
///
/// `AVSpeechSynthesizer` needs no audio asset, so there is no licence to clear
/// and no network to wait for. The question is not switchable off: it *is* the
/// task in game 1, and a child who cannot read has nothing else to go by.
/// Neither are the recorded calls of game 2 — nothing this app makes audible
/// is a setting any more (#138).
@MainActor
final class SpeechAnnouncer: NSObject {
    /// A notch below the system default of 0.5. The default rattles the
    /// question off faster than a child who is still learning the names can
    /// follow it, and a compact voice is the one that rattles hardest: it
    /// clips the pauses between words as it speeds up.
    private static let compactRate = AVSpeechUtteranceDefaultSpeechRate * 0.9

    /// Barely slower than the system default, for a downloaded voice.
    ///
    /// An enhanced or premium voice already stretches its own vowels and holds
    /// its own pauses, so the same 0.9 that saves a compact voice makes this
    /// one drag. Half the correction is enough.
    ///
    /// Judgement, not measurement: the simulator has compact voices only, so
    /// this could not be listened to here. It is the value Christian should
    /// turn first if a downloaded voice still reads too fast or too slowly on
    /// his device (#151).
    private static let downloadedRate = AVSpeechUtteranceDefaultSpeechRate * 0.95

    private let synthesizer = AVSpeechSynthesizer()

    /// The voice for every utterance — see ``SpeechVoice``. `nil` when the
    /// device carries no German voice at all. The utterance then keeps
    /// `voice == nil` and the system reads it with its default voice — a wrong
    /// accent is still better than silence.
    private let voice: AVSpeechSynthesisVoice?

    /// The rate that suits ``voice``. Stored rather than recomputed per
    /// sentence: the voice cannot change while the app runs.
    private let speechRate: Float

    /// The utterance currently on its way to the speaker.
    ///
    /// Held as the object and not merely as its `ObjectIdentifier` so that the
    /// replacement in `announce(_:)` is allocated while this one is still
    /// alive. Two live objects cannot share an address, so the identity check
    /// in `utteranceEnded(_:)` cannot mistake the outgoing utterance for the
    /// incoming one.
    ///
    /// `AVSpeechSynthesizer.isSpeaking` is no substitute for it: measured with
    /// the pinned toolchain the synthesiser's flag stays `false` for about ten
    /// milliseconds after `speak(_:)` — even inside
    /// `speechSynthesizer(_:didStart:)` — so anything derived from it would be
    /// blind at exactly the start of a sentence.
    private var spokenUtterance: AVSpeechUtterance?

    override init() {
        voice = SpeechVoice.forUtterance
        // `.default` covers both the compact voice and the case where there
        // was no voice to look at: today's rate is what the app has always
        // used, and nothing about an unknown voice argues for changing it.
        speechRate = switch voice?.quality {
        case .enhanced, .premium: Self.downloadedRate
        default: Self.compactRate
        }
        super.init()

        synthesizer.delegate = self
    }

    /// Asks for one bird: "Wo ist die Amsel?"
    ///
    /// Speaks immediately and drops whatever was still running, so tapping the
    /// question again re-reads it instead of queueing a second reading behind
    /// the first.
    func announce(_ bird: Bird) {
        announce(prompt(for: bird))
    }

    /// Says one finished sentence — the praise on the round end, for a child
    /// who cannot read the headline.
    ///
    /// Takes text rather than a key: the String Catalog belongs to the app's
    /// screens, and this type stays the one that only knows how to speak.
    func announce(_ sentence: String) {
        // One sound at a time (#30). A call is what the child asked for by
        // tapping, and in game 2 it is the question itself; a sentence laid
        // over it would leave neither intelligible. Dropped rather than
        // queued — by the time a call has run its course, the screen that
        // wanted to say something has usually moved on.
        guard AudioFocus.call?.isPlaying != true else {
            Logger.audio.debug("Staying silent, a call is playing")
            return
        }

        AudioSessionConfigurator.activatePlayback()

        let utterance = AVSpeechUtterance(string: sentence)
        utterance.voice = voice
        utterance.rate = speechRate

        _ = synthesizer.stopSpeaking(at: .immediate)
        spokenUtterance = utterance
        AudioFocus.speech = self
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
