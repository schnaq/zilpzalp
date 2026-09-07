import SwiftUI

/// The five card tints. `paper` is the default cream card; the other four
/// tint a group without changing what it means.
///
/// Each case names the same CSS custom property `Card.jsx` names — hence the
/// mix of semantic aliases and ramp entries (`--border-card` for `paper`,
/// `--sand-300` for `sand`, though both resolve to the same colour). Keeping
/// the spelling lets this switch be diffed against the JSX line by line.
///
/// Declared next to ``ZCard`` rather than inside it: ``ZCard`` is generic over
/// its content, so a nested `ZCard.Tone` could not be named without spelling
/// out that content type.
public enum ZCardTone: CaseIterable, Hashable, Sendable {
    case paper
    case leaf
    case clay
    case sun
    case sand

    var fill: Color {
        switch self {
        case .paper: ZColor.surfaceCard
        case .leaf: ZColor.olive50
        case .clay: ZColor.clay50
        case .sun: ZColor.sun100
        case .sand: ZColor.surfaceSunken
        }
    }

    var outline: Color {
        switch self {
        case .paper: ZColor.borderCard
        case .leaf: ZColor.olive300
        case .clay: ZColor.clay200
        case .sun: ZColor.sun300
        case .sand: ZColor.sand300
        }
    }
}

/// A rounded, outlined panel that groups content on the cream page.
///
/// Ported from `design/components/core/Card.jsx`. The 3 pt outline is never
/// optional: the outline, not the shadow, is what makes a card read as
/// illustration rather than as a floating browser panel. Use the tints
/// sparingly — one tone per group.
///
/// ```swift
/// ZCard(tone: .leaf) {
///     Text(summary)
/// }
/// ```
public struct ZCard<Content: View>: View {
    private let tone: ZCardTone
    private let padding: CGFloat
    private let content: Content

    /// - Parameters:
    ///   - tone: See ``ZCardTone``.
    ///   - padding: The gap between the content and the outline —
    ///     `Card.jsx`'s `pad`, `--space-5` by default.
    ///   - content: Anything. The card sets body type and text colour; the
    ///     content overrides what it needs to.
    public init(
        tone: ZCardTone = .paper,
        padding: CGFloat = ZSpacing.step5,
        @ViewBuilder content: () -> Content,
    ) {
        self.tone = tone
        self.padding = padding
        self.content = content()
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: ZRadius.card, style: .continuous)
    }

    public var body: some View {
        content
            // Not `singleLine`: a card holds prose, and the grown-up copy in
            // it wraps by design.
            .typeStyle(.body, .body, weight: .semibold)
            .foregroundStyle(ZColor.textBody)
            // `strokeBorder` draws the outline inside the bounds, so the width
            // is added here: `padding` stays the gap the caller asked for
            // between content and the visible outline, as in the CSS box.
            .padding(padding + ZBorder.width)
            .background(
                shape
                    .fill(tone.fill)
                    .shadow(
                        color: ZShadow.medium.color,
                        radius: ZShadow.medium.radius,
                        x: ZShadow.medium.offsetX,
                        y: ZShadow.medium.offsetY,
                    ),
            )
            .overlay(shape.strokeBorder(tone.outline, lineWidth: ZBorder.width))
    }
}

#Preview("Tones") {
    VStack(spacing: ZSpacing.step5) {
        ForEach(ZCardTone.allCases, id: \.self) { tone in
            ZCard(tone: tone) {
                Text("\(String(describing: tone)) — three birds learned today")
            }
        }
    }
    .padding(ZSpacing.step6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}

#Preview("Padding and mixed content") {
    VStack(spacing: ZSpacing.step5) {
        ZCard(tone: .leaf, padding: ZSpacing.step6) {
            VStack(alignment: .leading, spacing: ZSpacing.step3) {
                Text("Wide padding")
                    .font(ZType.Step.headline.font(.display, weight: .bold))
                Badge("rare", tone: .rare, icon: .sparkles)
            }
        }
        ZCard(tone: .sun, padding: ZSpacing.step3) {
            Icon(.star, size: .large)
        }
    }
    .padding(ZSpacing.step6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}
