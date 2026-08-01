import SwiftUI

// Shadow tokens from `design/tokens/shadows.css`.
//
// Two families live here. The ambient shadows (`--shadow-sm/md/lg`) are warm
// brown and soft — never neutral grey. The "toy" ledge (`--ledge`) is a solid,
// unblurred slab under every pressable that gets pressed away on tap; its
// colour is not part of the token because it is always the 700 shade of the
// pressable's own tone (see ``ZColor/primaryShadow``).

/// The ZilpZalp shadow tokens.
public enum ZShadow {
    /// An ambient drop shadow, ready for SwiftUI's
    /// `.shadow(color:radius:x:y:)`.
    public struct Style: Sendable, Hashable {
        /// The shadow colour, alpha included.
        public let color: Color
        /// SwiftUI's blur radius. CSS states a blur diameter, SwiftUI a
        /// Gaussian radius, so this is the CSS value halved.
        public let radius: CGFloat
        /// Horizontal offset, for `.shadow`'s `x:`. Zero throughout — the
        /// light comes from straight above.
        public let offsetX: CGFloat
        /// Vertical offset, for `.shadow`'s `y:`.
        public let offsetY: CGFloat
    }

    /// `--shadow-sm: 0 2px 6px rgba(92,58,36,.10)`.
    public static let small = Style(
        color: Color(hex: 0x5C3A24, opacity: 0.10),
        radius: 3,
        offsetX: 0,
        offsetY: 2,
    )
    /// `--shadow-md: 0 8px 20px rgba(92,58,36,.12)`.
    public static let medium = Style(
        color: Color(hex: 0x5C3A24, opacity: 0.12),
        radius: 10,
        offsetX: 0,
        offsetY: 8,
    )
    /// `--shadow-lg: 0 18px 40px rgba(92,58,36,.16)`.
    public static let large = Style(
        color: Color(hex: 0x5C3A24, opacity: 0.16),
        radius: 20,
        offsetX: 0,
        offsetY: 18,
    )

    /// `--ledge: 0 6px 0` — how far the solid ledge sits below a pressable.
    /// On press the surface travels down and the ledge shrinks to nothing.
    public static let ledgeOffset: CGFloat = 6
    /// `--ledge-lg: 0 10px 0` — the ledge for the big pressables.
    public static let ledgeLargeOffset: CGFloat = 10

    /// `--inset-soft: inset 0 -4px 0 rgba(34,48,31,.06)` — the vertical offset
    /// of the soft inner edge. Negative: it sits along the bottom.
    public static let insetSoftOffset: CGFloat = -4
    /// The colour of that inner edge, `rgba(34,48,31,.06)`.
    public static let insetSoftColor = Color(hex: 0x22301F, opacity: 0.06)

    /// `--ring-focus: 0 0 0 5px …` — the width of the focus ring.
    public static let focusRingWidth: CGFloat = 5
    /// The focus ring colour: `--focus-ring` at 45 %.
    ///
    /// CSS mixes towards transparent in oklab; plain sRGB alpha is close
    /// enough here because the second colour is fully transparent.
    public static let focusRingColor = ZColor.focusRing.opacity(0.45)
}
