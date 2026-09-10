import os
import SwiftUI
import ZilpZalpData
import ZilpZalpUI

/// Both games: the app asks for a bird, the child taps its photo. How it asks
/// — the spoken name in game 1, the recorded call in game 2 — is
/// ``QuizSession``'s; the screen looks the same either way, which is the whole
/// point of one engine for two games (spec §4).
///
/// The screen owns the arrangement and nothing else. ``QuizSession`` holds the
/// round and the taps, `ZilpZalpCore` holds the rules, and every visible part
/// is a `ZilpZalpUI` component handed finished values.
///
/// Two arrangements, from the design's two reference screens: the question in
/// a column to the left of a 2×2 grid of answers (1194×834, screens 1c and
/// 3a), or in a row above the same grid (390×844, screen 1j). Which one a
/// screen gets is measured rather than categorised — see ``QuizLayout``.
/// Neither ever scrolls: four photos a child cannot see at once are not four
/// choices.
struct QuizScreen: View {
    /// One leaf of the progress row in a compact width.
    ///
    /// ``QuizProgress`` defaults to 44 pt, which its own documentation sizes
    /// for "a round of five". A round is ten (spec §4), and ten 44 pt leaves
    /// with 12 pt between them are 548 pt — wider than any iPhone. This is the
    /// largest leaf that fits ten of them across a 390 pt screen.
    private static let compactLeaf: CGFloat = 24

    /// The four rubric tints, one per position in the grid. Position rather
    /// than species: the tints are there to tell four squares apart, and a
    /// tint that travelled with a bird would be a second, quieter way of
    /// naming it.
    private static let tones: [ChoiceTile.Tone] = [.wald, .beeren, .rufe, .sumpf]

