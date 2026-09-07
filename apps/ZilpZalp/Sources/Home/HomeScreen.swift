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
struct HomeScreen: View {
    /// The wordmark's size in the top bar, from `HomeScreen.jsx`. In a compact
    /// width it drops to the wordmark's own floor.
    private static let wordmarkSize: CGFloat = 44

    let openGame: (Game) -> Void
    let openParents: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Whether the screen is in a compact width — a phone in portrait, or an
    /// iPad sharing its screen. It settles the two type sizes only; where the
    /// tiles go is measured rather than categorised, see ``tiles(in:)``.
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
                // estimate. That is what keeps both games on screen at once
                // from a 375 pt iPhone up, with no scroll view.
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

    /// The two games, side by side or stacked — whichever arrangement the
    /// space makes the tiles bigger in.
    ///
    /// One rule, no cases: an iPad ends up in a row in either orientation, an
    /// iPhone stacks in portrait and rows in landscape, an iPad in Slide Over
    /// stacks. Bigger tiles are the whole goal — they are what a
    /// four-year-old aims at.
    private func tiles(in area: CGSize) -> some View {
        let inARow = tileSize(in: area, sideBySide: true)
        let stacked = tileSize(in: area, sideBySide: false)
        let sideBySide = inARow >= stacked
        let size = sideBySide ? inARow : stacked
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
        // `HomeTile` draws its label at a fixed 22 pt whatever edge length it
        // is given, so a tile the space forces down far enough turns "Wer
        // singt da?" into "Wer singt d…" — measured on an iPhone SE, which is
        // the shortest screen the app supports. Letting the label shrink keeps
        // the words whole, and the floor is the design's own: nothing a child
        // reads goes below 20 pt.
        //
        // The tile scales its glyph off its own size already; scaling the
        // label belongs there too, and this modifier belongs in the bin the
        // day #12's component does it.
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

    /// A screen title is `display-2` in the design. In a compact width it
    /// steps down to `headline`: every point the title gives back goes into
    /// the tiles, and on the shortest supported screen that is what keeps both
    /// games visible at a size their labels still fit.
    private var titleStep: ZType.Step {
        isCompact ? .headline : .display2
    }

    /// One tile's edge length: the design's grid cell, and smaller only where
    /// the space cannot hold it — a phone in landscape, an iPad in Slide Over.
    ///
    /// Never below the 64 pt touch floor, even where that means overflowing the
    /// space: a tile a four-year-old cannot hit breaks a rule the design calls
    /// non-negotiable, and a few points of overhang does not. No supported
    /// device gets anywhere near it — the floor is here so that none ever can.
    private func tileSize(in area: CGSize, sideBySide: Bool) -> CGFloat {
        let across = sideBySide ? (area.width - ZSpacing.gapTiles) / 2 : area.width
        let down = sideBySide ? area.height : (area.height - ZSpacing.gapTiles) / 2
        let fitting = min(HomeTile.defaultSize, across, down).rounded(.down)
        return max(ZSpacing.touchMinimum, fitting)
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
