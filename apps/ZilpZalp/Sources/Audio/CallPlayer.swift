import AVFoundation
import Foundation
import os

/// Plays a bird's recorded call — the sound game 2 (#31) asks its question
/// with, and the one thing in the app that comes off disk rather than out of
/// the speech synthesiser.
///
/// `AVAudioPlayer` and nothing above it: a call is a few seconds of local AAC
/// whose hash was checked when the pack was installed, so there is no stream to
/// buffer, no queue to keep and no rate to control. `AVAudioEngine` would buy
/// none of that back.
///
/// A tap while a call runs is a legitimate "again" — spec §4 wants a call to be
/// repeatable as often as a child likes — so ``play(_:)`` starts the recording
/// over instead of refusing the tap or layering a second voice on top.
///
/// ```swift
/// SoundButton(isPlaying: player.isPlaying, label: "Ruf noch einmal hören") {
///     if let call = library.callURL(for: bird) { player.play(call) }
/// }
/// ```
@MainActor
@Observable
final class CallPlayer: NSObject {
    /// The call on its way to the speaker, `nil` while this player is silent.
    ///
    /// Not observed itself — a view reads ``isPlaying``, and the recording is
    /// bookkeeping — but it is the one fact this type keeps: setting it is what
    /// moves ``isPlaying``, so no path through here can leave the two of them
    /// disagreeing.
    @ObservationIgnored private var player: AVAudioPlayer? {
        didSet { isPlaying = player != nil }
    }

    /// Whether a call is audible right now — what `SoundButton` draws its
    /// rings from.
    ///
    /// One case leaves this standing at `true` with nothing to hear: an
    /// interruption. A phone call pauses `AVAudioPlayer` without ever
    /// delivering a finish, and this app deliberately observes no interruption
    /// notifications (see ``AudioSessionConfigurator``). The next tap sets it
    /// right, which is the same tap the child would make anyway.
    private(set) var isPlaying = false

    /// Plays `url` from the beginning.
    ///
    /// Whatever is being spoken stops as this starts, and nothing is spoken
    /// until the call is over — see ``AudioFocus``.
    ///
    /// Failures are logged and never shown: a file that went missing between
    /// the pack check and the tap, or a recording the decoder refuses. A child
    /// who taps and hears nothing has a dull moment; a child who is handed an
    /// error message has a broken app, and cannot read it either.
    func play(_ url: URL) {
        // Silenced, but deliberately not released yet: the replacement has to
        // be allocated while this one is still alive. Two live objects cannot
        // share an address, so the identity check in ``callEnded(_:successfully:)``
        // cannot mistake a finish meant for the outgoing recording for the
        // incoming one — the trap ``SpeechAnnouncer`` guards against the same
        // way for its utterances.
        player?.stop()

        let recording: AVAudioPlayer
        do {
            recording = try AVAudioPlayer(contentsOf: url)
        } catch {
            let reason = error.localizedDescription
            Logger.audio.error(
                "Call \(url.lastPathComponent, privacy: .public) unreadable: \(reason, privacy: .public)",
            )
            player = nil
            return
        }
        recording.delegate = self

        // Before every single sound, exactly as the speech does — but only
        // once there is a sound to make: activating the session interrupts
        // whatever the grown-ups were listening to, and a file that is not
        // there has not earned that. The category, mode and options stay
        // untouched on purpose: `.playback` against `.duckOthers` is open
        // decision 6 in the spec, waiting for a human, and a call player that
        // quietly asked for ducking here would have decided it.
        AudioSessionConfigurator.activatePlayback()
        guard recording.play() else {
            Logger.audio.error(
                "Call \(url.lastPathComponent, privacy: .public) did not start",
            )
            player = nil
            return
        }

        // Only now, with the recording actually going: a call that never
        // started has no business silencing the sentence it was going to
        // replace. One main-actor tick separates the two, so nobody hears an
        // overlap.
        AudioFocus.speech?.stop()
        player = recording
        AudioFocus.call = self
    }

    /// Stops the call. Playing again is a fresh ``play(_:)``, from the top.
    func stop() {
        player?.stop()
        player = nil
    }

    /// Clears the flag only for the recording that is actually current.
    ///
    /// A finish delivered while ``play(_:)`` has already handed the next
    /// recording over must not switch that one off — the same trap
    /// ``SpeechAnnouncer`` documents for cancelled utterances.
    private func callEnded(_ ended: ObjectIdentifier, successfully: Bool) {
        guard let player, ObjectIdentifier(player) == ended else { return }

        if !successfully {
            Logger.audio.error("Call stopped: the recording could not be decoded")
        }
        self.player = nil
    }
}

/// The protocol is not main-actor annotated, so the callback stays `nonisolated`
/// and hops to the main actor itself. `AVAudioPlayer` is not `Sendable`; only
/// its identity crosses.
extension CallPlayer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool,
    ) {
        let ended = ObjectIdentifier(player)
        Task { @MainActor in self.callEnded(ended, successfully: flag) }
    }
}
