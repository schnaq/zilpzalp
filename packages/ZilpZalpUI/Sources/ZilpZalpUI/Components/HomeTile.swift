import SwiftUI

/// A nest on the home tree: one activity, one tap.
///
/// Ported from `design/components/navigation/HomeTile.jsx`. The tile is a
/// large, square pressable that sits on a solid ledge of its own tone and
/// presses down onto it — a plastic toy button, not a flat rectangle.
///
/// It knows nothing about games, ranks or progress. It takes a title, a
/// glyph, a tone, a number of earned stars and whether it is open yet; what
/// those stand for is the screen's business. A locked tile shows an egg
/// waiting to hatch — never a padlock, never a wall.
///
/// Accessibility: the button's label is ``title``, which is why the title is
/// required rather than optional. The stars are deliberately not announced —
/// saying "two of three stars" would need a sentence, and this package holds
/// no product strings. A screen that wants them spoken attaches its own
/// `accessibilityValue`.
public struct HomeTile: View {
    /// The four tile tones from the JSX. Each is a background, an edge and a
    /// foreground drawn from one ramp, so a tile is always monochrome-warm.
    ///
    /// Every field names the same custom property the JSX names, semantic
    /// alias or ramp entry. `ZColor.primarySoft` is the same colour as
    /// `olive100` and `ZColor.reward` the same as `sun400`, but substituting
    /// them would claim a role the tile does not have: a tone is a tint, not
    /// a primary surface and not a reward.
    public enum Tone: Sendable, Hashable, CaseIterable {
        /// Meadow olive — the primary tone.
        case leaf
        /// Feather clay.
        case clay
        /// Sun yellow.
        case sun
        /// The hoopoe's crest orange.
        case hoopoe

        var palette: HomeTilePalette {
            switch self {
            case .leaf:
                HomeTilePalette(
                    background: ZColor.olive100,
                    edge: ZColor.primary,
                    foreground: ZColor.olive700,
                )
            case .clay:
                HomeTilePalette(
                    background: ZColor.clay100,
                    edge: ZColor.info,
                    foreground: ZColor.clay700,
                )
            case .sun:
                HomeTilePalette(
                    background: ZColor.sun200,
                    edge: ZColor.sun400,
                    foreground: ZColor.sun600,
                )
            case .hoopoe:
                HomeTilePalette(
                    background: ZColor.orange100,
                    edge: ZColor.accent,
                    foreground: ZColor.orange700,
                )
            }
        }
    }

    /// The JSX default and the home screen's grid cell. Public because a
    /// screen laying out the tree needs the same number for its columns.
    public static let defaultSize: CGFloat = 240

    let title: String
    let icon: ZIcon
    let tone: Tone
    /// Already clamped to `0 ... 3` by ``init(title:icon:tone:stars:locked:size:action:)``.
    let stars: Int
    let locked: Bool
    let size: CGFloat
    private let action: () -> Void

    /// - Parameters:
    ///   - title: The word under the glyph, and the button's accessibility
    ///     label. Always a parameter — the package carries no product copy.
    ///     One or two words: the tile draws it on a single line and shrinks it
    ///     rather than wrapping or cutting it off. How large that line is
    ///     drawn follows the tile, see ``labelStep``.
    ///   - icon: The activity's glyph. Ignored while ``locked``.
    ///   - tone: The tile's tint.
    ///   - stars: How many of the three slots are filled. A number outside
    ///     `0 ... 3` is clamped, not rejected — the tile has three slots and
    ///     draws what fits, rather than trapping on a child's home screen.
    ///     What a star is worth is decided elsewhere.
    ///   - locked: Not open yet. The tile turns sand, shows an egg, drops its
    ///     ledge and its stars, and stops responding to taps.
    ///   - size: Edge length of the square. The default is the home screen's
    ///     grid cell, far above the 64 pt touch floor; a caller passing its
    ///     own number keeps that floor itself.
    ///   - action: Run on tap. Never called while ``locked``.
    public init(
        title: String,
        icon: ZIcon = .bird,
        tone: Tone = .leaf,
        stars: Int = 0,
        locked: Bool = false,
        size: CGFloat = HomeTile.defaultSize,
        action: @escaping () -> Void = {},
    ) {
        self.title = title
        self.icon = icon
        self.tone = tone
        self.stars = HomeTileMetrics.clampedStars(stars)
        self.locked = locked
        self.size = size
        self.action = action
    }

    /// The glyph actually drawn: an egg while locked, the activity's own
    /// otherwise.
    var displayedIcon: ZIcon {
        locked ? .egg : icon
    }

    /// The stars actually drawn. A locked tile shows none — there is nothing
    /// to have earned yet.
    var displayedStars: Int {
        locked ? 0 : stars
    }