    let game: Game
    let library: PackLibrary
    /// How often "Nochmal spielen" has sent a child back here; see
    /// ``RootView/roundsAskedFor``. Only ever compared with itself: what the
    /// screen acts on is the change, never the number.
    let askedFor: Int
    /// How often the playing child has recognised each species so far, asked
    /// when the round ends rather than passed as a value: the round the child
    /// is about to finish is not the first one this screen has dealt, and the
    /// answer has to be the one standing on the profile now. It decides which
    /// bird the round end celebrates — see
    /// ``RoundPlay/celebratedSpecies(recognisedBefore:)``.
    let recognitions: () -> [String: Int]
    /// Called once the last question is answered. ``RootView`` pushes
    /// ``Route/roundEnd(_:)`` with it.
    let onFinished: (RoundResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Built on the first appearance rather than in an initialiser: a `View`
    /// is created again on every layout pass, and a new round on every pass is
    /// not a round.
    @State private var session: QuizSession?

    /// What the feedback band turned out to need: the taller of the two
    /// sentences at this width, measured rather than guessed, so the answers
    /// are sized against the room that is really left. It depends on the
    /// width and the font and never on the tiles, so there is no loop here —
    /// one extra layout pass and it settles. Same move as ``HomeScreen``'s
    /// headline.
    @State private var feedbackHeight: CGFloat = 0

    /// The way out of the round and the question in front of it; see
    /// ``LeaveRequest``.
    @State private var leaving = LeaveRequest()

    /// A phone, or an iPad sharing its screen. It settles how big the parts
    /// around the answers are drawn — type step, sound button, leaf row,
    /// margins, the feedback band. Where those parts *stand* is measured, not
    /// categorised: see ``QuizLayout``.
    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        Group {
            if let session {
                round(session)
            } else {
                unavailable
            }
        }
        .background(ZColor.surfacePage)
        .quitQuestion($leaving, round: session) { dismiss() }
        // Every screen brings its own `TopBar`; the system bar would stack a
        // second, smaller back button above it.
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: open)
        // And on the count as well, because the appearance is not always
        // delivered: a tap on "Nochmal spielen" that lands while the round end
        // is still being pushed reverses that push, and this screen is then
        // told neither that it went away nor that it came back — it would keep
        // the finished round, its ten green leaves and no way out of them
        // (#157).
        //
        // Both fire in the ordinary case, milliseconds apart, and that is
        // deliberate. Only the first finds a finished round and deals; the
        // second puts the same question again, which is inaudible at that
        // distance — and it is what picks the round back up whenever
        // something covers this screen and `suspend()` cuts the question.
        .onChange(of: askedFor) { session?.resume() }
        // The question being spoken and the round waiting to move on both
        // outlive this view otherwise — a child who taps back would hear the
        // last question from the home screen.
        .onDisappear { session?.suspend() }
    }

    // MARK: - The round

    private func round(_ session: QuizSession) -> some View {
        VStack(spacing: 0) {
            TopBar(title: game.title) {
                IconButton(
                    .chevronLeft,
                    label: String(localized: "nav.back.accessibility"),
                    diameter: ZSpacing.touchMinimum,
                ) { leaving.ask(session) { dismiss() } }
            }

            // Under the bar rather than in it, on every width. The phone never
            // had room for it up there — ten 44 pt leaves are 548 pt beside a
            // 64 pt back button — and since #220 the iPad has none either: the
            // centre carries the game's name, and a title beside ten leaves
            // would shrink to fit an 11 inch iPad in portrait. One row in one
            // place is also one arrangement fewer to think about.
            progress(session)
                .padding(.vertical, ZSpacing.step2)
                .frame(maxWidth: .infinity)

            GeometryReader { area in
                content(session, in: area.size)
                    .frame(width: area.size.width, height: area.size.height)
            }
            .padding(.horizontal, isCompact ? ZSpacing.step4 : ZSpacing.gutterScreen)
            .padding(.vertical, isCompact ? ZSpacing.step3 : ZSpacing.step5)
        }
        .onChange(of: session.isFinished) { _, finished in
            if finished {
                onFinished(session.result(recognisedBefore: recognitions()))
            }
        }
    }

    @ViewBuilder
    private func content(_ session: QuizSession, in area: CGSize) -> some View {
        let layout = QuizLayout(area: area, isCompact: isCompact, feedbackBand: feedbackHeight)

        VStack(spacing: layout.stackGap) {
            switch layout.arrangement {
            case .above:
                HStack(spacing: ZSpacing.step4) {
                    soundButton(session, diameter: layout.soundDiameter)
                    if let name = session.writtenQuestion {
                        question(name, in: .above)
                    }
                }
                .frame(height: layout.soundDiameter + ZShadow.ledgeLargeOffset)

                grid(session, edge: layout.tile)

            case .beside:
                HStack(spacing: ZSpacing.step7) {
                    VStack(spacing: ZSpacing.step5) {
                        soundButton(session, diameter: layout.soundDiameter)
                        if let name = session.writtenQuestion {
                            question(name, in: .beside)
                        }
                    }
                    .frame(width: QuizLayout.promptColumn)

                    grid(session, edge: layout.tile)
                }
                // The question and the answers are one group, centred in the
                // width together. Letting the grid claim the leftover instead
                // would pin the two of them to opposite edges with a hole
                // between, and a four-year-old's eyes have to get from one to
                // the other.
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            feedbackBand(session, reserve: layout.feedbackSlot)
        }
    }

    /// The answers: two rows of two, in the order the round put them.
    ///
    /// Built from whatever the round offers rather than from a fixed four, so
    /// a pack that ever runs a question with three choices draws three tiles
    /// instead of an empty square, and the last question's answer leaves no
    /// row behind when the round ends.
    ///
    /// The birds travel into the rows as values. Handing the tiles an index
    /// into `session.choices` instead crashed the app on the tenth answer:
    /// `ForEach` re-ran a row with the indices it was built with while the
    /// session had already moved past the last question and was offering
    /// none. There is no index left here to go stale.
    private func grid(_ session: QuizSession, edge: CGFloat) -> some View {
        let choices = Array(session.choices.enumerated())
        return VStack(spacing: ZSpacing.gapTiles) {
            ForEach(Array(stride(from: 0, to: choices.count, by: 2)), id: \.self) { first in
                HStack(spacing: ZSpacing.gapTiles) {
                    ForEach(
                        choices[first ..< min(first + 2, choices.count)],
                        id: \.element.id,
                    ) { choice in
                        tile(session, choice.element, at: choice.offset, edge: edge)
                    }
                }
            }
        }
        // Height only: the grid takes the vertical room the arrangement leaves
        // it and centres in it, but its width stays its own so that whatever
        // stands beside it is centred with it rather than pushed aside.
        .frame(maxHeight: .infinity)
    }

    private func tile(
        _ session: QuizSession,
        _ bird: Bird,
        at position: Int,
        edge: CGFloat,
    ) -> some View {
        QuizTile(
            image: session.photo(for: bird),
            // Never the bird's name: VoiceOver would read the answer out to a
            // child who is meant to find it. The position is all the label can
            // honestly say about a photo the game is asking about.
            label: String(format: String(localized: "quiz.tile.accessibility"), position + 1),
            tone: Self.tones[position % Self.tones.count],
            phase: session.phase(for: bird),
            dimmed: session.isDimmed(bird),
            edge: edge,
        ) { session.choose(bird) }
            .accessibilityIdentifier(QuizIdentifier.tile(bird.id))
    }

    /// The question, put again on demand — read out in game 1, played in game 2.
    ///
    /// The rings are the call's. In game 1 `isPlaying` stays false throughout:
    /// nothing there comes out of a file, and whether the synthesiser is still
    /// speaking is not observable, so rings driven by it would never switch
    /// off again.
    private func soundButton(_ session: QuizSession, diameter: CGFloat) -> some View {
        SoundButton(
            isPlaying: session.isCallPlaying,
            label: soundLabel(session),
            diameter: diameter,
        ) { session.askQuestion() }
            // On the button rather than on the written name, because game 2
            // has no written name and the screenshot run has to find the
            // question in both games. It is the one part of the question row
            // that is on the screen whichever game is being played.
            .accessibilityIdentifier(QuizIdentifier.question(session.answer?.id))
    }

    /// What VoiceOver says the button will do, which is what it is about to
    /// say or play. Game 1 names the bird — the name is the whole question,
    /// and the button says it a second later anyway. Game 2 must not: there
    /// the name is the answer, for the reason a tile's label is a position.
    private func soundLabel(_ session: QuizSession) -> String {
        guard let name = session.writtenQuestion else {
            return String(localized: "quiz.sound.call.accessibility")
        }
        return String(format: String(localized: "quiz.sound.name.accessibility"), name)
    }

    /// The bird's name in writing — for the grown-up over the shoulder,
    /// exactly as on the design's screens. The child gets it spoken; the tiles
    /// stay wordless. Only game 1 has one, and only the name: the sentence
    /// around it went with #220, together with the article that made it „der
    /// Lachender Hans".
    ///
    /// It reads from the sound button: beside it in a row, under it in a
    /// column. So the arrangement settles the alignment, and nothing else
    /// has to be told about it.
    private func question(_ name: String, in arrangement: QuizLayout.Arrangement) -> some View {
        let leading = arrangement == .above
        return Text(verbatim: name)
            .typeStyle(isCompact ? .headline : .title, .display, weight: .extraBold)
            .foregroundStyle(ZColor.textStrong)
            .multilineTextAlignment(leading ? .leading : .center)
            .lineLimit(2)
            // "Hausrotschwanz" is the longest name the base pack asks for, and
            // on the narrowest supported screen it needs the room. The floor
            // is the design's own: nothing a child might read goes below 20 pt.
            .minimumScaleFactor(ZType.Step.body.size / ZType.Step.headline.size)
            .frame(maxWidth: .infinity, alignment: leading ? .leading : .center)
    }

    /// The band the app says something back in, kept clear whether or not
    /// there is anything to say.
    ///
    /// Both sentences are drawn into it invisibly, so the band is always as
    /// tall as the taller of them needs *at this width* and the one that
    /// actually appears finds its room already reserved. A
    /// `frame(height:)` around a branch that produces nothing reserved
    /// nothing at all — the grid moved 46 pt the instant a banner appeared
    /// (#115) — and a fixed height the sentence did not fit truncated it to
    /// one line (#116). Measuring covers both, and keeps covering them if
    /// the sentences ever change.
    private func feedbackBand(_ session: QuizSession, reserve: CGFloat) -> some View {
        ZStack {
            template(correctBanner)
            template(retryBanner)
            feedback(session)
        }
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
            feedbackHeight = $0
        }
        // The design's reserve is the floor, never the ceiling: an iPad's
        // band stays the 100 pt the design draws even though one line needs
        // less.
        .frame(maxWidth: .infinity, minHeight: reserve)
    }

    /// What the app says back. Nothing until something has been tapped.
    ///
    /// A fresh identity per kind, so each sentence pops in rather than
    /// replacing the previous one in place.
    @ViewBuilder
    private func feedback(_ session: QuizSession) -> some View {
        if session.isAnswered {
            correctBanner.id(ChoiceTile.Phase.correct)
        } else if !session.wrongTaps.isEmpty {
            retryBanner.id(ChoiceTile.Phase.retry)
        }
    }

    private var correctBanner: FeedbackBanner {
        FeedbackBanner(String(localized: "quiz.feedback.correct"), kind: .correct)
    }

    private var retryBanner: FeedbackBanner {
        FeedbackBanner(String(localized: "quiz.feedback.retry"), kind: .retry)
    }

    /// A banner that is only there to be measured: it holds the band open and
    /// is otherwise not on the screen at all.
    ///
    /// `hidden()` already keeps it out of the drawing, out of hit testing and
    /// out of the accessibility tree — verified in the simulator, where the
    /// tree carries no banner at all until one is actually said. The explicit
    /// `accessibilityHidden(true)` says so anyway: a child sweeping VoiceOver
    /// across the screen must never meet a sentence the app has not said, and
    /// that promise is too important to rest on a side effect.
    private func template(_ banner: FeedbackBanner) -> some View {
        banner
            .hidden()
            .accessibilityHidden(true)
    }

    private func progress(_ session: QuizSession) -> some View {
        let total = session.round.questions.count
        let asked = min(session.index + 1, total)
        return QuizProgress(
            // The leaf fills the moment the answer lands, not one question
            // later: it is the smallest reward the screen has.
            total: total,
            completed: session.isAnswered ? asked : session.index,
            current: session.index,
            label: String(localized: "quiz.progress.label"),
            value: String(format: String(localized: "quiz.progress.value"), asked, total),
            leafSize: isCompact ? Self.compactLeaf : QuizProgress.defaultLeafSize,
        )
    }

    /// A pack with fewer than four species cannot fill a single question, and
    /// a pack without calls cannot fill one of game 2's. Neither is reachable
    /// — the bundled pack has ten species, and ``AppModel/games`` offers game 2
    /// only where it can be played — but a sentence rather than a crash all the
    /// same, because a downloaded pack (#34) could be anything.
    private var unavailable: some View {
        Text("quiz.unavailable")
            .typeStyle(.bodyLarge, .body, weight: .regular)
            .foregroundStyle(ZColor.textBody)
            .multilineTextAlignment(.center)
            .padding(ZSpacing.gutterScreen)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func open() {
        if session == nil {
            do {
                session = try QuizSession(library: library, game: game)
            } catch {
                let reason = String(describing: error)
                Logger.quiz.error("No round for \(game.title): \(reason, privacy: .public)")
                return
            }
        }
        session?.resume()
    }
}
