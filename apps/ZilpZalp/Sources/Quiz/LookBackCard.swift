import SwiftUI
import ZilpZalpData
import ZilpZalpUI

/// Which answered question the look-back card opens on.
struct LookBack: Identifiable {
    let question: Int

    var id: Int {
        question
    }
}

/// The round's answered questions, one page each and oldest first, as they
/// stood when they were answered: the answer marked, the other three stepped
/// back. See `docs/superpowers/specs/2026-11-16-look-back-in-round-design.md`.
///
/// Looking, not playing: the tiles take no taps, and nothing sounds unless the
/// sound button is tapped — not on opening, not on turning a page. The round
/// holds underneath while the card is up; see
/// ``QuizSession/startLookBack(at:)`` and ``QuizSession/endLookBack()``.
struct LookBackCard: View {
    /// Room under the tiles for the page dots, which are drawn over the pages.
    private static let dotsRoom = ZSpacing.step7

    let session: QuizSession
    /// The question on screen, from the leaf that was tapped.
    @State var page: Int
    let close: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    /// The name the question was put with: game 1 only — in game 2 it would
    /// be the answer.
    private var writtenName: String? {
        session.game == .names ? session.answer(ofQuestion: page)?.name : nil
    }

    var body: some View {
        VStack(spacing: ZSpacing.step5) {
            header
            // On a phone the name gets a row of its own: between the sound
            // button and the close button, „Bachstelze" broke mid-word.
            if isCompact, let writtenName {
                name(writtenName)
            }
            // The dots are the page indicator, never digits: the audience
            // cannot read them.
            TabView(selection: $page) {
                ForEach(0 ..< session.answeredCount, id: \.self) { question in
                    GeometryReader { area in
                        grid(question, edge: Self.edge(in: area.size))
                            .frame(width: area.size.width, height: area.size.height)
                    }
                    // The answer's glow reaches past its tile, and a page
                    // clips whatever leaves it.
                    .padding(ZSpacing.step3)
                    .padding(.bottom, Self.dotsRoom)
                    .tag(question)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            // On the page's cream the dots alone would be white on white.
            .indexViewStyle(.page(backgroundDisplayMode: .always))
        }
        .padding(ZSpacing.step5)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ZColor.surfacePage)
    }

    /// The question as it was put — the sound button, and on an iPad the
    /// name beside it — and the way out.
    private var header: some View {
        HStack(spacing: ZSpacing.step4) {
            SoundButton(
                isPlaying: session.isCallPlaying,
                label: soundLabel,
                diameter: SoundButton.minimumDiameter,
            ) { session.askAgain(question: page) }

            if !isCompact, let writtenName {
                name(writtenName)
            }

            Spacer(minLength: 0)

            IconButton(
                .close,
                label: String(localized: "quiz.lookBack.close"),
                diameter: ZSpacing.touchMinimum,
                action: close,
            )
        }
        .frame(height: SoundButton.minimumDiameter + ZShadow.ledgeLargeOffset)
    }

    /// The bird's name in writing, in the quiz's type.
    private func name(_ name: String) -> some View {
        Text(verbatim: name)
            .typeStyle(isCompact ? .headline : .title, .display, weight: .extraBold)
            .foregroundStyle(ZColor.textStrong)
            .lineLimit(1)
            .minimumScaleFactor(ZType.Step.body.size / ZType.Step.headline.size)
    }

    /// As in the quiz: game 1's button names the bird, game 2's must not.
    private var soundLabel: String {
        if let writtenName {
            String(format: String(localized: "quiz.sound.name.accessibility"), writtenName)
        } else {
            String(localized: "quiz.sound.call.accessibility")
        }
    }

    /// The answers in two rows of two, in the order the round put them, with
    /// the quiz's tints by position.
    private func grid(_ question: Int, edge: CGFloat) -> some View {
        let answer = session.answer(ofQuestion: question)
        let choices = Array(session.choices(inQuestion: question).enumerated())
        let columns = Array(repeating: GridItem(.fixed(edge), spacing: ZSpacing.gapTiles), count: 2)
        return LazyVGrid(columns: columns, spacing: ZSpacing.gapTiles) {
            ForEach(choices, id: \.element.id) { position, bird in
                QuizTile(
                    image: session.photos.photo(bird.id, question: question),
                    label: String(
                        format: String(localized: "quiz.tile.accessibility"),
                        position + 1,
                    ),
                    tone: QuizTile.tones[position % QuizTile.tones.count],
                    phase: bird.id == answer?.id ? .correct : .idle,
                    dimmed: bird.id != answer?.id,
                    edge: edge,
                ) {}
                    // Looking, not answering: a tap here is no answer.
                    .allowsHitTesting(false)
            }
        }
    }

    /// The quiz's own sizing rule, for two rows of two in `area`. Below the
    /// tile's floor ``QuizTile`` scales it, as in the quiz.
    private static func edge(in area: CGSize) -> CGFloat {
        QuizLayout.tileEdge(
            across: area.width - ZSpacing.gapTiles,
            down: area.height - ZSpacing.gapTiles - 2 * ZShadow.ledgeLargeOffset,
        )
    }
}

extension View {
    /// The look-back card over the round, presented like the feedback sheet:
    /// a sheet, never a full-screen cover, so the round's `onAppear` — which
    /// would ask the question again — does not run when it goes.
    func lookBack(_ item: Binding<LookBack?>, session: QuizSession) -> some View {
        sheet(item: item, onDismiss: { session.endLookBack() }, content: { lookBack in
            LookBackCard(session: session, page: lookBack.question) { item.wrappedValue = nil }
        })
    }
}