    /// The step the label is drawn at, derived from ``size`` exactly as the
    /// glyph is: the largest step of the scale whose line still fits between
    /// the tile's paddings, and never below `body`, the smallest size
    /// anything a child reads may take.
    ///
    /// What "fits" means is measured rather than guessed: the widest label
    /// this tile is drawn with anywhere is 7.3 times the type size wide, so a
    /// step needs that multiple of the `size − 2 × --space-4` the padding
    /// leaves. That puts `label` — the step `typography.css` names for tile
    /// labels — at tiles from 193 pt and `headline` from 237 pt, which the
    /// JSX's own 240 pt tile clears: the deliberate deviation issue #92 asks
    /// for, so that a big tile does not carry a small word under an 82 pt
    /// glyph.
    ///
    /// Below 193 pt the tile drops to `body` and stays there. That floor still
    /// needs room: at 20 pt the two labels the app ships ask for a 174.4 pt
    /// tile („Finde den Vogel") and a 147.1 pt one („Wer singt da?"). The home
    /// screen's narrowest tile is 159 pt since it took the phone gutter
    /// (#145), so the shorter one fits whole and the longer one shrinks —
    /// 17.8 pt on a 375 pt phone, see ``HomeTileMetrics/labelScaleFloor``.
    /// That is the first time the shrink is needed on a supported width, and
    /// it is the price of calling game 1 what it asks the child to do (#220).
    var labelStep: ZType.Step {
        let available = size - 2 * ZSpacing.step4
        let steps: [ZType.Step] = [.headline, .label]
        return steps.first { available >= HomeTileMetrics.labelWidthRatio * $0.size } ?? .body
    }

    private var palette: HomeTilePalette {
        locked ? .locked : tone.palette
    }

    public var body: some View {
        let tilePalette = palette

        return Button(action: action) {
            VStack(spacing: ZSpacing.step3) {
                Icon(displayedIcon, size: .custom(size * HomeTileMetrics.iconRatio))

                Text(title)
                    // One line by design, so no `multilineTextAlignment`:
                    // the frame centres the single line already.
                    .typeStyle(labelStep, .display, weight: .bold, singleLine: true)
                    // The last resort, one step's worth: a label wider than
                    // its tile shrinks rather than losing its ending — the
                    // ending is where the question mark is. It engages below
                    // a 147 pt tile, which is smaller than any screen the app
                    // supports draws (#145), and it keeps the design's line
                    // box, so the glyph above does not shift.
                    .minimumScaleFactor(HomeTileMetrics.labelScaleFloor)

                // No stars at all until the first one is earned, exactly as
                // in the JSX: three empty outlines on a fresh tile would read
                // as a scoreboard.
                if displayedStars > 0 {
                    HStack(spacing: ZSpacing.step1) {
                        ForEach(0 ..< HomeTileMetrics.starCapacity, id: \.self) { index in
                            Icon(.star, size: .small)
                                .foregroundStyle(
                                    index < displayedStars ? ZColor.sun500 : ZColor.sand400,
                                )
                        }
                    }
                }
            }
            .foregroundStyle(tilePalette.foreground)
        }
        .buttonStyle(HomeTileButtonStyle(palette: tilePalette, size: size, hasLedge: !locked))
        // A locked tile is genuinely not activatable, and VoiceOver should say
        // so rather than offer a button that does nothing.
        .disabled(locked)
    }
}

/// The three colours one tile is drawn in.
struct HomeTilePalette: Sendable, Hashable {
    let background: Color
    let edge: Color
    let foreground: Color

    /// A tile that is not open yet: sand, sand, muted ink.
    static let locked = HomeTilePalette(
        background: ZColor.surfaceSunken,
        edge: ZColor.borderCard,
        foreground: ZColor.ink300,
    )
}

