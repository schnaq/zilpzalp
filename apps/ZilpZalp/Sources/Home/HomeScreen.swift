import SwiftUI
import ZilpZalpUI

/// Where every session starts: the headline, and one tile per game.
///
/// Deliberately not the tree from `design/ui_kits/ipad_app/HomeScreen.jsx`.
/// Christian dropped it on 2026-09-07 — the metaphor did not come across —
/// together with the locked nests for games 3 and 4. Those two games are out
/// of v1 for want of freely licensed material (spec §1), and nobody can say
/// what a child would be waiting for, so they are absent rather than teased.
/// Two games, two tiles, the plain page ground.
///
/// The screen holds no state. It reports which game was tapped and when the
/// grown-ups' door was opened; where those lead is ``RootView``'s business.
///
/// `@MainActor` on the type rather than on `body` alone: `HomeTile.defaultSize`
/// is main-actor isolated because `HomeTile` is a `View`, and the helpers below
/// reach for it.
@MainActor
struct HomeScreen: View {
    /// The wordmark's size in the top bar. `HomeScreen.jsx` sets 44; on a
    /// phone it drops to the wordmark's own floor.
    private static let wordmarkSize: CGFloat = 44

    let openGame: (Game) -> Void
    let openParents: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBar {
                Wordmark(size: isCompact ? Wordmark.minimumSize : Self.wordmarkSize)
            } trailing: {
                IconButton(
                    .userRoundCog,
                    label: String(localized: "parents.title"),
                    tone: .clay,
                    diameter: ZSpacing.touchMinimum,
                    action: openParents,
                )
            }

            VStack(spacing: ZSpacing.step6) {
                headline

                // The reader reports exactly what the headline left over, so
                // the tiles are sized against real space rather than an
                // estimate — and both games are on screen at once on every
                // device, without a scroll view and without a device check.
                GeometryReader { area in
                    tiles(in: area.size)
                }
            }
            .frame(maxWidth: ZSpacing.maxContent)
            .padding(.horizontal, ZSpacing.gutterScreen)
            .padding(.vertical, ZSpacing.step6)
            .frame(maxWidth: .infinity)
        }
        .background(ZColor.surfacePage)
    }

    private var headline: some View {
        Text("home.title")
            .font(titleStep.font(.display, weight: .extraBold))
            .lineSpacing(titleStep.lineSpacing)
            .foregroundStyle(ZColor.textStrong)
            .multilineTextAlignment(.center)
    }

    /// The two games, side by side in a wide space and stacked in a tall one.
    ///
    /// The shape of the space decides, not the device: an iPad in Slide Over
    /// stacks, an iPhone in landscape puts them in a row, and neither case
    /// needs a rule of its own.
    private func tiles(in area: CGSize) -> some View {
        let sideBySide = area.width >= area.height
        let size = tileSize(in: area, sideBySide: sideBySide)
        let arrangement = sideBySide
            ? AnyLayout(HStackLayout(spacing: ZSpacing.gapTiles))
            : AnyLayout(VStackLayout(spacing: ZSpacing.gapTiles))

        // No stars: nothing is stored in M3 — earned stars arrive with the
        // progress persistence (#27) — and a filled slot the app cannot
        // remember would be a lie told to a four-year-old.
        return arrangement {
            tile(.names, icon: .bird, tone: .hoopoe, size: size)
            tile(.calls, icon: .volume2, tone: .leaf, size: size)
        }
        // `HomeTile` sizes its label off the tile, so on a small screen the
        // tile shrinks until "Wer singt da?" would read "Wer singt d…". A
        // second line and a little shrinking keep the words whole instead, and
        // the floor is the design's own: nothing a child reads goes below
        // 20 pt.
        .minimumScaleFactor(ZType.Step.body.size / ZType.Step.label.size)
        .frame(width: area.width, height: area.height)
    }

    private func tile(
        _ game: Game,
        icon: ZIcon,
        tone: HomeTile.Tone,
        size: CGFloat,
    ) -> some View {
        HomeTile(
            title: game.title,
            icon: icon,
            tone: tone,
            size: size,
            action: { openGame(game) },
        )
    }

    /// A screen title is `display-2` in the design. On a phone it steps down
    /// to `headline`: every point the headline gives back goes into the tiles,
    /// and on the shortest supported screen that is what keeps both games
    /// visible at a size their labels still fit.
    private var titleStep: ZType.Step {
        isCompact ? .headline : .display2
    }

    /// One tile's edge length: the design's grid cell, and smaller only where
    /// the space cannot hold it — a phone in landscape, an iPad in Slide Over.
    private func tileSize(in area: CGSize, sideBySide: Bool) -> CGFloat {
        let across = sideBySide ? (area.width - ZSpacing.gapTiles) / 2 : area.width
        let down = sideBySide ? area.height : (area.height - ZSpacing.gapTiles) / 2
        return max(0, min(HomeTile.defaultSize, across, down).rounded(.down))
    }
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
