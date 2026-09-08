import Foundation
import os
import SwiftUI
import UIKit
import ZilpZalpCore
import ZilpZalpData
import ZilpZalpUI

/// One sitting at game 1: the round being played, where in it the child is,
/// and what has been tapped so far.
///
/// Wiring and state, no rules. Which species may stand beside which is
/// ``Round``'s business, what a round is worth is ``Scoring``'s; this type
/// maps the pack onto them, remembers the taps, and drives the speech. Every
/// question the screen asks about a tile — which phase, dimmed or not — is
/// answered by deriving it from those three facts rather than by storing a
/// fourth that could disagree with them.
///
/// **The tap bookkeeping wants to move.** `index`, `wrongTaps`, `isAnswered`
/// and `firstTryCorrect` are pure transitions with no I/O in them, and
/// `AGENTS.md` puts everything testable without a simulator in a package.
/// They sit here because #25 was not allowed to change `ZilpZalpCore`, not
/// because this is where they belong: the destination is a value type in Core
/// that takes a tap and returns the next state, with this class left holding
/// only the photos, the speech and the timer that genuinely cannot go there.
/// Until then this logic has no unit tests, which is the cost of the shortcut.
@MainActor
@Observable
final class QuizSession {
    /// How long the answer stays on screen before the next question. The check
    /// mark, the dimming and the banner all have to be seen and understood by
    /// somebody who is four; `--dur-celebrate` is the token the design gives
    /// exactly that moment.
    private static let answerPause = ZMotion.celebrate

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

    /// The species pool in manifest order, so that a seeded round is
    /// reproducible.
    private let species: [QuizSpecies]

    private let announcer = SpeechAnnouncer()

    /// The pending move to the next question. Held so that leaving the screen
    /// can cancel it — a round that advances behind the child's back is a
    /// round that is over before it is opened again.
    private var advance: Task<Void, Never>?

    /// The round being played. Replaced wholesale by ``resume()`` once the
    /// previous one is over.
    private(set) var round: Round

    /// Which question is being asked, `questions.count` once the round is over.
    private(set) var index = 0

    /// The species ids tapped on the current question that were not the answer.
    /// Cleared with every question; it is what makes a tile show `retry` and
    /// what decides whether the answer still counts as a first try.
    private(set) var wrongTaps: Set<String> = []

    /// True from the moment the answer is tapped until the next question is
    /// asked. Locks nothing a child can feel — it only stops a second tap from
    /// scoring twice and the round from advancing twice.
    private(set) var isAnswered = false

    /// Answers right at the first attempt. The one number the stars come from.
    private(set) var firstTryCorrect = 0

    /// The first species answered right at the first attempt, `nil` until one
    /// is. The round end celebrates it; see ``RoundResult/celebratedSpecies``.
    private(set) var firstTrySpecies: String?

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

    /// - Parameter catalog: The opened pack. Every species in it is a possible
    ///   question and a possible distractor.
    /// - Throws: `RoundError.insufficientSpecies` when the pack holds fewer
    ///   than four species and a question therefore cannot be filled. Not
    ///   reachable with the bundled pack, which has ten.
    init(catalog: PackCatalog) throws {
        let pack = catalog.pack
        birds = Dictionary(uniqueKeysWithValues: pack.birds.map { ($0.id, $0) })
        photos = Dictionary(
            uniqueKeysWithValues: pack.birds.compactMap { bird in
                catalog.photoURL(for: bird)
                    .flatMap { UIImage(contentsOfFile: $0.path(percentEncoded: false)) }
                    .map { (bird.id, Image(uiImage: $0)) }
            },
        )
        // The genus is the first word of the scientific name, and Core needs
        // nothing else of a bird: "Turdus merula" is a `Turdus`, and two of
        // those beside each other would make the question a coin toss.
        species = pack.birds.map { bird in
            let genus = bird.scientificName.split(separator: " ").first
            return QuizSpecies(id: bird.id, genus: String(genus ?? ""))
        }

        // Built here rather than on the first appearance so that a pack too
        // small to play is refused before a screen is drawn for it.
        var generator = SystemRandomNumberGenerator()
        round = try Round.make(from: species, using: &generator)
    }

    // MARK: - Reading the round

    /// The question being asked, `nil` once the round is over.
    var question: Round.Question? {
        index < round.questions.count ? round.questions[index] : nil
    }

    /// True once the round has moved past its last question — normally when
    /// the pause after the final answer runs out, and equally when ``resume()``
    /// finishes a pause that was cut short. The screen watches this to leave
    /// for the round end.
    var isFinished: Bool {
        index >= round.questions.count
    }

    /// The bird the current question asks for, `nil` once the round is over.
    var answer: Bird? {
        question.flatMap { birds[$0.answer] }
    }

    /// The four birds on offer, in the order the round put them.
    var choices: [Bird] {
        question?.choices.compactMap { birds[$0] } ?? []
    }

