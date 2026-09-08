import SwiftUI
import UIKit
import ZilpZalpCore
import ZilpZalpData
import ZilpZalpUI

/// The end of a round: three stars, a bird to keep, and the way back into a
/// new round. Screen 1d and `design/ui_kits/ipad_app/RewardScreen.jsx`.
///
/// **Celebration without competition.** The screen shows what was met and
/// what was earned, and nothing else: no percentage, no error count, no time,
/// nothing that measures this round against another one or against another
/// child. The three stars are always all three — the earned ones lit, the
/// rest dim — because one star has to read as an achievement rather than as
/// two missing ones, and a child who cannot read has only the picture to go
/// by. The praise is spoken for the same reason.
///
/// Nothing is written down. #29 records the round through `ProfileStore` and
/// fills the sticker album; until then the sticker says which bird this round
/// was about, never that it was "new".
struct RoundEndScreen: View {
    /// How far a star rises, from `zz-bob` in `design/guidelines/motion.css`.
    private static let bobHeight: CGFloat = 8

    /// One bob, out and back. No `ZMotion` duration covers it — the tokens
    /// stop at 900 ms because they time reactions, and this is idle life — so
    /// it is the 1.4 s of screen 1d and `RewardScreen.jsx`. Halved where it is
    /// used: SwiftUI counts one leg, the autoreverse gives back the other.
    private static let bobPeriod: TimeInterval = 1.4

    /// How far apart the three stars start bobbing, again from screen 1d.
    /// Together they read as a wave rather than as one blinking row.
    private static let bobStagger: TimeInterval = 0.15

    /// Where `zz-pop` starts the sticker: a little under full size rather than
    /// at nothing, so it lands instead of exploding.
    private static let popFromScale: CGFloat = 0.6

    /// The sticker on iPad, the 200 pt of screen 1e and `RewardScreen.jsx`.
    private static let regularSticker: CGFloat = 200

    /// The strip at the foot that belongs to the wordmark: the mark itself
    /// plus the gap under it and the same gap above, so the celebration is
    /// centred in what is left rather than behind it.
    private static let signatureBand = Wordmark.minimumSize + 2 * ZSpacing.step5

    /// A star that has not been earned. Olive rather than sun: dark enough
    /// against the forest ground to stay unlit, light enough to stay a star.
    /// What is missing is shown, exactly as a locked ``RewardSticker`` keeps
    /// its picture.
    private static let unlitStar = ZColor.olive600

    /// What the round earned. Comes from ``QuizSession`` through
    /// ``Route/roundEnd(_:)``; nothing here recomputes it.
    let result: RoundResult

    /// The pack the round was drawn from, for the sticker's photo, name and
    /// credit. Optional because ``RootView`` holds it optionally; without it
    /// the sticker falls back to its star glyph rather than to a hole.
    let catalog: PackCatalog?

    /// Pops back to ``QuizScreen``, which deals a fresh round when it
    /// reappears with a finished one behind it.
    let playAgain: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Flipped once on appearance to start the bob and the pop. Both
    /// animations hang off it, so with Reduce Motion on it changes nothing
    /// that moves: the stars sit still and the sticker is simply there.
    @State private var settled = false

    /// The bird on the sticker, resolved once. A `View` is built again on
    /// every layout pass, and reading the photo off disk on each of them
    /// would be a file lookup per frame of the pop.
    @State private var sticker: Sticker?

    /// The praise, spoken. Built on the first appearance for the same reason,
    /// and because a second synthesiser would talk over the first.
    @State private var announcer: SpeechAnnouncer?

    /// A phone in portrait, or an iPad sharing its screen.
    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    /// A phone in landscape: 400 pt of height for a hero line, a sticker and
    /// two buttons. The sticker moves beside the praise there instead of
    /// under it.
    private var isShort: Bool {
        verticalSizeClass == .compact
    }

