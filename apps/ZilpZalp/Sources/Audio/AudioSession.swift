import AVFoundation
import os

extension Logger {
    /// Everything that makes a sound logs here — the spoken question (#24) and
    /// the recorded calls (#30).
    static let audio = Logger(subsystem: "com.schnaq.zilpzalp", category: "audio")
}

/// The single audio-session setup for the whole app.
///
/// Category `.playback` is what keeps the app audible while the mute switch is
/// flipped. Children flip it, and a game 1 that says nothing is unusable for
/// someone who cannot read the question. The spoken question (#24) and the
/// recorded calls (#30) share this configuration.
enum AudioSessionConfigurator {
    /// Configures and activates the shared session. Meant to be called before
    /// every single sound, not once at launch.
    ///
    /// Deliberately not latched behind an "already done" flag. iOS deactivates
    /// the session when a phone call, an alarm or Siri interrupts, and nothing
    /// hands that fact back to us; asking for the category and activation again
    /// before each utterance is what brings the question back afterwards.
    /// `AVSpeechSynthesizer` speaks through this shared session — it does not
    /// keep one of its own — so a session that stays deactivated means a silent
    /// game 1. Repeating both calls on an already-configured session is cheap
    /// next to the speech that follows.
    ///
    /// Called when a sound actually starts rather than at launch: an app that
    /// has not made a sound yet has no business interrupting whatever the
    /// parents are listening to.
    static func activatePlayback() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
        } catch {
            // Audio still plays, it just loses against the mute switch. Not
            // reaching the child at all would be the worse outcome, so this
            // is logged and not surfaced.
            let reason = error.localizedDescription
            Logger.audio.error("Audio session setup failed: \(reason, privacy: .public)")
        }
    }
}
