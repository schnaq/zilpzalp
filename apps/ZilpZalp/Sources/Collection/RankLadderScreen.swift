import SwiftUI
import ZilpZalpCore
import ZilpZalpData
import ZilpZalpUI

/// "Deine Vogel-Leiter" — screen 1i: all eight ranks, their thresholds, and
/// the one the child stands on.
///
/// The whole ladder at once, including the rungs far above. A child who can
/// see the Wiedehopf knows there is a Wiedehopf; hiding what is out of reach
/// would leave the collection ending wherever the child happens to be today.
///
/// Nothing here is stored. The rank comes out of `RankLadder` on every draw,
/// from the star count the profile carries.
struct RankLadderScreen: View {
    /// The rung's disc on an iPad, and in a compact width.
    private static let rungSize: CGFloat = 110
    private static let compactRungSize: CGFloat = 84

    /// How wide a rung's column may get before another one fits beside it.
    /// Eight rungs make one row on an iPad in landscape and two on a phone.
    private static let rungColumn: CGFloat = 150
    private static let compactRungColumn: CGFloat = 110

    /// The star count the ladder is read against.
    let stars: Int
    let photos: SpeciesPhotos
    let goBack: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private var current: Rank {
        RankLadder.rank(forStars: stars)
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
            } center: {
                Text("rank.ladder.title")
            }

            ScrollView {
                VStack(spacing: ZSpacing.step6) {
                    Badge(
                        String(format: String(localized: "collection.stars"), stars),
                        tone: .sun,
                        icon: .star,
                    )

                    rungs
                }
                .frame(maxWidth: ZSpacing.maxContent)
                .padding(.horizontal, isCompact ? ZSpacing.step4 : ZSpacing.gutterScreen)
                .padding(.vertical, ZSpacing.step6)
                .frame(maxWidth: .infinity)
            }
        }
        .background(ZColor.surfacePage)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
    }

    /// The eight rungs, easiest first — the order `Rank.allCases` is declared
    /// in, which is also the order the thresholds rise in.
    private var rungs: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(minimum: isCompact ? Self.compactRungColumn : Self.rungColumn),
                    spacing: ZSpacing.gapTiles,
                    alignment: .top,
                ),
            ],
            spacing: ZSpacing.gapTiles,
        ) {
            ForEach(Rank.allCases, id: \.self) { rank in
                RankRung(
                    rank: rank,
                    photo: photos[rank.rawValue],
                    reached: stars >= rank.threshold,
                    current: rank == current,
                    size: isCompact ? Self.compactRungSize : Self.rungSize,
                )
            }
        }
    }
}

// MARK: - Previews

#Preview("iPad, on the third rung", traits: .fixedLayout(width: 1194, height: 834)) {
    NavigationStack {
        RankLadderScreen(stars: 72, photos: SpeciesPhotos(try? .bundled()), goBack: {})
    }
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("iPhone, at the start", traits: .fixedLayout(width: 390, height: 844)) {
    NavigationStack {
        RankLadderScreen(stars: 4, photos: SpeciesPhotos(try? .bundled()), goBack: {})
    }
    .environment(\.horizontalSizeClass, .compact)
}