    var body: some View {
        celebration
            .multilineTextAlignment(.center)
            // The strip the wordmark stands in, kept clear rather than drawn
            // over: an overlay at the foot of a centred column sits on the
            // buttons as soon as the screen is short, which on an iPad in
            // landscape it is.
            .padding(.bottom, showsSignature ? Self.signatureBand : 0)
            .padding(isCompact ? ZSpacing.step5 : ZSpacing.gutterScreen)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ZColor.surfaceForest)
            .overlay(alignment: .bottom) { signature }
            // No `TopBar`: screen 1d has none, and a finished round is
            // nothing to go back into — "Nochmal spielen" is the way on. The
            // bar is hidden like everywhere else in this app; it is
            // `navigationBarBackButtonHidden()` that takes the swipe back
            // with it, which is why it is here rather than only the toolbar
            // line.
            .toolbar(.hidden, for: .navigationBar)
            .navigationBarBackButtonHidden()
            .onAppear(perform: celebrate)
            // The praise must not still be running under the first question
            // of the next round.
            .onDisappear { announcer?.stop() }
    }

    // MARK: - Arrangement

    @ViewBuilder
    private var celebration: some View {
        if isShort {
            VStack(spacing: ZSpacing.step4) {
                HStack(spacing: ZSpacing.step7) {
                    VStack(spacing: ZSpacing.step3) {
                        stars
                        praise
                    }
                    reward
                }
                actions
            }
        } else {
            VStack(spacing: ZSpacing.step5) {
                stars
                praise
                reward
                actions
            }
        }
    }

    /// The three stars, bobbing. Hidden from VoiceOver because ``praise``
    /// says the same thing in words right underneath.
    private var stars: some View {
        HStack(spacing: ZSpacing.step3) {
            ForEach(0 ..< Scoring.maximumStars, id: \.self) { position in
                Icon(.star, size: .custom(starSize))
                    .foregroundStyle(position < result.stars ? ZColor.reward : Self.unlitStar)
                    .offset(y: settled ? -Self.bobHeight : 0)
                    .animation(bob(delayedBy: Double(position) * Self.bobStagger), value: settled)
            }
        }
        .accessibilityHidden(true)
    }

    private var praise: some View {
        VStack(spacing: ZSpacing.step3) {
            Text("roundEnd.title")
                .typeStyle(isCompact ? .display2 : .hero, .display, weight: .extraBold)
                .foregroundStyle(ZColor.white)

            Text(verbatim: starsEarned)
                .typeStyle(isCompact ? .body : .bodyLarge, .body, weight: .bold)
                .foregroundStyle(ZColor.textOnColor)
        }
    }

    /// The bird this round was about, arriving with `zz-pop`.
    ///
    /// The name and the credit are drawn here rather than passed into
    /// ``RewardSticker``, which would otherwise set both inside its disc:
    /// its caption is `--text-strong` and disappears into the forest ground,
    /// and its credit strip is clipped away at the left and right of the
    /// circle — where a CC BY photographer's name must not be. Both are the
    /// component's to fix (#11); until then this screen keeps its attribution
    /// whole and legible.
    private var reward: some View {
        VStack(spacing: ZSpacing.step2) {
            RewardSticker(
                image: sticker?.image,
                size: isCompact ? RewardSticker.defaultSize : Self.regularSticker,
            )

            if let sticker {
                Text(verbatim: sticker.name)
                    .typeStyle(isCompact ? .body : .bodyLarge, .display, weight: .bold)
                    .foregroundStyle(ZColor.white)

                Text(verbatim: sticker.credit)
                    .typeStyle(.caption, .body, weight: .regular)
                    .foregroundStyle(ZColor.textOnColor)
            }
        }
        .accessibilityElement(children: .combine)
        .scaleEffect(settled ? 1 : Self.popFromScale)
        .opacity(settled ? 1 : 0)
        .animation(pop, value: settled)
    }

    /// The way on, and the door #29 opens.
    ///
    /// Side by side as in the design, stacked on a phone in portrait: the
    /// design's own row measures 220 + 24 + 260 pt, and no iPhone is that
    /// wide.
    @ViewBuilder
    private var actions: some View {
        let buttons = Group {
            // **Inert until #29.** The collection does not exist yet, so this
            // button has nothing to open. It is drawn all the same because
            // screen 1d has it and because a button that appears later moves
            // the one beside it — and it is drawn as itself, not disabled:
            // the child is not told about a milestone in the issue tracker.
            ZButton(String(localized: "roundEnd.collection"), tone: .reward, leadingIcon: .album) {}

            ZButton(
                String(localized: "roundEnd.playAgain"),
                trailingIcon: .arrowRight,
                action: startAnotherRound,
            )
        }

        if isCompact, !isShort {
            VStack(spacing: ZSpacing.step4) { buttons }
        } else {
            HStack(spacing: ZSpacing.step5) { buttons }
        }
    }

    /// The wordmark at the foot of screen 1d, at the smallest size it stays
    /// legible at — which is what the design's own 34 clamps to.
    ///
    /// The one piece of decoration here, and screen 1d is an iPad screen. A
    /// phone goes without: measured in the simulator the mark lands on
    /// "Nochmal spielen" in portrait, and in landscape every point of height
    /// belongs to the celebration.
    @ViewBuilder
    private var signature: some View {
        if showsSignature {
            Wordmark(size: Wordmark.minimumSize, tone: .monoLight)
                .padding(.bottom, ZSpacing.step5)
        }
    }

    private var showsSignature: Bool {
        !isCompact && !isShort
    }

    // MARK: - Values

    /// "Du hast zwei Sterne gesammelt" — through the catalog's plural rules,
    /// never assembled here from a number and a noun.
    private var starsEarned: String {
        String(format: String(localized: "roundEnd.stars"), result.stars)
    }

    private var starSize: CGFloat {
        isCompact ? ZSpacing.step7 : ZSpacing.step8
    }

    /// One bob, forever, offset so the three stars travel as a wave. Reduce
    /// Motion gets no animation, and without one nothing moves.
    private func bob(delayedBy delay: TimeInterval) -> Animation? {
        guard !reduceMotion else { return nil }
        return ZMotion.easeInOut.animation(duration: Self.bobPeriod / 2)
            .repeatForever(autoreverses: true)
            .delay(delay)
    }

    /// `zz-pop`: the sticker bounces in over `--dur-celebrate`. Reduce Motion
    /// gets none, and the sticker is at full size from the first frame.
    private var pop: Animation? {
        reduceMotion ? nil : ZMotion.easeBounce.animation(duration: ZMotion.celebrate)
    }

    // MARK: - Behaviour

    /// Starts the motion, resolves the sticker and says the headline out
    /// loud, once.
    ///
    /// The praise is spoken because the child this screen is for cannot read
    /// it. The guard is what makes it once: `onAppear` may run again, and the
    /// same sentence twice sounds like a fault.
    private func celebrate() {
        settled = true
        sticker = sticker ?? Sticker(species: result.celebratedSpecies, from: catalog)

        guard announcer == nil else { return }
        let voice = SpeechAnnouncer()
        announcer = voice
        voice.announce(String(localized: "roundEnd.title"))
    }

    /// Stops the praise before leaving, so that it does not run into the
    /// first question of the round that follows.
    private func startAnotherRound() {
        announcer?.stop()
        playAgain()
    }
}

