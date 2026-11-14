import AVFoundation
import Foundation
import os
import ZilpZalpData

/// Everything the app says out loud — the question of game 1, the praise at the
/// end of a round, the headline of a screen a child cannot read.
///
/// A recorded clip first, the synthesiser behind it (#165). A clip is a person
/// speaking German; `AVSpeechSynthesizer` is what the device can do with no
/// asset at all, and the decision of 2026-09-08 was that the second one is a
/// fallback rather than the product. Which of the two spoke is nothing a caller
/// can see: it hands over a ``SpokenLine`` and the sentence is said.
///
/// The fallback is per sentence and silent. A pack whose speech was never
/// recorded, a species added between two releases, a download that has not
/// finished — all of them speak, because a child who cannot read and hears
/// nothing has no task at all.
///
/// When the app speaks is one choice in the grown-ups' area (#306), and
/// ``mode`` is where every announcer reads it: a line the app says on its own
/// is said only in ``ZilpZalpData/SpeechMode/automatic``, a line a child tapped
/// for always. The recorded calls are not speech: where there are calls, game
/// 2 is there, and its question is one of them (#138).
@MainActor
final class SpeechAnnouncer: NSObject {
    /// When the app speaks — ``ZilpZalpData/ParentalSettings/speechMode``,
    /// mirrored here.
    ///
    /// A static, and mirrored rather than read from the settings, for the
    /// reason ``AudioFocus`` is one: half a dozen screens build an announcer
    /// of their own, several of them far from anything that has ever heard of
    /// the grown-ups' area — ``ReadAloudButton`` beside a headline,
    /// ``QuizSession`` inside a round. Threading the settings through all of
    /// them would be six parameters to carry one value.
    ///
    /// ``ParentalSettingsModel`` sets it: once when the file is read at
    /// launch, and again on every change, which is what makes the choice
    /// apply without a restart. Read per ``announce(_:unprompted:)``, so the
    /// lines already on their way — the round end's praise and name — finish.
    ///
    /// Until that first read it stands where the settings stand — taken from
    /// the defaults rather than written out, so the two cannot say different
    /// things about a device that has never been to the grown-ups' area.
    static var mode = ParentalSettings().speechMode

    /// The breath between two lines said one after the other — „Super
    /// gemacht!", then „Amsel" (#264). The clips are trimmed to the voice, so
    /// without it the name would run straight into the praise. Judgement, not
    /// measurement: the knob to turn by ear.
    private static let pauseBetweenLines = Duration.milliseconds(300)

    /// The sentences that belong to no pack, opened once per launch.
    ///
    /// Once, not per announcer, for the reason ``SpeechVoice`` chooses the
    /// voice once: half a dozen screens build an announcer of their own, and
    /// decoding the same manifest six times would reach the same answer six
    /// times. `nil` only when the bundled document is missing, which
    /// `mise run check` already guards through `tools/sync_bundled_packs.py`.
    private static let fixedSet: SpeechCatalog? = {
        do {
            return try SpeechCatalog.bundled()
        } catch {
            let reason = String(describing: error)
            Logger.audio.error("Fixed sentences did not open: \(reason, privacy: .public)")
            return nil
        }
    }()

    private let synthesizer = AVSpeechSynthesizer()

    /// Where a line's recording is looked for. See ``SpeechClips``.
    private let clips: SpeechClips

    /// The voice for every utterance — see ``SpeechVoice``. `nil` when the
    /// device carries no German voice at all. The utterance then keeps
    /// `voice == nil` and the system reads it with its default voice — a wrong
    /// accent is still better than silence.
    private let voice: AVSpeechSynthesisVoice?

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

    /// The clip currently on its way to the speaker, `nil` while the
    /// synthesiser is speaking or nothing is. Kept for the same reason and
    /// with the same identity check as ``spokenUtterance``, which is also how
    /// ``CallPlayer`` holds its recording.
    private var spokenClip: AVAudioPlayer?

    /// The lines still to come after the one now sounding, said in order once
    /// it has run its course. Empty but for the round end's praise for a
    /// first find and „Zeit fürs Nest", which says three lines in a row.
    private var queuedLines: [SpokenLine] = []

    /// What comes a breath after the last line — see ``whenDone(_:)``.
    private var afterwards: (() -> Void)?

    /// The pause before the next queued line, cancelled with the queue.
    private var pause: Task<Void, Never>?

    /// - Parameter library: The packs whose species sentences this announcer
    ///   may play. Empty on the screens that say nothing about a species —
    ///   the picker, the gate, "Zeit fürs Nest" — which is why it defaults to
    ///   nothing. The creation screen does name one, since its avatars became
    ///   birds (#205), and hands its packs over.
    init(library: PackLibrary = .empty) {
        clips = SpeechClips(library: library, fixed: Self.fixedSet)
        voice = SpeechVoice.forUtterance
        super.init()

        synthesizer.delegate = self
    }

