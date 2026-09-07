import SwiftUI

/// The round, wordless control for navigation and utilities — back, home,
/// replay, settings. The only icon-only control a child ever touches.
///
/// Ported from `design/components/core/IconButton.jsx`. Because the glyph
/// carries no words, ``label`` is not optional: without it VoiceOver would
/// announce an unnamed button.
///
/// ```swift
/// IconButton(.chevronLeft, label: "back") { goBack() }
/// ```
public struct IconButton: View {
    /// The four tones the design system declares for this control. Not the
    /// same set as ``ZButton/Tone``: an icon button is never a reward, and
    /// `clay` is the tone the home screen uses for its secondary round
    /// buttons.
    public enum Tone: CaseIterable, Hashable, Sendable {
        case primary
        case accent
        case clay
        case quiet

        var palette: LedgePalette {
            switch self {
            case .primary: .primary
            case .accent: .accent
            case .clay: .clay
            case .quiet: .quiet
            }
        }
    }

    /// How much of the circle the glyph fills, from the JSX (`size * 0.45`).
    static let glyphRatio: CGFloat = 0.45

    private let icon: ZIcon
    private let label: LocalizedStringKey
    private let tone: Tone
    private let action: () -> Void

    /// The diameter actually drawn. Children's fingers set the floor, so a
    /// caller cannot shrink this control below `--touch-min`.
    let diameter: CGFloat

    /// - Parameters:
    ///   - icon: The glyph. Decorative on its own; ``label`` names the button.
    ///   - label: What VoiceOver announces. Mandatory.
    ///   - tone: See ``Tone``.
    ///   - diameter: Clamped to `--touch-min` from below. The default
    ///     `--touch-comfy` is the size for anything a child taps mid-game.
    ///   - action: What the press does.
    public init(
        _ icon: ZIcon,
        label: LocalizedStringKey,
        tone: Tone = .quiet,
        diameter: CGFloat = ZSpacing.touchComfortable,
        action: @escaping () -> Void,
    ) {
        self.icon = icon
        self.label = label
        self.tone = tone
        self.diameter = max(diameter, ZSpacing.touchMinimum)
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Icon(icon, size: .custom((diameter * Self.glyphRatio).rounded()))
                .frame(width: diameter, height: diameter)
        }
        // `--ledge`. `IconButton.jsx` hard-codes 7 px, a value `shadows.css`
        // does not define; 6 pt is the token it was reaching for.
        .buttonStyle(LedgeButtonStyle(palette: tone.palette, depth: ZShadow.ledgeOffset))
        .accessibilityLabel(Text(label))
    }
}

#Preview("Tones") {
    HStack(spacing: ZSpacing.step5) {
        ForEach(IconButton.Tone.allCases, id: \.self) { tone in
            IconButton(.house, label: "\(String(describing: tone))", tone: tone) {}
        }
    }
    .padding(ZSpacing.step6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}

#Preview("Diameters and disabled") {
    HStack(alignment: .top, spacing: ZSpacing.step5) {
        // The first one asks for 24 pt and is clamped up to 64.
        ForEach([24, ZSpacing.touchMinimum, ZSpacing.touchComfortable], id: \.self) { diameter in
            IconButton(.volume2, label: "read aloud", tone: .primary, diameter: diameter) {}
        }
        IconButton(.chevronLeft, label: "back") {}
            .disabled(true)
    }
    .padding(ZSpacing.step6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}
