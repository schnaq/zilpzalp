import Foundation
import os
import SwiftUI
import UIKit
import ZilpZalpCore
import ZilpZalpData
import ZilpZalpUI

/// One sitting at either game: the round being played, where in it the child
/// is, and what has been tapped so far.
///
/// Wiring, no rules. Which species may stand beside which is ``Round``'s
/// business, what a round is worth is ``Scoring``'s, and where a tap leaves
/// the round is ``RoundPlay``'s; this type maps the pack onto them and owns
/// only what none of them can hold — the photos, the recordings, the way the
/// question is put and the pause after an answer. Everything the screen asks
/// about a tile is passed through to the play rather than answered a second
/// time here, so a tile cannot end up in a phase the round disagrees with.
///
/// The two games differ in one thing and that thing lives here: game 1 reads
/// the bird's name out, game 2 plays its recorded call and says nothing at all
/// — the name would be the answer (#31).
@MainActor
@Observable
final class QuizSession {
    /// How long the answer stays on screen before the next question. The check
    /// mark, the dimming and the banner all have to be seen and understood by
    /// somebody who is four; `--dur-celebrate` is the token the design gives
    /// exactly that moment.
    private static let answerPause = ZMotion.celebrate

    /// Which question this sitting asks: the spoken name, or the call.
    private let game: Game

    /// The pack this round is drawn from, by species id — the only way back
    /// from a ``Round``'s identifiers to a bird with a name and a photo.
    private let birds: [String: Bird]

    /// Every bird's photo, resolved once when the session is built.
    ///
    /// Ten files, opened together rather than per question: `UIImage` maps the
    /// file and defers the decode to the first draw, so this costs a handful
    /// of file lookups, and in exchange no tile ever appears as the sand
    /// placeholder and fills in a moment later. Four such flashes per question
    /// would be the most visible thing on the screen.
    private let photos: [String: Image]

    /// Every bird's call, resolved once when the session is built — only the
    /// birds that carry one on disk are in here, and in game 2 those are
    /// exactly the birds a question can ask for.
    ///
    /// Resolved up front for the same reason the photos are: a round asks its
    /// question the moment it appears, and looking a file up on the way to the
    /// speaker would put the disk between the child and the sound.
    private let calls: [String: URL]

    /// The species pool in manifest order, so that a seeded round is
    /// reproducible.
    private let species: [QuizSpecies]

    private let announcer: SpeechAnnouncer

    /// Built for both games and used by one. It holds no recording until a
    /// call is played, so game 1 carries an empty object rather than an
    /// optional that would need unwrapping at every call site.
    private let player = CallPlayer()

    /// The pending move to the next question. Held so that leaving the screen
    /// can cancel it — a round that advances behind the child's back is a
    /// round that is over before it is opened again.
    private var advance: Task<Void, Never>?

    /// The round being played and everything tapped in it. Replaced wholesale
    /// by ``resume()`` once the previous one is over.
    private var play: RoundPlay

    /// What tells this round apart from the next one, so the round end books
    /// it exactly once. Renewed with every fresh round in ``resume()``.
    private var roundID = UUID()

    /// When the first question of this round went up, `nil` until it does.
    ///
    /// Set where the question is spoken rather than in ``resume()``: a round
    /// is dealt before the screen it is played on exists, and the seconds a
    /// child owes the daily budget (#36) start when a bird is on the screen.
    private var askedFirstQuestion: Date?

    /// When the last answer of this round was tapped.
    ///
    /// Taken on the tap and not when the round moves on: `answerPause` is a
    /// second of check mark and applause that belongs to the round, but the
    /// pair of timestamps is meant to say "first question to last answer",
    /// and it should say exactly that.
    private var answeredLastQuestion: Date?

    /// - Parameters:
    ///   - catalog: The opened pack. Every species in it is a possible
    ///     distractor; which of them a question can ask for depends on the game.
    ///   - game: Whether the question is the spoken name or the recorded call.
    /// - Throws: `RoundError.insufficientSpecies` when the pack holds fewer
    ///   than four species and a question therefore cannot be filled, or
    ///   `RoundError.noSpeciesToAskFor` when game 2 is opened on a pack that
    ///   carries no call at all. Neither is reachable from the home screen: the
    ///   bundled pack has ten species, and ``AppModel/games`` offers game 2 only
    ///   where there are calls to ask with.
    init(catalog: PackCatalog, game: Game) throws {
        self.game = game
        let pack = catalog.pack
        birds = Dictionary(uniqueKeysWithValues: pack.birds.map { ($0.id, $0) })
        photos = Dictionary(
            uniqueKeysWithValues: pack.birds.compactMap { bird in
                catalog.photoURL(for: bird)
                    .flatMap { UIImage(contentsOfFile: $0.path(percentEncoded: false)) }
                    .map { (bird.id, Image(uiImage: $0)) }
            },
        )
        let recordings = Dictionary(
            uniqueKeysWithValues: pack.birds.compactMap { bird in
                catalog.callURL(for: bird).map { (bird.id, $0) }
            },
        )
        calls = recordings
        announcer = SpeechAnnouncer(pack: catalog)

        // The genus is the first word of the scientific name, and Core needs
        // nothing else of a bird: "Turdus merula" is a `Turdus`, and two of
        // those beside each other would make the question a coin toss.
        //
        // Game 2 puts its question with the recording, so a bird without one
        // cannot be the answer there — its photo stays in as a distractor
        // (#31). The local `recordings` rather than the property: a closure in
        // an initialiser may not reach for `self` yet.
        species = pack.birds.map { bird in
            let genus = bird.scientificName.split(separator: " ").first
            return QuizSpecies(
                id: bird.id,
                genus: String(genus ?? ""),
                canBeAsked: game == .names || recordings[bird.id] != nil,
            )
        }

        // Built here rather than on the first appearance so that a pack too
        // small to play is refused before a screen is drawn for it.
        var generator = SystemRandomNumberGenerator()
        play = try RoundPlay(round: Round.make(from: species, using: &generator))
    }