    /// Says one line — as it was recorded, or as the synthesiser reads it.
    ///
    /// Speaks immediately and drops whatever was still running, so tapping the
    /// question again re-reads it instead of queueing a second reading behind
    /// the first.
    ///
    /// - Parameter unprompted: `true` for a line the app says on its own — a
    ///   headline on arrival, a new question, the praise — which ``mode``
    ///   may keep quiet. A line a child tapped for is always said. No
    ///   default: every caller says which of the two it is.
    func announce(_ line: SpokenLine, unprompted: Bool) {
        announce([line], unprompted: unprompted)
    }

    /// Says several lines one after the other with a short pause between
    /// them — the round end's „Super gemacht!" and the bird's name (#264).
    ///
    /// Each line is decided as it starts, recorded or synthesised on its own,
    /// so the switch and a call that began in the pause reach the second line
    /// too. A line that stays silent, or is cut off rather than finished,
    /// drops the rest: whoever cut it off wanted the speaker.
    ///
    /// The queue is filled in ``sayInTurn(_:)`` alone, and only once the first
    /// line has actually started; ``stop()`` is the one other place that empties it.
    func announce(_ lines: [SpokenLine], unprompted: Bool) {
        // A line that is not to be said still ends this announcer's last one:
        // the next question must not arrive under the name of the one before,
        // which a child may have tapped for a moment ago.
        guard Self.mode.speaks(unprompted: unprompted) else {
            Logger.audio.debug("Staying silent until a speaker is tapped")
            stop()
            return
        }
        afterwards = nil
        sayInTurn(lines)
    }

    /// Nothing of this announcer's is sounding, nor waiting in a pause.
    var isQuiet: Bool {
        spokenClip == nil && spokenUtterance == nil && pause == nil
    }

    /// Runs `next` a breath after everything this announcer is saying, at once
    /// when it is quiet — the next question after the praise. Dropped with the
    /// queue when the lines are cut off: whoever did that wanted the speaker.
    func whenDone(_ next: @escaping () -> Void) {
        if isQuiet {
            next()
        } else {
            afterwards = next
        }
    }

    /// The queue's way on: ``announce(_:unprompted:)`` without the switch, and
    /// leaving ``afterwards`` standing.
    private func sayInTurn(_ lines: [SpokenLine]) {
        pause?.cancel()
        pause = nil
        queuedLines = []
        guard let line = lines.first, say(line) else { return }
        queuedLines = Array(lines.dropFirst())
    }

    /// Says one line, and whether anything started to sound.
    private func say(_ line: SpokenLine) -> Bool {
        // One sound at a time (#30). A call is what the child asked for by
        // tapping, and in game 2 it is the question itself; a sentence laid
        // over it would leave neither intelligible. Dropped rather than
        // queued — by the time a call has run its course, the screen that
        // wanted to say something has usually moved on.
        guard AudioFocus.call?.isPlaying != true else {
            Logger.audio.debug("Staying silent, a call is playing")
            return false
        }

        // Recording or synthesiser — decided in `ZilpZalpData`, where it can
        // be asserted without a simulator.
        let decision = clips.decision(for: line.key, about: line.bird, pack: line.pack)

        // One sentence at a time across announcers, not only inside one.
        // Every screen builds its own (see ``ReadAloudButton``), and the quiz
        // screen now has two of them at once: the round's, and the one the
        // question about leaving is said with (#146). Stopping only this
        // announcer would let the next question start under a sentence that
        // is still being said.
        //
        // A different one, never this one: this announcer's own hand-over is
        // the two lines below, and stopping it here would only clear what it
        // is about to set again.
        if let other = AudioFocus.speech, other !== self {
            other.stop()
        }

        // Silenced, but deliberately not released yet: the replacement has to
        // be allocated while this one is still alive, so that a finish meant
        // for the outgoing sound cannot switch off the incoming one.
        _ = synthesizer.stopSpeaking(at: .immediate)
        spokenClip?.stop()
        AudioFocus.speech = self

        // Which of the two voices a sentence reached, in one line either way.
        // Public: a sentence key and a file name are properties of the build,
        // not of the child holding the iPad.
        //
        // A clip that will not open or will not start is the one branch the
        // decision cannot make, because the file is opened here: it falls
        // through to the synthesiser, silently and per sentence.
        if case let .clip(clip) = decision, play(clip) {
            // The counterpart of `spokenClip = nil` in `speak(_:)`: a finish
            // still on its way for the utterance this replaced must not pass
            // for this line's and start the next one under it.
            spokenUtterance = nil
            let key = line.key ?? ""
            let file = clip.lastPathComponent
            Logger.audio.debug("Said \(key, privacy: .public) from \(file, privacy: .public)")
            return true
        }

        Logger.audio.debug(
            "No clip for \(line.key ?? "an assembled sentence", privacy: .public), speaking it",
        )
        speak(line.text)
        return true
    }

