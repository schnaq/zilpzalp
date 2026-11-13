import SwiftUI

/// A small sun-yellow sticker with a glyph on it, stuck on something else:
/// the binoculars on a level tile and on a tricky question's sound button.
///
/// A sticker, not a button: no ledge, because a ledge says "press me" and taps
/// go to whatever it sits on. ``RewardSticker``'s sun palette keeps the glyph
/// bark on yellow — black on yellow is the hazard sign — and the cream ring
/// reads as cut out with scissors.
///
/// It says nothing to VoiceOver: the control it sits on carries the label, and
/// a badge that spoke for itself would announce the same fact twice.
///
/// ```swift
/// GlyphBadge(.binoculars, diameter: 44, rotation: .degrees(6))
/// ```
public struct GlyphBadge: View {
    /// The glyph, as a share of the diameter.
    private static let glyphRatio: CGFloat = 0.6

    /// The sun-600 edge inside the diameter, and the cream ring outside it.
    private static let edgeRatio: CGFloat = 0.07

    private let icon: ZIcon
    private let diameter: CGFloat
    private let rotation: Angle

    /// - Parameters:
    ///   - icon: The glyph.
    ///   - diameter: The disc, its edge included. The cream ring overhangs it
    ///     without a say in the layout.
    ///   - rotation: The tilt. A second sticker beside a first leans the other
    ///     way, so the pair reads as two stuck on by hand.
    public init(_ icon: ZIcon, diameter: CGFloat, rotation: Angle = .degrees(-8)) {
        self.icon = icon
        self.diameter = diameter
        self.rotation = rotation
    }

    public var body: some View {
        let colours = RewardSticker.Tone.sun.palette
        let edge = diameter * Self.edgeRatio

        Icon(icon, size: .custom((diameter * Self.glyphRatio).rounded()))
            .foregroundStyle(colours.foreground)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(colours.background))
            .overlay { Circle().strokeBorder(colours.edge, lineWidth: edge) }
            .background {
                // The cut-out ring, outside the frame without a say in the
                // layout, and the shadow under it: it is the sticker's
                // silhouette, so it is what lifts the sticker off its ground.
                Circle()
                    .fill(ZColor.cream50)
                    .padding(-edge)
                    .shadow(
                        color: ZShadow.medium.color,
                        radius: ZShadow.medium.radius,
                        x: ZShadow.medium.offsetX,
                        y: ZShadow.medium.offsetY,
                    )
            }
            .rotationEffect(rotation)
            .accessibilityHidden(true)
    }
}

#Preview("Glyph badge") {
    HStack(spacing: ZSpacing.step6) {
        GlyphBadge(.binoculars, diameter: 30)
        GlyphBadge(.binoculars, diameter: 44)
        GlyphBadge(.binoculars, diameter: 56)
        HStack(spacing: -44 * 0.2) {
            GlyphBadge(.binoculars, diameter: 44, rotation: .degrees(6))
                .zIndex(1)
            GlyphBadge(.binoculars, diameter: 44)
        }
    }
    .padding(ZSpacing.step7)
    .background(ZColor.sand200)
}
