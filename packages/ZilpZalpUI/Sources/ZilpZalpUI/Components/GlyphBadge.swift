import SwiftUI

/// A small sun-yellow disc with a glyph in it, stuck on the corner of
/// something else, such as the binoculars on the sound button of a harder
/// level.
///
/// It says nothing to VoiceOver: the control it sits on carries the label, and
/// a badge that spoke for itself would announce the same fact twice.
///
/// ```swift
/// GlyphBadge(.binoculars, diameter: 44)
/// ```
public struct GlyphBadge: View {
    private let icon: ZIcon
    private let diameter: CGFloat

    /// - Parameters:
    ///   - icon: The glyph.
    ///   - diameter: Outer diameter of the disc, outline included.
    public init(_ icon: ZIcon, diameter: CGFloat) {
        self.icon = icon
        self.diameter = diameter
    }

    public var body: some View {
        Icon(icon, size: .custom((diameter * GlyphBadgeMetrics.glyphRatio).rounded()))
            .foregroundStyle(ZColor.textOnReward)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(ZColor.reward))
            .overlay {
                Circle().strokeBorder(ZColor.surfaceCard, lineWidth: GlyphBadgeMetrics.outline)
            }
            .background(
                Circle()
                    .fill(ZColor.rewardShadow)
                    .offset(y: diameter * GlyphBadgeMetrics.ledgeRatio),
            )
            .rotationEffect(GlyphBadgeMetrics.tilt)
            .accessibilityHidden(true)
    }
}

enum GlyphBadgeMetrics {
    /// The glyph inside the disc.
    static let glyphRatio: CGFloat = 0.55
    /// The cream outline that lifts the badge off whatever it sits on.
    static let outline: CGFloat = 3
    /// The ledge, scaled down from the 6 pt of a full-size pressable: a badge
    /// is a fraction of the size.
    static let ledgeRatio: CGFloat = 0.08
    static let tilt = Angle.degrees(-10)
}

#Preview("Glyph badge") {
    HStack(spacing: ZSpacing.step6) {
        GlyphBadge(.binoculars, diameter: 32)
        GlyphBadge(.binoculars, diameter: 44)
        GlyphBadge(.binoculars, diameter: 64)
    }
    .padding(ZSpacing.step7)
    .background(ZColor.surfacePage)
}