    /// Stops the sentence, whichever of the two was saying it. Speaking again
    /// is a fresh ``announce(_:)``.
    func stop() {
        queuedLines = []
        afterwards = nil
        pause?.cancel()
        pause = nil
        _ = synthesizer.stopSpeaking(at: .immediate)
        spokenUtterance = nil
        spokenClip?.stop()
        spokenClip = nil
    }

    /// Plays the recording of a sentence.
    ///
    /// - Returns: `false` when the clip could not be opened or would not
    ///   start, which sends the sentence to the synthesiser instead. A file
    ///   that went missing between the pack check and the tap, or a recording
    ///   the decoder refuses, must not cost a child the question — and nothing
    ///   in the UI mentions either.
    private func play(_ clip: URL) -> Bool {
        let recording: AVAudioPlayer
        do {
            recording = try AVAudioPlayer(contentsOf: clip)
        } catch {
            let reason = error.localizedDescription
            Logger.audio.error(
                "Clip \(clip.lastPathComponent, privacy: .public) unreadable: \(reason, privacy: .public)",
            )
            return false
        }
        recording.delegate = self

        // Only once there is a sound to make, exactly as ``CallPlayer`` does
        // it: activating the session interrupts whatever the grown-ups were
        // listening to, and a file that is not there has not earned that.
        AudioSessionConfigurator.activatePlayback()
        guard recording.play() else {
            Logger.audio.error("Clip \(clip.lastPathComponent, privacy: .public) did not start")
            return false
        }

        spokenClip = recording
        return true
    }

    /// Reads a sentence out with the device's own voice — the fallback for
    /// every line no clip says.
    private func speak(_ sentence: String) {
        AudioSessionConfigurator.activatePlayback()

        let utterance = AVSpeechUtterance(string: sentence)
        utterance.voice = voice
        utterance.rate = SpeechVoice.rate

        // Nothing came off disk, so nothing is left to stop: the player set
        // aside above may go now.
        spokenClip = nil
        spokenUtterance = utterance
        synthesizer.speak(utterance)
    }

    /// Clears the flag only for the utterance that is actually current. A
    /// `didCancel` caused by `announce(_:)` arrives after the next utterance
    /// has already been handed over, and must not clear that one.
    ///
    /// Only a finished utterance goes on to the next queued line: a cancelled
    /// one was cut off by whoever took the speaker.
    private func utteranceEnded(_ ended: ObjectIdentifier, finished: Bool) {
        guard let spokenUtterance, ObjectIdentifier(spokenUtterance) == ended else { return }
        self.spokenUtterance = nil
        if finished {
            lineFinished()
        }
    }

    /// Starts the next queued line after ``pauseBetweenLines``, or what
    /// ``whenDone(_:)`` left once the queue is through. Both voices end here,
    /// and only when the line ended on its own — a clip that broke off
    /// undecodable counts, since nobody took the speaker.
    private func lineFinished() {
        guard !queuedLines.isEmpty || afterwards != nil else { return }
        let rest = queuedLines
        pause = Task { [weak self] in
            try? await Task.sleep(for: Self.pauseBetweenLines)
            guard !Task.isCancelled, let self else { return }
            // Already let through: the queue only exists for a line that was.
            guard rest.isEmpty else { return sayInTurn(rest) }
            let next = afterwards
            afterwards = nil
            pause = nil
            next?()
        }
    }

    /// Lets a clip that has run its course go, under the same identity guard
    /// ``CallPlayer`` documents for its recordings: a finish delivered after
    /// ``announce(_:)`` has handed the next clip over must not release that
    /// one.
    ///
    /// What it buys is the decoded recording being freed when it stops
    /// sounding rather than at the next sentence — on the album screen that
    /// can be minutes — and ``spokenClip`` meaning what it says. Nothing
    /// branches on it: unlike ``CallPlayer/isPlaying``, which draws
    /// `SoundButton`'s rings, no view asks this announcer whether it is
    /// sounding.
    private func clipEnded(_ ended: ObjectIdentifier, successfully: Bool) {
        guard let spokenClip, ObjectIdentifier(spokenClip) == ended else { return }

        if !successfully {
            Logger.audio.error("Sentence stopped: the clip could not be decoded")
        }
        self.spokenClip = nil
        lineFinished()
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
        Task { @MainActor in self.utteranceEnded(ended, finished: true) }
    }

    nonisolated func speechSynthesizer(
        _: AVSpeechSynthesizer,
        didCancel utterance: AVSpeechUtterance,
    ) {
        let ended = ObjectIdentifier(utterance)
        Task { @MainActor in self.utteranceEnded(ended, finished: false) }
    }
}

/// As above, and for the same reason: `AVAudioPlayer` is not `Sendable`, so
/// only the identity of the recording that ended crosses to the main actor.
extension SpeechAnnouncer: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(
        _ player: AVAudioPlayer,
        successfully flag: Bool,
    ) {
        let ended = ObjectIdentifier(player)
        Task { @MainActor in self.clipEnded(ended, successfully: flag) }
    }
}
