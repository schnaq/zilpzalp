import AVFoundation
import os

private let logger = Logger(subsystem: "com.schnaq.zilpzalp", category: "audio")

/// The single audio-session setup for the whole app.
///
/// Category `.playback` is what keeps the app audible while the mute switch is
/// flipped. Children flip it, and a game 1 that says nothing is unusable for
/// someone who cannot read the question. The spoken question (#24) and the
/// recorded calls (#30) share this configuration.
@MainActor
enum AudioSessionConfigurator {
    private static var isConfigured = false

    /// Configures and activates the shared session.
    ///
    /// Idempotent after the first success, so every place that makes a sound
    /// may call it without coordinating with the others. Called when audio
    /// actually starts rather than at launch: an app that has not made a sound
    /// yet has no business interrupting whatever the parents are listening to.
    static func activatePlayback() {
        guard !isConfigured else { return }

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [])
            try session.setActive(true)
            isConfigured = true
        } catch {
            // Audio still plays, it just loses against the mute switch. Not
            // reaching the child at all would be the worse outcome, so this
            // is logged and not surfaced.
            logger.error("Audio session failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
