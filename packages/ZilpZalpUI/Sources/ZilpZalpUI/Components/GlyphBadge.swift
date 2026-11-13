import SwiftUI

/// A small sun-yellow sticker with a glyph on it, stuck on something else —
/// the binoculars that count the look-alikes on a level tile, and that mark a
/// tricky question on the sound button.
///
/// A sticker, not a button: no ledge, because a ledge says "press me" and taps
/// go to whatever it sits on. It wears ``RewardSticker``'s own sun pair — a
/// sun disc with a darker edge and a bark glyph, never black on yellow, which
/// is the hazard-sign palette — a cream ring as if cut out with scissors, the
/// medium shadow and a tilt.
///
/// It says nothing to VoiceOver: the control it sits on carries the label, and
/// a badge that spoke for itself would announce the same fact twice.
///
/// ```swift
/// GlyphBadge(.binoculars, diameter: 44)
/// GlyphBadge(.binoculars, diameter: 44, rotation: .degrees(6))
/// ```
public struct GlyphBadge: View {
    private let icon: ZIcon
    private let diameter: CGFloat
    private let rotation: Angle

    /// - Parameters:
    ///   - icon: The glyph.
    ///   - diameter: Diameter of the disc, its edge included and the cream
    ///     ring outside it not — the ring overhangs the frame, as a CSS
    ///     spread shadow does.
    ///   - rotation: The tilt. A second sticker beside a first leans the other
    ///     way, so the pair reads as two stuck on by hand.
    public init(_ icon: ZIcon, diameter: CGFloat, rotation: Angle = .degrees(-8)) {
        self.icon = icon
        self.diameter = diameter
        self.rotation = rotation
    }

    public var body: some View {
        let edge = diameter * GlyphBadgeMetrics.edgeRatio
        let ring = diameter * GlyphBadgeMetrics.ringRatio

        Icon(icon, size: .custom((diameter * GlyphBadgeMetrics.glyphRatio).rounded()))
            .foregroundStyle(ZColor.bark700)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(ZColor.sun300))
            .overlay { Circle().strokeBorder(ZColor.sun600, lineWidth: edge) }
            .background {
                // The cut-out ring, outside the frame without a say in the
                // layout, and the shadow under it: it is the sticker's
                // silhouette, so it is what lifts the sticker off its ground.
                Circle()
                    .fill(ZColor.cream50)
                    .padding(-ring)
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

enum GlyphBadgeMetrics {
    /// The glyph on the disc.
    static let glyphRatio: CGFloat = 0.6
    /// The sun-600 edge, inside the diameter.
    static let edgeRatio: CGFloat = 0.07
    /// The cream ring, outside it.
    static let ringRatio: CGFloat = 0.07
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
