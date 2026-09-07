import SwiftUI

// How a ``ChoiceTile`` is painted: the colours one phase resolves to, the
// numbers the JSX gives it, and the press itself. Split out of `ChoiceTile.swift`
// the way `LedgeButtonStyle.swift` sits beside `ZButton.swift` — the component
// decides *what* it is showing, this file decides what that looks like.

/// The three colours one tile is outlined, seated and ringed in.
struct ChoiceTilePalette: Sendable, Hashable {
    /// The 5 pt outline around the photo.
    let border: Color
    /// The solid slab the tile sits on.
    let ledge: Color
    /// The soft halo around a tile that has been touched. `nil` while idle —
    /// four haloed tiles would say nothing.
    let ring: Color?
}

/// The round marker in a resolved tile's top-right corner.
///
/// There are exactly two of these and there will not be a third: a check on
/// olive and a "go round again" on sun. No cross, no red, no failure.
struct ChoiceTileBadge: Sendable, Hashable {
    let icon: ZIcon
    let fill: Color
    let foreground: Color
}

/// The tile's geometry. The values without a token are the JSX's own literals,
/// named here rather than sprinkled through the view.
enum ChoiceTileMetrics {
    /// `Math.round(size * 0.3)` — the placeholder bird glyph.
    static let placeholderRatio: CGFloat = 0.3
    /// The badge circle, 56 px in the JSX.
    static let badgeDiameter: CGFloat = 56
    /// The glyph inside it, 30 px.
    static let badgeGlyph: CGFloat = 30
    /// `top: 12, right: 12` — `--space-3`.
    static let badgeInset = ZSpacing.step3
    /// `zz-pop` starts at `scale(.6)`.
    static let badgeEntryScale: CGFloat = 0.6
    /// The `10px` spread of the halo around a touched tile.
    static let ringWidth: CGFloat = 10
    /// `--ledge-lg`. The JSX draws 9 px; 10 is the token it was reaching for,
    /// and the one `HomeTile` already sits on.
    static let restingLedge = ZShadow.ledgeLargeOffset
    /// What is left of the ledge under a pressed tile. `shadows.css` has no
    /// token for it; the JSX presses onto a bare 2 px, `HomeTile` onto 3.
    static let pressedLedge: CGFloat = 3
    /// How far the face travels. The difference keeps the ledge's bottom edge
    /// nailed in place, so only the tile moves.
    static let pressTravel = restingLedge - pressedLedge
    /// `translateY(-4px)` — `--space-1` — under a correct tile.
    static let correctLift = ZSpacing.step1
    /// A tile that is no longer the question. Visible, readable, still
    /// tappable — this is the one thing that must never read as "blocked".
    static let dimmedOpacity: Double = 0.4
}

/// Border, ledge, halo and the press.
///
/// A third ledge implementation, for the same reason `HomeTile` gives:
/// ``LedgeButtonStyle`` paints a `Capsule` filled with a ``LedgePalette``'s
/// face colour, and a photo tile has neither a capsule nor a face colour — it
/// has a 40 pt rounded square, a phase-driven outline and a halo. Folding all
/// three together is a refactor of its own, once every pressable has landed.
/// ``SoundButton``, which really is a capsule, reuses ``LedgeButtonStyle``
/// unchanged.
struct ChoiceTileButtonStyle: ButtonStyle {
    let palette: ChoiceTilePalette

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ZRadius.tile, style: .continuous)
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .overlay { shape.strokeBorder(palette.border, lineWidth: ZBorder.widthThick) }
            // `offset`, so the tile travels without moving the ledge that the
            // next two backgrounds draw, or the tiles beside it.
            .offset(y: configuration.isPressed ? ChoiceTileMetrics.pressTravel : 0)
            .background {
                // A background rather than a `ZStack` sibling: it is handed
                // the face's own size instead of stretching into whatever the
                // grid happens to offer.
                shape
                    .fill(palette.ledge)
                    .offset(y: ChoiceTileMetrics.restingLedge)
            }
            .background {
                // Painted under the ledge, as in the CSS, where the ledge
                // shadow is listed first and therefore wins. Negative padding
                // pushes the halo outside the tile without giving it a say in
                // the layout, so a tile does not resize when it is touched.
                if let ring = palette.ring {
                    RoundedRectangle(
                        cornerRadius: ZRadius.tile + ChoiceTileMetrics.ringWidth,
                        style: .continuous,
                    )
                    .fill(ring)
                    .padding(-ChoiceTileMetrics.ringWidth)
                }
            }
            // Keeps the ledge inside the tile's own bounds and makes it part
            // of the touch target.
            .padding(.bottom, ChoiceTileMetrics.restingLedge)
            .contentShape(Rectangle())
            .animation(
                ZMotion.easeOut.animation(duration: ZMotion.instant),
                value: configuration.isPressed,
            )
    }
}
