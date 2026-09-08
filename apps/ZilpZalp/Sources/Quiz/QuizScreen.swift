import os
import SwiftUI
import ZilpZalpData
import ZilpZalpUI

/// Game 1: the app asks for a bird, the child taps its photo.
///
/// The screen owns the arrangement and nothing else. ``QuizSession`` holds the
/// round and the taps, `ZilpZalpCore` holds the rules, and every visible part
/// is a `ZilpZalpUI` component handed finished values.
///
/// Two arrangements, from the design's two reference screens. On iPad the
/// question stands in a column to the left of a 2×2 grid of answers (1194×834,
/// screens 1c and 3a); on iPhone it sits in a row above the same grid, drawn
/// smaller (390×844, screen 1j). Neither ever scrolls: four photos a child
/// cannot see at once are not four choices.
struct QuizScreen: View {
    /// The tile edge the design draws on iPad, and the ceiling everywhere. A
    /// photo bigger than this does not make the question easier to answer.
    private static let maximumTile = ChoiceTile.defaultSize

    /// The column the question stands in on iPad, beside the answers. Wide
    /// enough for the 160 pt sound button and for the longest bird name in the
    /// base pack to wrap into two lines at 36 pt.
    private static let promptColumn: CGFloat = 320

    /// The band the feedback banner appears in, kept clear whether or not
    /// there is anything to say. The design reserves 100 px for it; a grid
    /// that jumped a banner's height on every answer would move the tiles out
    /// from under a finger that is still on its way.
    private static let feedbackSlot: CGFloat = 100
    private static let compactFeedbackSlot: CGFloat = 76

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
    let catalog: PackCatalog
    /// Called once the last question is answered. ``RootView`` pushes
    /// ``Route/roundEnd(_:)`` with it.
    let onFinished: (RoundResult) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Built on the first appearance rather than in an initialiser: a `View`
    /// is created again on every layout pass, and a new round on every pass is
    /// not a round.
    @State private var session: QuizSession?