    // MARK: - Reading the round

    /// The round being played, for the screen's progress row.
    var round: Round {
        play.round
    }

    /// Which question is being asked; see ``RoundPlay/index``.
    var index: Int {
        play.index
    }

    /// Whether the current question has been answered; see
    /// ``RoundPlay/isAnswered``.
    var isAnswered: Bool {
        play.isAnswered
    }

    /// The species tapped on the current question that were not the answer;
    /// see ``RoundPlay/wrongTaps``.
    var wrongTaps: Set<String> {
        play.wrongTaps
    }

    /// True once the round has moved past its last question — normally when
    /// the pause after the final answer runs out, and equally when ``resume()``
    /// finishes a pause that was cut short. The screen watches this to leave
    /// for the round end.
    var isFinished: Bool {
        play.isFinished
    }

    /// The bird the current question asks for, `nil` once the round is over.
    var answer: Bird? {
        play.question.flatMap { birds[$0.answer] }
    }

    /// The four birds on offer, in the order the round put them.
    var choices: [Bird] {
        play.question?.choices.compactMap { birds[$0] } ?? []
    }

    /// This bird's photo, `nil` when the file was missing — the tile then draws
    /// its own placeholder rather than an empty square.
    func photo(for bird: Bird) -> Image? {
        photos[bird.id]
    }

    /// Whether a call is sounding right now — the rings on the sound button.
    /// Always false in game 1, which plays no recording at all.
    var isCallPlaying: Bool {
        player.isPlaying
    }

    /// Where `bird`'s tile stands, in the design system's terms.
    func phase(for bird: Bird) -> ChoiceTile.Phase {
        switch play.phase(of: bird.id) {
        case .idle: .idle
        case .retry: .retry
        case .correct: .correct
        }
    }

    /// Whether `bird`'s tile steps back. Only once the answer is found, and
    /// only for the other three — opacity, never a lock.
    func isDimmed(_ bird: Bird) -> Bool {
        play.isDimmed(bird.id)
    }

    /// The question in writing, for the grown-up reading over the shoulder.
    ///
    /// Game 1 writes the sentence it speaks, but always with the written name
    /// and never with the phonetic override that only a speech synthesiser
    /// should ever see. Game 2 writes its own title instead — "Wer singt da?" —
    /// because there the name *is* the answer, and printing it would hand it to
    /// everybody who can read. The title rather than a second catalog entry
    /// saying the same words: it is what the tile promised, and what a grown-up
    /// who tapped that tile expects at the top of the screen.
    var writtenQuestion: String {
        guard let answer else { return "" }
        return switch game {
        case .names:
            String(
                format: String(localized: "quiz.prompt.whereIs"),
                answer.article,
                answer.name,
            )
        case .calls:
            game.title
        }
    }

    /// What the round has come to, once it is over. Which bird of it is
    /// celebrated is ``RoundPlay/celebratedSpecies(recognisedBefore:)``.
    func result(recognisedBefore: [String: Int]) -> RoundResult {
        RoundResult(
            id: roundID,
            questionCount: play.round.questions.count,
            celebratedSpecies: play.celebratedSpecies(recognisedBefore: recognisedBefore),
            recognitions: play.recognitions,
            playtime: playtime,
        )
    }

    /// First question to last answer. Zero for a round that was never played
    /// — there is nothing to bill a child for a screen it only looked at.
    private var playtime: TimeInterval {
        guard let askedFirstQuestion, let answeredLastQuestion else { return 0 }
        return max(0, answeredLastQuestion.timeIntervalSince(askedFirstQuestion))
    }

    // MARK: - Playing it