    /// This bird's photo, `nil` when the file was missing — the tile then draws
    /// its own placeholder rather than an empty square.
    func photo(for bird: Bird) -> Image? {
        photos[bird.id]
    }

    /// Where `bird`'s tile stands: the answer once it has been found, a "go
    /// round again" for anything already tried, untouched otherwise.
    ///
    /// Derived rather than stored, so a tile cannot end up in a phase the round
    /// disagrees with.
    func phase(for bird: Bird) -> ChoiceTile.Phase {
        if isAnswered, bird.id == question?.answer {
            return .correct
        }
        if wrongTaps.contains(bird.id) {
            return .retry
        }
        return .idle
    }

    /// Whether `bird`'s tile steps back. Only once the answer is found, and
    /// only for the other three — opacity, never a lock.
    func isDimmed(_ bird: Bird) -> Bool {
        isAnswered && bird.id != question?.answer
    }

    /// The question in writing, for the grown-up reading over the shoulder —
    /// the same sentence the app speaks, but always the written name, never the
    /// phonetic override that only a speech synthesiser should ever see.
    var writtenQuestion: String {
        guard let answer else { return "" }
        return String(
            format: String(localized: "quiz.prompt.whereIs"),
            answer.article,
            answer.name,
        )
    }

    /// What the round has come to, once it is over.
    ///
    /// The sticker's species falls back to the round's first question when
    /// nothing was answered at the first attempt, so that a round the child
    /// found hard still ends with a bird rather than an empty disc.
    var result: RoundResult {
        RoundResult(
            id: roundID,
            firstTryCorrect: firstTryCorrect,
            questionCount: round.questions.count,
            celebratedSpecies: firstTrySpecies ?? round.questions.first?.answer,
            species: Set(round.questions.map(\.answer)),
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
    /// The screen calls this every time it appears, and it has three cases to
    /// tell apart. Opened for the first time, it asks the question the
    /// constructor's round starts with. Returned to from the round end — which
    /// is all "Nochmal spielen" does — it deals a fresh round, because the last
    /// one is over. Coming back to a question that was answered while the
    /// screen was going away, it finishes that move instead of asking an
    /// already-answered question a second time.
    func resume() {
        if isFinished {
            var generator = SystemRandomNumberGenerator()
            // The pool has not changed since `init` accepted it, so the one
            // reason `make` can throw has already been ruled out. The fallback
            // deals the finished round's questions again, which is a duller
            // round and not a broken one.
            round = (try? Round.make(from: species, using: &generator)) ?? round
            index = 0
            wrongTaps = []
            isAnswered = false
            firstTryCorrect = 0
            firstTrySpecies = nil
            roundID = UUID()
            askedFirstQuestion = nil
            answeredLastQuestion = nil
        } else if isAnswered {
            // A question that was answered while the screen was going away, so
            // that the pause after it never ran out. Finish the move rather
            // than asking an already-answered question again — otherwise the
            // round comes back showing a check nobody can get past.
            nextQuestion()
            return
        }
        askQuestion()
    }

    /// Reads the question out. The sound button calls this; so does every new
    /// question.
    ///
    /// No guard against speaking over the previous utterance:
    /// ``SpeechAnnouncer/announce(_:)`` stops whatever is running before it
    /// starts, so two questions can never sound at once. Refusing the tap
    /// while the sentence is still running would only make the one button a
    /// child reaches for feel broken.
    func askQuestion() {
        guard let answer else { return }
        // Only the first one: the sound button re-reads the question, and a
        // round does not start again because a child asked to hear it twice.
        askedFirstQuestion = askedFirstQuestion ?? Date()
        Logger.quiz.debug("Asking for \(answer.id, privacy: .public)")
        announcer.announce(answer)
    }

    /// A tile was tapped.
    ///
    /// The wrong one costs nothing but the first try: no lock, no counter the
    /// child sees, and the same tile may be tapped again. The right one ends
    /// the question and, after the pause, moves the round on.
    func choose(_ bird: Bird) {
        guard let question, !isAnswered else { return }

        guard bird.id == question.answer else {
            wrongTaps.insert(bird.id)
            return
        }

        if wrongTaps.isEmpty {
            firstTryCorrect += 1
            firstTrySpecies = firstTrySpecies ?? bird.id
        }
        isAnswered = true
        answeredLastQuestion = Date()

        advance?.cancel()
        advance = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.answerPause))
            guard !Task.isCancelled else { return }
            self?.nextQuestion()
        }
    }

    /// Stops everything that outlives the screen: the sentence being spoken and
    /// the round waiting to move on.
    func suspend() {
        advance?.cancel()
        advance = nil
        announcer.stop()
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
        index += 1
        wrongTaps = []
        isAnswered = false

        // A finished round has nothing left to ask, and the question that was
        // still being spoken must not run on under the round end's praise.
        // The session owns the announcer and knows when its round is over, so
        // it stops itself rather than waiting for a screen to notice: the
        // push runs the round end's `onAppear` before this screen's
        // `onDisappear`, which is too late.
        guard !isFinished else { return announcer.stop() }
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