    /// A phone in portrait, or an iPad sharing its screen. It picks the
    /// arrangement; the sizes inside it are measured, not categorised.
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
        // Every screen brings its own `TopBar`; the system bar would stack a
        // second, smaller back button above it.
        .toolbar(.hidden, for: .navigationBar)
        .onAppear(perform: open)
        // The question being spoken and the round waiting to move on both
        // outlive this view otherwise — a child who taps back would hear the
        // last question from the home screen.
        .onDisappear { session?.suspend() }
    }

    // MARK: - The round

    private func round(_ session: QuizSession) -> some View {
        VStack(spacing: 0) {
            TopBar {
                IconButton(
                    .chevronLeft,
                    label: String(localized: "nav.back.accessibility"),
                    diameter: ZSpacing.touchMinimum,
                ) { dismiss() }
            } center: {
                if !isCompact {
                    progress(session)
                }
            }

            // Ten leaves do not fit an iPhone's top bar beside a 64 pt back
            // button, so in a compact width the row moves out of the bar and
            // under it, full width — the one place it still reads as a row
            // rather than a smudge.
            if isCompact {
                progress(session)
                    .padding(.vertical, ZSpacing.step2)
                    .frame(maxWidth: .infinity)
            }

            GeometryReader { area in
                content(session, in: area.size)
                    .frame(width: area.size.width, height: area.size.height)
            }
            .padding(.horizontal, isCompact ? ZSpacing.step4 : ZSpacing.gutterScreen)
            .padding(.vertical, isCompact ? ZSpacing.step3 : ZSpacing.step5)
        }
        .onChange(of: session.isFinished) { _, finished in
            if finished {
                onFinished(session.result)
            }
        }
    }

    @ViewBuilder
    private func content(_ session: QuizSession, in area: CGSize) -> some View {
        if isCompact {
            VStack(spacing: ZSpacing.step4) {
                HStack(spacing: ZSpacing.step4) {
                    soundButton(session, diameter: SoundButton.minimumDiameter)
                    question(session)
                }
                .frame(height: SoundButton.minimumDiameter + ZShadow.ledgeLargeOffset)

                grid(session, edge: compactTile(in: area))
                feedback(session).frame(height: Self.compactFeedbackSlot)
            }
        } else {
            VStack(spacing: ZSpacing.step5) {
                HStack(spacing: ZSpacing.step7) {
                    VStack(spacing: ZSpacing.step5) {
                        soundButton(session, diameter: ZSpacing.touchHero)
                        question(session)
                    }
                    .frame(width: Self.promptColumn)

                    grid(session, edge: regularTile(in: area))
                }
                // The question and the answers are one group, centred in the
                // width together. Letting the grid claim the leftover instead
                // would pin the two of them to opposite edges with a hole
                // between, and a four-year-old's eyes have to get from one to
                // the other.
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                feedback(session).frame(height: Self.feedbackSlot)
            }
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
            credit: bird.creditLine,
            tone: Self.tones[position % Self.tones.count],
            phase: session.phase(for: bird),
            dimmed: session.isDimmed(bird),
            edge: edge,
        ) { session.choose(bird) }
    }

    /// The question, spoken again on demand.
    ///
    /// `isPlaying` is left at `false`: `SpeechAnnouncer` is a plain class, so
    /// its `isSpeaking` flag is not observable and rings driven by it would
    /// never switch off. Making the announcer `@Observable` is a follow-up in
    /// `Audio/`, which this change has no other business in.
    private func soundButton(_ session: QuizSession, diameter: CGFloat) -> some View {
        SoundButton(
            label: String(localized: "quiz.sound.accessibility"),
            diameter: diameter,
        ) { session.askQuestion() }
    }

    /// The question in writing — for the grown-up over the shoulder, exactly
    /// as on the design's screens. The child gets it spoken; the tiles stay
    /// wordless.
    private func question(_ session: QuizSession) -> some View {
        Text(verbatim: session.writtenQuestion)
            .typeStyle(isCompact ? .headline : .title, .display, weight: .extraBold)
            .foregroundStyle(ZColor.textStrong)
            .multilineTextAlignment(isCompact ? .leading : .center)
            .lineLimit(2)
            // "Wo ist der Hausrotschwanz?" is the longest question the base
            // pack asks, and on the narrowest supported screen it needs the
            // room. The floor is the design's own: nothing a child might read
            // goes below 20 pt.
            .minimumScaleFactor(ZType.Step.body.size / ZType.Step.headline.size)
            .frame(maxWidth: .infinity, alignment: isCompact ? .leading : .center)
    }

    /// What the app says back. Nothing until something has been tapped.
    ///
    /// A fresh identity per kind, so each sentence pops in rather than
    /// replacing the previous one in place.
    @ViewBuilder
    private func feedback(_ session: QuizSession) -> some View {
        if session.isAnswered {
            FeedbackBanner(String(localized: "quiz.feedback.correct"), kind: .correct)
                .id(ChoiceTile.Phase.correct)
        } else if !session.wrongTaps.isEmpty {
            FeedbackBanner(String(localized: "quiz.feedback.retry"), kind: .retry)
                .id(ChoiceTile.Phase.retry)
        }
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

    /// A pack with fewer than four species cannot fill a single question. Not
    /// reachable with the bundled pack; a sentence rather than a crash all the
    /// same, because a downloaded pack (#34) could be anything.
    private var unavailable: some View {
        Text("quiz.unavailable")
            .typeStyle(.bodyLarge, .body, weight: .regular)
            .foregroundStyle(ZColor.textBody)
            .multilineTextAlignment(.center)
            .padding(ZSpacing.gutterScreen)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Sizing

    private func open() {
        if session == nil {
            do {
                session = try QuizSession(catalog: catalog)
            } catch {
                let reason = String(describing: error)
                Logger.quiz.error("No round for \(game.title): \(reason, privacy: .public)")
                return
            }
        }
        session?.resume()
    }

    /// The tile edge on iPad: whatever fits beside the question column and
    /// above the feedback band, capped at the design's 260 pt.
    private func regularTile(in area: CGSize) -> CGFloat {
        let across = area.width - Self.promptColumn - ZSpacing.step7 - ZSpacing.gapTiles
        let down = area.height
            - Self.feedbackSlot
            - ZSpacing.step5
            - ZSpacing.gapTiles
            - ZShadow.ledgeLargeOffset
        return tileEdge(across: across, down: down)
    }

    /// The tile edge on iPhone: what is left under the question row and above
    /// the feedback band.
    private func compactTile(in area: CGSize) -> CGFloat {
        let across = area.width - ZSpacing.gapTiles
        let down = area.height
            - SoundButton.minimumDiameter
            - Self.compactFeedbackSlot
            - 2 * ZSpacing.step4
            - ZSpacing.gapTiles
            - 2 * ZShadow.ledgeLargeOffset
        return tileEdge(across: across, down: down)
    }

    /// Half of whichever of the two runs out first — the tiles are square and
    /// there are two of them each way — never above the design's tile, and
    /// never below the touch floor even where the floor means overflowing the
    /// space. A tile a four-year-old cannot hit breaks a rule the design calls
    /// non-negotiable; a few points of overhang on a screen no supported
    /// device has does not.
    private func tileEdge(across: CGFloat, down: CGFloat) -> CGFloat {
        max(ZSpacing.touchMinimum, min(Self.maximumTile, min(across, down) / 2).rounded(.down))
    }
}

// MARK: - Previews

@MainActor
@ViewBuilder
private func quizPreview(_ sizeClass: UserInterfaceSizeClass) -> some View {
    if let catalog = try? PackCatalog.bundled() {
        NavigationStack {
            QuizScreen(game: .names, catalog: catalog, onFinished: { _ in })
        }
        .environment(\.horizontalSizeClass, sizeClass)
    } else {
        Text(verbatim: "The bundled pack did not open.")
    }
}

#Preview("iPad landscape", traits: .fixedLayout(width: 1194, height: 834)) {
    quizPreview(.regular)
}

#Preview("iPhone portrait", traits: .fixedLayout(width: 390, height: 844)) {
    quizPreview(.compact)
}
