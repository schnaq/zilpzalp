import AVFoundation
import os
import ZilpZalpCore

/// The voice the app speaks with, chosen once per launch.
///
/// The choosing itself is ``SpeechVoiceChoice`` in `ZilpZalpCore`, where it
/// can be tested; this is the bridge to AVFoundation and nothing else. The two
/// halves meet over ``SpeechVoiceDescription``, so the grown-ups' area can name
/// the voice without importing AVFoundation.
///
/// Once per launch, not per ``SpeechAnnouncer``: half a dozen screens build an
/// announcer of their own, and enumerating the device's voice catalogue six
/// times to reach the same answer would also print the log line six times. The
/// cost is that a grown-up who downloads a voice while the app is running
/// still sees the old one — the catalogue does post
/// `AVSpeechSynthesizer.availableVoicesDidChangeNotification`, but reacting to
/// it means re-choosing mid-sentence, and a relaunch is what the hint in the
/// grown-ups' area asks for anyway (#151).
enum SpeechVoice {
    /// The German voice this launch settled on, or `nil` when the device
    /// carries none. Read by the grown-ups' area to name it.
    static let chosen: SpeechVoiceDescription? = SpeechVoiceChoice.best(from: installed())

    /// What every utterance is given. `nil` only when the device has no German
    /// voice at all and no default one either; the utterance then keeps
    /// `voice == nil` and the system reads it with whatever it has — a wrong
    /// accent is still better than silence.
    ///
    /// Resolving this is what writes the log line, so it happens exactly once,
    /// the first time the app speaks.
    static let forUtterance: AVSpeechSynthesisVoice? = resolve()

    /// Every voice on the device, in Core's terms.
    private static func installed() -> [SpeechVoiceDescription] {
        AVSpeechSynthesisVoice.speechVoices().map { voice in
            SpeechVoiceDescription(
                identifier: voice.identifier,
                name: voice.name,
                language: voice.language,
                quality: quality(of: voice.quality),
                isNovelty: voice.voiceTraits.contains(.isNoveltyVoice),
                isPersonal: voice.voiceTraits.contains(.isPersonalVoice),
            )
        }
    }

    /// The chosen voice, looked back up by its identifier.
    ///
    /// Falls back to `AVSpeechSynthesisVoice(language:)` — what the app did
    /// before #151 — on both ways this can miss: no German voice on the
    /// device, and a voice that was listed but no longer resolves, which
    /// happens when a download is removed between the two calls.
    private static func resolve() -> AVSpeechSynthesisVoice? {
        guard
            let chosen,
            let voice = AVSpeechSynthesisVoice(identifier: chosen.identifier)
        else {
            Logger.audio.warning(
                "No German voice to choose from, asking the system for \(language, privacy: .public)",
            )
            return AVSpeechSynthesisVoice(language: language)
        }

        // Public on purpose: a voice's name and quality are properties of the
        // device's software, not of the person holding it, and this line is
        // the only way to tell whether a downloaded voice was picked up.
        Logger.audio.info(
            """
            Speaking German with \(voice.name, privacy: .public) \
            (\(voice.identifier, privacy: .public)), \
            quality \(String(describing: chosen.quality), privacy: .public)
            """,
        )
        return voice
    }

    /// AVFoundation's tiers under Core's names. `default` is the compact voice
    /// every device ships with; the enum is an Objective-C one, so the switch
    /// needs a `default` case for tiers that do not exist yet.
    private static func quality(of quality: AVSpeechSynthesisVoiceQuality) -> SpeechVoiceQuality {
        switch quality {
        case .premium: .premium
        case .enhanced: .enhanced
        default: .standard
        }
    }

    /// The language asked for when nothing was chosen.
    private static let language = SpeechVoiceChoice.preferredLanguage
}