/// What the sticker draws: one species of the round just played, resolved
/// from the pack.
private struct Sticker {
    let name: String
    /// `nil` when the photo file is missing — ``RewardSticker`` then shows its
    /// glyph, which is still a sticker.
    let image: Image?
    let credit: String

    /// - Returns: `nil` when there is no pack, no species, or the pack does
    ///   not know the id.
    init?(species: String?, from catalog: PackCatalog?) {
        guard
            let catalog,
            let species,
            let bird = catalog.pack.birds.first(where: { $0.id == species })
        else {
            return nil
        }

        name = bird.name
        image = catalog.photoURL(for: bird)
            .flatMap { UIImage(contentsOfFile: $0.path(percentEncoded: false)) }
            .map { Image(uiImage: $0) }
        credit = bird.creditLine
    }
}

// MARK: - Previews

#Preview("iPad, three stars", traits: .fixedLayout(width: 1194, height: 834)) {
    NavigationStack {
        RoundEndScreen(
            result: RoundResult(
                firstTryCorrect: 10,
                questionCount: 10,
                celebratedSpecies: "amsel",
            ),
            catalog: try? PackCatalog.bundled(),
            playAgain: {},
        )
    }
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("iPhone, one star", traits: .fixedLayout(width: 390, height: 844)) {
    NavigationStack {
        RoundEndScreen(
            result: RoundResult(
                firstTryCorrect: 3,
                questionCount: 10,
                celebratedSpecies: "rotkehlchen",
            ),
            catalog: try? PackCatalog.bundled(),
            playAgain: {},
        )
    }
    .environment(\.horizontalSizeClass, .compact)
}

#Preview("Without a pack", traits: .fixedLayout(width: 1194, height: 834)) {
    NavigationStack {
        RoundEndScreen(
            result: RoundResult(firstTryCorrect: 7, questionCount: 10, celebratedSpecies: nil),
            catalog: nil,
            playAgain: {},
        )
    }
    .environment(\.horizontalSizeClass, .regular)
}
