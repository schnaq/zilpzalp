import SwiftUI
import ZilpZalpData
import ZilpZalpUI

/// The end of a round: three stars, a bird to keep, and the way back into a
/// new round. Screen 1d and `design/ui_kits/ipad_app/RewardScreen.jsx`.
///
/// **Celebration without competition.** The screen shows what was met and
/// what was earned, and nothing else: no percentage, no error count, no time,
/// nothing that measures this round against another one or against another
/// child. The three stars are always all three — the earned ones filled, the
/// rest hollow — because one star has to read as an achievement rather than as
/// two missing ones, and a child who cannot read has only the picture to go
/// by. The praise is spoken for the same reason.
///
/// **This is where a round is written down.** The screen books it through
/// ``AppModel/record(_:)`` before it says anything about it, and every claim
/// it makes — a first find, a new rank — is read off the profile written.
struct RoundEndScreen: View {
    /// Where `zz-pop` starts the sticker: a little under full size rather than
    /// at nothing, so it lands instead of exploding.
    private static let popFromScale: CGFloat = 0.6

    /// The sticker on iPad, the 200 pt of screen 1e and `RewardScreen.jsx`.
    private static let regularSticker: CGFloat = 200

    /// The strip at the foot that belongs to the wordmark, so the
    /// celebration is centred in what is left rather than behind it.
    private static let signatureBand = Wordmark.minimumSize + 2 * ZSpacing.step5

    /// How long the celebration keeps the screen before the rank ascent
    /// arrives over it: long enough for the sticker to land and the praise to
    /// be said, short enough to still read as one moment. A judgement call
    /// rather than a token — 1e replaces this screen in the design.
    private static let ascentDelay: TimeInterval = 2.2

    /// What the round earned. Comes from ``QuizSession`` through
    /// ``Route/roundEnd(_:)``; nothing here recomputes it.
    let result: RoundResult

    /// The pack the round was drawn from, for the sticker's photo, name and
    /// credit. Optional because ``RootView`` holds it optionally; without it
    /// the sticker falls back to its star glyph rather than to a hole.
    let catalog: PackCatalog?

    /// Books the round onto the playing child and answers with what it
    /// changed, `nil` when nothing was written. Idempotent; see
    /// ``AppModel/record(_:)``.
    let record: (RoundResult) async -> RoundOutcome?

    /// The way on: a pop back to ``QuizScreen``, or "Zeit fürs Nest" once the
    /// day's budget is spent (#36). Which of the two is the shell's to decide.
    let playAgain: () -> Void

    /// Opens the sticker album, and pushes the rank ascent over this screen.
    let openCollection: () -> Void
    let showAscent: (RankAscent) -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Flipped once on appearance to start the bob and the pop.
    ///
    /// With Reduce Motion on the pop is `nil`, so the flip only puts the
    /// sticker at full size: nothing moves, and nothing is left half-drawn.
    /// The stars keep that promise themselves — see ``RoundEndStars``.
    @State private var settled = false

    /// The bird on the sticker, resolved once: a `View` is built again on
    /// every layout pass, and reading the photo off disk on each of them
    /// would be a file lookup per frame of the pop.
    @State private var sticker: RoundEndSticker?

    /// The praise, spoken. Built once, so no second synthesiser can talk
    /// over the first.
    @State private var announcer: SpeechAnnouncer?

    /// What the round changed about the profile, once booked. `nil` for the
    /// frame before that, and for a round that could not be written — the
    /// screen then makes no claim it cannot back up.
    @State private var outcome: RoundOutcome?

    /// The ascent has been pushed for this round. `.task` runs again when
    /// the child comes back from the album, and a second "Du bist jetzt eine
    /// Amsel!" would be a second promotion.
    @State private var ascentShown = false

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

    /// Narrow or short — either way there is no room for the iPad's sizes.
    /// Width alone is not enough: the two biggest iPhones report a *regular*
    /// width in landscape, where the height is still a phone's, and keying
    /// the sizes on width put a hero line into 430 pt of height there.
    private var isTight: Bool {
        isCompact || isShort
    }

    /// The step the praise is set in: the design's `--text-hero` where the
    /// screen has an iPad to itself, one step down where it has not.
    private var titleStep: ZType.Step {
        isTight ? .display2 : .hero
    }

