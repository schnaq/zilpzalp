import SwiftUI
import ZilpZalpCore
import ZilpZalpUI

/// "Du bist jetzt eine Amsel!" — screen 1e, the moment a round carries a child
/// over a threshold.
///
/// Reached from the round end and only then: the ascent is about the round
/// just played, and there is no other way to arrive at one.
///
/// **The design draws 1e *instead of* 1d; this app pushes it *after*.** #26
/// built the round end as its own screen, and a rank that replaced the stars
/// would take the stars away on the one round that earned the most of them.
/// So the celebration is two beats — what the round earned, then what it
/// changed — and the three bobbing stars of the design's 1e are left out here
/// because the screen underneath has just shown them.
///
/// Nothing is written down on this screen. The round was booked before it was
/// pushed; the rank is `RankLadder.rank(forStars:)` of what was written.
struct RankAscentScreen: View {
    /// The hero sticker, the 200 pt of screen 1e.
    private static let heroSticker: CGFloat = 200
    private static let compactHeroSticker: CGFloat = 140

    /// The three rungs of the path underneath it, small enough that the hero
    /// stays the hero.
    private static let pathRung: CGFloat = 80
    private static let compactPathRung: CGFloat = 64

    /// Where `zz-pop` starts the sticker, as on the round end.
    private static let popFromScale: CGFloat = 0.6

    /// How tall the progress pill is, and how wide it may get. From 1e, which
    /// draws it as a wide bar under the path rather than a full-width rule.
    private static let barHeight: CGFloat = ZSpacing.step4
    private static let barWidth: CGFloat = 420

    let ascent: RankAscent
    let photos: SpeciesPhotos
    /// Back to the round end, from the top bar and from "Weiter".
    let goBack: () -> Void
    /// The whole ladder, from the three rungs of the path.
    let openLadder: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Flipped on appearance so the new rank's sticker pops in. With Reduce
    /// Motion on there is no animation and it is simply there.
    @State private var settled = false

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    /// A phone in landscape. The same reasoning as on the round end: the two
    /// biggest iPhones report a regular width there and a phone's height.
    private var isTight: Bool {
        isCompact || verticalSizeClass == .compact
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBar {
                IconButton(
                    .chevronLeft,
                    label: String(localized: "nav.back.accessibility"),
                    diameter: ZSpacing.touchMinimum,
                    action: goBack,
                )
            }

            ScrollView {
                VStack(spacing: isTight ? ZSpacing.step4 : ZSpacing.step6) {
                    hero
                    headline
                    path
                    progress
                    ZButton(
                        String(localized: "rank.ascent.continue"),
                        trailingIcon: .arrowRight,
                        action: goBack,
                    )
                }
                .multilineTextAlignment(.center)
                .frame(maxWidth: ZSpacing.maxContent)
                .padding(.horizontal, isCompact ? ZSpacing.step4 : ZSpacing.gutterScreen)
                .padding(.vertical, ZSpacing.step6)
                .frame(maxWidth: .infinity)
            }
        }
        .background(ZColor.surfacePage)
        .toolbar(.hidden, for: .navigationBar)
        // The second beat of a celebration is left on purpose or not at all:
        // the chevron and "Weiter" go back, a swipe does not. #150 names this
        // screen with the round end and "Zeit fürs Nest".
        .swipesBack(.disabled)
        .readAloudOnce(ascent.reached.ascentSentence)
        .onAppear { settled = true }
    }

    /// The bird of the rank just reached, arriving with `zz-pop`.
    private var hero: some View {
        RewardSticker(
            image: photos[ascent.reached.rawValue],
            icon: .bird,
            size: isTight ? Self.compactHeroSticker : Self.heroSticker,
        )
        .scaleEffect(settled ? 1 : Self.popFromScale)
        .opacity(settled ? 1 : 0)
        .animation(pop, value: settled)
        .accessibilityHidden(true)
    }

    private var headline: some View {
        Text(verbatim: ascent.reached.ascentSentence)
            .typeStyle(isTight ? .headline : .display2, .display, weight: .extraBold)
            .foregroundStyle(ZColor.textStrong)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Where the step sits on the ladder: the rung left behind, the one
    /// reached, and the one after it. The whole row opens the full ladder —
    /// a child taps the picture, not a word it cannot read.
    private var path: some View {
        Button(action: openLadder) {
            HStack(alignment: .top, spacing: ZSpacing.step3) {
                ForEach(pathRanks, id: \.self) { rank in
                    RankRung(
                        rank: rank,
                        photo: photos[rank.rawValue],
                        reached: ascent.stars >= rank.threshold,
                        current: rank == ascent.reached,
                        size: isTight ? Self.compactPathRung : Self.pathRung,
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "rank.ladder.title"))
    }

    /// How far the next rung still is: the bar of 1e and the sentence under
    /// it. Absent on the top rung, where there is nothing left to miss.
    @ViewBuilder
    private var progress: some View {
        if let missing = RankLadder.starsMissing(from: ascent.stars),
           let next = RankLadder.next(after: ascent.reached)
        {
            VStack(spacing: ZSpacing.step3) {
                Capsule()
                    .fill(ZColor.sand200)
                    .frame(maxWidth: Self.barWidth)
                    .frame(height: Self.barHeight)
                    .overlay(alignment: .leading) {
                        GeometryReader { bar in
                            Capsule()
                                .fill(ZColor.reward)
                                .frame(width: bar.size.width * fraction(toward: next))
                        }
                    }
                    .clipShape(Capsule())

                Text(verbatim: next.starsMissing(missing))
                    .typeStyle(.body, .body, weight: .bold)
                    .foregroundStyle(ZColor.textBody)
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// The three rungs of the path. The rung above is dropped on the top rank,
    /// where there is none.
    private var pathRanks: [Rank] {
        [ascent.from, ascent.reached] + (RankLadder.next(after: ascent.reached).map { [$0] } ?? [])
    }

    /// How much of the way from this rung to the next one is behind the child.
    ///
    /// Measured from the rung actually stood on, not from zero: a bar that ran
    /// from the first star of all would barely move in the stretch between two
    /// thresholds, which is the only stretch this screen is about.
    private func fraction(toward next: Rank) -> CGFloat {
        let span = next.threshold - ascent.reached.threshold
        guard span > 0 else { return 1 }
        let walked = ascent.stars - ascent.reached.threshold
        return min(max(CGFloat(walked) / CGFloat(span), 0), 1)
    }

    private var pop: Animation? {
        reduceMotion ? nil : ZMotion.easeBounce.animation(duration: ZMotion.celebrate)
    }
}

// MARK: - Previews

#Preview("iPad", traits: .fixedLayout(width: 1194, height: 834)) {
    NavigationStack {
        RankAscentScreen(
            ascent: RankAscent(from: .kohlmeise, reached: .amsel, stars: 27),
            photos: SpeciesPhotos(try? .bundled()),
            goBack: {},
            openLadder: {},
        )
    }
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("iPhone", traits: .fixedLayout(width: 390, height: 844)) {
    NavigationStack {
        RankAscentScreen(
            ascent: RankAscent(from: .rotkehlchen, reached: .star, stars: 152),
            photos: SpeciesPhotos(try? .bundled()),
            goBack: {},
            openLadder: {},
        )
    }
    .environment(\.horizontalSizeClass, .compact)
}
