import SwiftUI
import ZilpZalpUI

/// The tree with the activity nests — where every session starts.
///
/// Ported from `design/ui_kits/ipad_app/HomeScreen.jsx`. Two nests are open,
/// two are eggs that have not hatched: games 3 and 4 are out of v1 for want of
/// freely licensed material (spec §1). They stay on the tree because hiding
/// them would make the app look smaller than it is without making the wait any
/// shorter.
///
/// The screen holds no state. It reports which nest was tapped and when the
/// grown-ups' door was opened; where those lead is ``RootView``'s business.
///
/// `@MainActor` on the type rather than on `body` alone: ``HomeLayout`` reads
/// `HomeTile.defaultSize`, which is main-actor isolated because `HomeTile` is
/// a `View`, and the helpers below all reach for that layout.
@MainActor
struct HomeScreen: View {
    let openGame: (Game) -> Void
    let openParents: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var layout: HomeLayout {
        horizontalSizeClass == .compact ? .compact : .spacious
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBar {
                Wordmark(size: layout.wordmarkSize)
            } trailing: {
                IconButton(
                    .userRoundCog,
                    label: String(localized: "parents.title"),
                    tone: .clay,
                    diameter: ZSpacing.touchMinimum,
                    action: openParents,
                )
            }

            ScrollView {
                VStack(spacing: ZSpacing.step6) {
                    Text("home.title")
                        .font(layout.titleStep.font(.display, weight: .extraBold))
                        .lineSpacing(layout.titleStep.lineSpacing)
                        .foregroundStyle(ZColor.textStrong)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    tree
                }
                .frame(maxWidth: ZSpacing.maxContent)
                .padding(.horizontal, layout.gutter)
                .padding(.vertical, ZSpacing.step5)
                .frame(maxWidth: .infinity)
            }
        }
        .background(HomeLayout.sky)
    }

    // MARK: - The tree

    /// Trunk, two branches and the four nests. Plain blocks rather than
    /// artwork: the home tree is still a stand-in (`design/readme.md`, "Known
    /// gaps"), and a wrong illustration would be harder to replace than none.
    private var tree: some View {
        VStack(spacing: layout.rowGap) {
            branch {
                nest(.names, icon: .bird, tone: .hoopoe)
                nest(.calls, icon: .volume2, tone: .leaf)
            }
            branch {
                lockedNest
                lockedNest
            }
        }
        .padding(.bottom, layout.trunkFoot)
        .background(alignment: .bottom) { trunk }
        .frame(maxWidth: .infinity)
    }

    /// One row of nests, sitting on a branch.
    private func branch(@ViewBuilder nests: () -> some View) -> some View {
        HStack(spacing: ZSpacing.gapTiles) { nests() }
            .background(alignment: .bottom) {
                Capsule()
                    .fill(ZColor.bark500)
                    .frame(height: layout.branchThickness)
                    // Slid down until its centre line meets the bottom of the
                    // tiles' ledges, so the nests sit on the branch rather
                    // than float over it.
                    .offset(y: layout.branchThickness / 2 + ZShadow.ledgeLargeOffset)
            }
    }

    private var trunk: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: layout.trunkWidth / 2,
            topTrailingRadius: layout.trunkWidth / 2,
            style: .continuous,
        )
        .fill(ZColor.bark500)
        .frame(width: layout.trunkWidth)
        // Starts halfway up the first row: the crown then rises between the
        // two upper nests instead of above them.
        .padding(.top, layout.tile / 2)
    }

    // MARK: - The nests

    /// A nest with no stars yet. Nothing is stored in M3 — earned stars arrive
    /// with the progress persistence (#27) — and a filled slot the app cannot
    /// remember would be a lie told to a four-year-old.
    private func nest(_ game: Game, icon: ZIcon, tone: HomeTile.Tone) -> some View {
        HomeTile(
            title: game.title,
            icon: icon,
            tone: tone,
            size: layout.tile,
            action: { openGame(game) },
        )
    }

    private var lockedNest: some View {
        HomeTile(
            title: String(localized: "home.locked.comingSoon"),
            locked: true,
            size: layout.tile,
        )
    }
}

/// The home screen at its two widths.
///
/// Picked by horizontal size class, never by device: an iPad in a narrow split
/// view is compact and gets the compact tree, and no code has to ask what
/// hardware it is running on. The numbers without a token are the ones
/// `HomeScreen.jsx` names.
@MainActor
private struct HomeLayout {
    /// A soft sky → cream → meadow gradient, the one decorative gradient the
    /// design allows and only on this screen.
    static let sky = LinearGradient(
        stops: [
            .init(color: ZColor.orange50, location: 0),
            .init(color: ZColor.cream100, location: 0.46),
            .init(color: ZColor.olive100, location: 1),
        ],
        startPoint: .top,
        endPoint: .bottom,
    )

    let tile: CGFloat
    let gutter: CGFloat
    let rowGap: CGFloat
    let branchThickness: CGFloat
    let trunkWidth: CGFloat
    /// How far the trunk runs on below the lower branch.
    let trunkFoot: CGFloat
    let wordmarkSize: CGFloat
    let titleStep: ZType.Step

    /// The design's reference, iPad landscape 1194×834.
    ///
    /// The row gap is 32 rather than the JSX's 40: at 40 the tree needs more
    /// height than an 834 pt iPad has under the top bar, and a home screen
    /// that scrolls on the reference device is a home screen with a mistake
    /// in it.
    static let spacious = HomeLayout(
        tile: HomeTile.defaultSize,
        gutter: ZSpacing.gutterScreen,
        rowGap: ZSpacing.step6,
        branchThickness: 34,
        trunkWidth: 92,
        trunkFoot: ZSpacing.step7,
        wordmarkSize: 44,
        titleStep: .display2,
    )

    /// iPhone portrait, 390×844 — and 375 pt wide on the smallest supported
    /// iPhone, which is what sets the tile size: two 150 pt nests, a 24 pt gap
    /// and a 16 pt gutter on each side come to 356 pt.
    static let compact = HomeLayout(
        tile: 150,
        gutter: ZSpacing.step4,
        rowGap: ZSpacing.step5,
        branchThickness: 20,
        trunkWidth: 56,
        trunkFoot: ZSpacing.step6,
        wordmarkSize: Wordmark.minimumSize,
        titleStep: .title,
    )
}

// MARK: - Previews

#Preview("iPad landscape", traits: .fixedLayout(width: 1194, height: 834)) {
    HomeScreen(openGame: { _ in }, openParents: {})
        .environment(\.horizontalSizeClass, .regular)
}

#Preview("iPhone portrait", traits: .fixedLayout(width: 390, height: 844)) {
    HomeScreen(openGame: { _ in }, openParents: {})
        .environment(\.horizontalSizeClass, .compact)
}