    /// Picks the round up where the screen left it, or deals a new one.
    ///
    /// Called when the screen opens the round, when "Nochmal spielen" sends a
    /// child back for another one, and when "Weiterspielen" puts the quit card
    /// away again — and it has three cases to tell apart, which the callers do
    /// not map onto one by one. A finished round is replaced by a fresh one,
    /// because the last is over. A question answered while the screen was
    /// going away has its move finished rather than being asked again. And
    /// anything else is a question to put, whether for the first time or once
    /// more.
    func resume() {
        if play.isFinished {
            var generator = SystemRandomNumberGenerator()
            // The pool has not changed since `init` accepted it, so neither
            // reason `make` can throw has come back. The fallback deals the
            // finished round's questions again, which is a duller round and
            // not a broken one.
            let dealt = try? Round.make(from: species, using: &generator)
            play = RoundPlay(round: dealt ?? play.round)
            roundID = UUID()
            askedFirstQuestion = nil
            answeredLastQuestion = nil
        } else if play.isAnswered {
            // A question that was answered while the screen was going away, so
            // that the pause after it never ran out. Finish the move rather
            // than asking an already-answered question again — otherwise the
            // round comes back showing a check nobody can get past.
            nextQuestion()
            return
        }
        askQuestion()
    }

    /// Puts the question: game 1 reads the name out, game 2 plays the call. The
    /// sound button calls this; so does every new question.
    ///
    /// No guard against sounding over whatever is still running, because
    /// neither side needs one: ``SpeechAnnouncer/announce(_:)`` and
    /// ``CallPlayer/play(_:)`` both stop what they do and begin again, so two
    /// questions can never sound at once. Refusing the tap while a question
    /// runs would only make the one button a child reaches for feel broken.
    func askQuestion() {
        guard let answer else { return }
        // Only the first one: the sound button asks again, and a round does not
        // start again because a child asked to hear it twice.
        askedFirstQuestion = askedFirstQuestion ?? Date()
        Logger.quiz.debug("Asking for \(answer.id, privacy: .public)")

        switch game {
        case .names:
            announcer.announce(.whereIs(answer))
        case .calls:
            // Never missing in a round of game 2 — only birds with a recording
            // are asked for. Silence if it ever were: saying the name instead
            // would hand the child the answer.
            if let call = calls[answer.id] {
                player.play(call)
            }
        }
    }

    /// A tile was tapped.
    ///
    /// The wrong one costs nothing but the first try: no lock, no counter the
    /// child sees, and the same tile may be tapped again. The right one ends
    /// the question and, after the pause, moves the round on. What the tap was
    /// worth is the play's answer; the pause is this type's, because a clock
    /// has no business in Core.
    func choose(_ bird: Bird) {
        // `.ignored` covers the second tap during the pause and a tap on a
        // finished round, and neither may arm the timer a second time.
        guard case .correct = play.tap(bird.id) else { return }

        // The question has been answered, so it stops being asked. A call left
        // running would sound over the next question, and over the round end's
        // praise if this was the last one: that screen speaks as it appears,
        // and nothing is spoken while a call plays (#30).
        player.stop()
        answeredLastQuestion = Date()

        advance?.cancel()
        advance = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.answerPause))
            guard !Task.isCancelled else { return }
            self?.nextQuestion()
        }
    }

    /// Stops everything that outlives the screen: the question being spoken or
    /// played, and the round waiting to move on.
    func suspend() {
        advance?.cancel()
        advance = nil
        announcer.stop()
        player.stop()
    }

    /// Moves the round on by one, from the pause after an answer or from
    /// ``resume()`` picking that pause up where it was interrupted.
    ///
    /// Cancels the pending move first rather than only dropping the reference:
    /// a `Task` nobody holds keeps running, so a caller that arrives while one
    /// is still in flight would advance the round and then have it advanced a
    /// second time under it — one question the child never got to see. When
    /// the pending move is the caller, cancelling it here is a no-op: it is
    /// already past its own cancellation check.
    private func nextQuestion() {
        advance?.cancel()
        advance = nil
        play.advance()

        // A finished round has nothing left to ask, and neither the sentence
        // nor the call may run on under the round end's praise — a call still
        // sounding would swallow that screen's spoken headline outright (#30).
        // The session owns both and knows when its round is over, so it stops
        // them itself rather than waiting for a screen to notice: the push runs
        // the round end's `onAppear` before this screen's `onDisappear`.
        //
        // The call too, though ``choose(_:)`` stopped it on the answer: the
        // sound button stays live through the pause that follows, and a tap
        // there starts the answered question's call again.
        guard !play.isFinished else {
            announcer.stop()
            player.stop()
            return
        }
        askQuestion()
    }
}

extension Logger {
    /// Playing a round.
    ///
    /// The third copy of the bundle identifier in this target, after
    /// `Logger.packs` and `Logger.audio`. `AppModel.swift` asks the third one
    /// to pull all three into a single constant; that means editing `Audio/`,
    /// which this pull request has no other business in, so it is left as a
    /// follow-up rather than smuggled in here.
    static let quiz = Logger(subsystem: "com.schnaq.zilpzalp", category: "quiz")
}
