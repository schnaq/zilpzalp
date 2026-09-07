import SwiftUI

/// A soft pill label for counts, habitats and rarity. Decorative only: it has
/// no action, no press state and no touch target, so it is a plain view and
/// not a `Button`.
///
/// Ported from `design/components/core/Badge.jsx`. Use ``Tone/rare`` only for
/// genuinely rare finds, so it keeps its meaning.
///
/// ```swift
/// Badge("rare", tone: .rare, icon: .sparkles)
/// ```
public struct Badge: View {
    /// The six badge tints. Each pairs a soft fill with a dark shade of the
    /// same hue, so the text carries its own contrast.
    ///
    /// As in ``ZCardTone``, each case names the CSS custom property
    /// `Badge.jsx` names, so the mix of semantic aliases (`--color-primary-
    /// soft`) and ramp entries (`--clay-100`) is deliberate.
    public enum Tone: CaseIterable, Hashable, Sendable {
        case leaf
        case hoopoe
        case sun
        case clay
        case rare
        case sand

        var fill: Color {
            switch self {
            case .leaf: ZColor.primarySoft
            case .hoopoe: ZColor.accentSoft
            case .sun: ZColor.sun200
            case .clay: ZColor.clay100
            case .rare: ZColor.berry100
            case .sand: ZColor.sand200
            }
        }

        var foreground: Color {
            switch self {
            case .leaf: ZColor.olive700
            case .hoopoe: ZColor.orange700
            case .sun: ZColor.bark700
            case .clay: ZColor.clay700
            case .rare: ZColor.berry700
            case .sand: ZColor.ink700
            }
        }
    }

    private let text: LocalizedStringKey
    private let tone: Tone
    private let icon: ZIcon?

    /// - Parameters:
    ///   - text: One or two words. Long text is not wrapped, as in the JSX.
    ///   - tone: See ``Tone``.
    ///   - icon: An optional glyph in front of the text.
    public init(_ text: LocalizedStringKey, tone: Tone = .leaf, icon: ZIcon? = nil) {
        self.text = text
        self.tone = tone
        self.icon = icon
    }

    public var body: some View {
        HStack(spacing: ZSpacing.step2) {
            if let icon {
                // `Icon.Size.small` is 24 pt; the JSX asks for 22. Taking the
                // existing preset beats adding a raw value for 2 pt.
                Icon(icon, size: .small)
            }
            Text(text)
                .font(ZType.Step.body.font(.display, weight: .bold))
                .tracking(ZType.Step.body.tracking(ZType.Tracking.looseEm))
        }
        .padding(.vertical, ZSpacing.step2)
        .padding(.horizontal, ZSpacing.step4)
        .foregroundStyle(tone.foreground)
        .background(Capsule().fill(tone.fill))
        // `white-space: nowrap` in the JSX: a badge keeps its one line.
        .fixedSize(horizontal: true, vertical: false)
    }
}

#Preview("Tones") {
    VStack(alignment: .leading, spacing: ZSpacing.step3) {
        ForEach(Badge.Tone.allCases, id: \.self) { tone in
            Badge("\(String(describing: tone))", tone: tone)
        }
    }
    .padding(ZSpacing.step6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}

#Preview("With icons") {
    VStack(alignment: .leading, spacing: ZSpacing.step3) {
        Badge("rare", tone: .rare, icon: .sparkles)
        Badge("three stars", tone: .sun, icon: .star)
        Badge("woodland", tone: .leaf, icon: .leaf)
        Badge("song", tone: .hoopoe, icon: .music)
    }
    .padding(ZSpacing.step6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}