    /// How far the praise may shrink before it would rather break: never
    /// below `--text-title`, whichever step it was set in.
    ///
    /// A guard, not a target — the one ``TopBarTitle`` carries, for the same
    /// reason. "Super gemacht!" measures 7.149 times the type size in the
    /// bundled Baloo 2 ExtraBold (CoreText), so 343.2 pt at `--text-display-2`.
    /// A 390 pt phone leaves 342 pt between the screen's two `--space-5`
    /// paddings: 1.2 pt short, and that is the whole of #137 — the 402 pt
    /// iPhone 17 has 354 pt and shows the line whole. SwiftUI truncates it
    /// there rather than wrapping: the column hands the line the ideal height
    /// it asks for, and that is one line's. It *can* wrap — a `.fixedSize`
    /// puts "gemacht!" on a second line — but two headlines push the sticker
    /// and both buttons down, and screen 1d draws one.
    ///
    /// What it spends: 0.997 at 390 pt, 0.953 at the 375 pt of an iPhone SE.
    /// A full-screen iPad never reaches it — `--text-hero` asks for 629.1 pt
    /// and the narrowest iPad in portrait, the mini's 744, leaves 648 pt —
    /// but an iPad sharing its screen does: half of a 13" in landscape is
    /// 678 pt, still a regular width, and the hero line shrinks to 0.925.
    private var titleScaleFloor: CGFloat {
        ZType.Step.title.size / titleStep.size
    }

    var body: some View {
        celebration
            .multilineTextAlignment(.center)
            // The strip the wordmark stands in, kept clear rather than drawn
            // over: an overlay at the foot of a centred column sits on the
            // buttons as soon as the screen is short, which on an iPad in
            // landscape it is.
            .padding(.bottom, showsSignature ? Self.signatureBand : 0)
            .padding(isTight ? ZSpacing.step5 : ZSpacing.gutterScreen)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ZColor.surfaceForest)
            .overlay(alignment: .bottom) { signature }
            // No `TopBar`: screen 1d has none, and a finished round is
            // nothing to go back into — "Nochmal spielen" is the way on. The
            // bar is hidden like everywhere else in this app, and the swipe
            // from the edge is turned down in so many words rather than left
            // to follow from that (#150).
            .toolbar(.hidden, for: .navigationBar)
            .swipesBack(.disabled)
            // A `Task` rather than `onAppear`: the round is written down
            // before anything is said about it, and writing is `await`. Its
            // cancellation is what stops the ascent from arriving behind a
            // child who has already tapped on.
            .task { await celebrate() }
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

    /// The three stars, bobbing — see ``RoundEndStars``.
    private var stars: some View {
        RoundEndStars(earned: result.stars, size: starSize, raised: settled)
    }