/// The tile's geometry. The values without a token are the JSX's own literals
/// and are named here rather than sprinkled through the view.
///
/// Internal rather than private since #220, as ``TopBarMetrics`` already is:
/// the label's scale floor is a promise the tests check, and a number a test
/// spells out a second time is a number that can drift.
enum HomeTileMetrics {
    /// `Math.round(size * 0.34)` — the glyph scales with the tile.
    static let iconRatio: CGFloat = 0.34
    /// How wide the widest label a tile is drawn with is per point of type
    /// size, and with it how far the label may follow the tile up before it
    /// stops fitting — see ``HomeTile/labelStep``.
    ///
    /// Measured with CoreText in the bundled Baloo 2 Bold, which is the only
    /// face a tile label is ever drawn in. "Sterne sammeln" is the widest —
    /// 145.6 pt at 20 pt, 160.1 at 22 and 203.8 at 28, so 7.278 throughout,
    /// since advances scale with the point size. It comes from this file's
    /// own previews rather than from the JSX, whose four tiles are all
    /// shorter; the widest label the tile is asked to draw is what a
    /// truncation rule has to hold against.
    ///
    /// Rounded up, so that a boundary lands with a point of slack rather
    /// than on the last glyph's edge.
    static let labelWidthRatio: CGFloat = 7.3
    /// How far a label may shrink before it would rather be cut off: one step
    /// of the scale, `body` 20 pt down to `caption` 16 pt.
    ///
    /// Not a size a child reads at — 20 pt is the floor the design sets — and
    /// no supported screen asks for it, see ``HomeTile/labelStep``. It is here
    /// so that a longer word in another language, or a tile a future screen
    /// draws smaller, loses a little height rather than its last glyphs.
    static let labelScaleFloor = ZType.Step.caption.size / ZType.Step.body.size
    /// Three stars per activity, and never a fourth.
    static let starCapacity = 3
    /// The resting ledge, `--ledge-lg`.
    static let restingLedge = ZShadow.ledgeLargeOffset
    /// What is left of the ledge under a pressed tile. `shadows.css` has no
    /// token for it; the JSX presses onto a bare 3 px.
    static let pressedLedge: CGFloat = 3
    /// How far the tile travels. The difference keeps the ledge's bottom edge
    /// nailed in place, so only the tile moves.
    static let pressTravel = restingLedge - pressedLedge

    static func clampedStars(_ stars: Int) -> Int {
        min(max(stars, 0), starCapacity)
    }
}

/// Fills, edge, ledge and the press. Kept next to the tile rather than shared:
/// the pull request building `ZButton` and `IconButton` grows a ledge style of
/// its own right now, and the two are folded together once both have landed.
private struct HomeTileButtonStyle: ButtonStyle {
    let palette: HomeTilePalette
    let size: CGFloat
    let hasLedge: Bool

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ZRadius.tile, style: .continuous)
    }

    func makeBody(configuration: Configuration) -> some View {
        let pressed = configuration.isPressed && hasLedge

        return ZStack {
            // A solid slab rather than a blurred shadow, and it never moves:
            // the tile pressing down over it is what makes the ledge look as
            // if it shrinks, exactly as in the JSX.
            if hasLedge {
                shape
                    .fill(palette.edge)
                    // A bare shape takes whatever the stack proposes, which
                    // would grow the tile to fill its slot. The ledge is the
                    // tile's own size, shifted down.
                    .frame(width: size, height: size)
                    .offset(y: HomeTileMetrics.restingLedge)
            }

            configuration.label
                .padding(ZSpacing.step4)
                .frame(width: size, height: size)
                .background { shape.fill(palette.background) }
                .overlay { shape.strokeBorder(palette.edge, lineWidth: ZBorder.widthThick) }
                .offset(y: pressed ? HomeTileMetrics.pressTravel : 0)
        }
        .animation(
            ZMotion.easeOut.animation(duration: ZMotion.instant),
            value: configuration.isPressed,
        )
    }
}

// MARK: - Previews

#Preview("All four tones") {
    HStack(spacing: ZSpacing.gapTiles) {
        HomeTile(title: "Wer singt da?", icon: .volume2, tone: .leaf, stars: 3)
        HomeTile(title: "Federn finden", icon: .feather, tone: .clay, stars: 1)
        HomeTile(title: "Sterne sammeln", icon: .star, tone: .sun, stars: 2)
        HomeTile(title: "Finde den Vogel", icon: .bird, tone: .hoopoe, stars: 2)
    }
    .padding(ZSpacing.step6)
    .background(ZColor.surfacePage)
}

#Preview("Stars, none to three") {
    HStack(spacing: ZSpacing.gapTiles) {
        ForEach(0 ... HomeTileMetrics.starCapacity, id: \.self) { stars in
            HomeTile(title: "Wer singt da?", icon: .volume2, stars: stars)
        }
    }
    .padding(ZSpacing.step6)
    .background(ZColor.surfacePage)
}

#Preview("Locked, and a stray star count") {
    HStack(spacing: ZSpacing.gapTiles) {
        HomeTile(title: "Bald!", locked: true)
        HomeTile(title: "Bald!", icon: .music, tone: .sun, stars: 3, locked: true)
        // Nine stars is not a state; the tile clamps rather than complains.
        HomeTile(title: "Finde den Vogel", icon: .bird, tone: .hoopoe, stars: 9)
    }
    .padding(ZSpacing.step6)
    .background(ZColor.surfacePage)
}