    private var praise: some View {
        VStack(spacing: ZSpacing.step3) {
            Text("roundEnd.title")
                .typeStyle(titleStep, .display, weight: .extraBold)
                // One line, shrunk to fit rather than cut off — see
                // ``titleScaleFloor``. The praise is the one sentence a child
                // who cannot read is meant to have read out to them, and a
                // headline that ends in an ellipsis is not that sentence.
                // Deliberately not `typeStyle(singleLine:)`, which would give
                // the line the design's 52.8 pt box instead of Baloo 2's own
                // 76.9 pt one and lift the celebration under it; the two
                // modifiers below are what ``TopBarTitle`` uses instead.
                .lineLimit(1)
                .minimumScaleFactor(titleScaleFloor)
                .foregroundStyle(ZColor.white)

            Text(verbatim: starsEarned)
                .typeStyle(isTight ? .body : .bodyLarge, .body, weight: .bold)
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
                size: isTight ? RewardSticker.defaultSize : Self.regularSticker,
            )

            if let sticker {
                Text(verbatim: caption(for: sticker))
                    .typeStyle(isTight ? .body : .bodyLarge, .display, weight: .bold)
                    .foregroundStyle(ZColor.white)

                Text(verbatim: sticker.credit)
                    .typeStyle(.caption, .body, weight: .regular)
                    .foregroundStyle(ZColor.textOnColor)
            }
        }
        .accessibilityElement(children: .combine)
        .scaleEffect(popped ? 1 : Self.popFromScale)
        .opacity(popped ? 1 : 0)
        .animation(pop, value: settled)
    }

    /// The pop belongs to a bird met for the first time. One already in the
    /// album is simply there: still shown, still named, but the arrival is
    /// the reward for finding something new.
    private var popped: Bool {
        settled || !isFirstFind
    }

    /// The way on first, the album second (#119): a child who can read
    /// neither label tells the two apart by position and colour, so the
    /// sun-yellow one at the top must be the one that carries the round on.
    ///
    /// Side by side as in the design, stacked on a phone in portrait — the
    /// design's row measures 220 + 24 + 260 pt, and no iPhone is that wide.
    @ViewBuilder
    private var actions: some View {
        let buttons = Group {
            ZButton(
                String(localized: "roundEnd.playAgain"),
                tone: .reward,
                trailingIcon: .arrowRight,
                action: startAnotherRound,
            )

            ZButton(
                String(localized: "roundEnd.collection"),
                leadingIcon: .album,
                action: openCollection,
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

    /// "Du hast einen Stern gesammelt" — through the catalog's plural rules,
    /// never assembled here from a number and a noun.
    ///
    /// A review read this as always resolving the `other` variant, which is
    /// what `String(format: String(localized:), _:)` used to do. On the
    /// toolchain `mise.toml` pins it does not: both categories were checked on
    /// a device, one star renders "einen Stern" and two render "2 Sterne". If
    /// that ever changes, the symptom is the German "1 Sterne" — and the fix
    /// is `String.localizedStringWithFormat`, not two keys.
    private var starsEarned: String {
        String(format: String(localized: "roundEnd.stars"), result.stars)
    }

    /// Whether the round put this bird in the album for the first time: read
    /// off the profile as it stood before the round was booked. `false` until
    /// then — one frame of silence beats a claim that was not checked.
    private var isFirstFind: Bool {
        outcome?.isFirstFind(of: result.celebratedSpecies) ?? false
    }

    /// "Amsel gesammelt" for a first find, the bare name otherwise.
    private func caption(for sticker: RoundEndSticker) -> String {
        guard isFirstFind else { return sticker.name }
        return String(format: String(localized: "roundEnd.sticker.new"), sticker.name)
    }

    /// The one sentence this screen says out loud, for the child who cannot
    /// read it. A first find gets its own, so the news is heard as well.
    private var spokenPraise: String {
        guard isFirstFind, let sticker else { return String(localized: "roundEnd.title") }
        return String(format: String(localized: "roundEnd.sticker.new.spoken"), sticker.name)
    }

    private var starSize: CGFloat {
        isTight ? ZSpacing.step7 : ZSpacing.step8
    }

    /// `zz-pop`: the sticker bounces in over `--dur-celebrate`. Reduce Motion
    /// gets none, and the sticker is at full size from the first frame.
    private var pop: Animation? {
        reduceMotion ? nil : ZMotion.easeBounce.animation(duration: ZMotion.celebrate)
    }

    // MARK: - Behaviour

    /// Books the round, then celebrates it: the sticker, the motion, the
    /// sentence said out loud, and — when the round carried the child onto a
    /// new rung — the ascent over the top of it.
    ///
    /// The order matters. Being a first find decides both the caption and the
    /// sentence, so nothing is drawn as new before the profile is written.
    /// The guards are what make each part happen once: this runs again every
    /// time the child comes back from the album.
    private func celebrate() async {
        sticker = sticker ?? RoundEndSticker(species: result.celebratedSpecies, from: catalog)
        outcome = await record(result)
        // Left while the round was being written down: the praise would
        // land over whatever replaced this screen.
        guard !Task.isCancelled else { return }
        settled = true

        if announcer == nil {
            let voice = SpeechAnnouncer()
            announcer = voice
            voice.announce(spokenPraise)
        }

        guard !ascentShown, let ascent = outcome?.ascent else { return }
        // The stars and the sticker get the screen to themselves first: a new
        // rank on top of the praise would take the round away mid-look.
        try? await Task.sleep(for: .seconds(Self.ascentDelay))
        // Flagged only once it is shown: set before the wait, a child who
        // opened the album inside those seconds would have turned "once"
        // into "never".
        guard !Task.isCancelled else { return }
        ascentShown = true
        showAscent(ascent)
    }

    /// Stops the praise before leaving, so that it does not run into the
    /// first question of the round that follows.
    private func startAnotherRound() {
        announcer?.stop()
        playAgain()
    }
}
