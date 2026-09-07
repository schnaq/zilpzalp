import SwiftUI

/// The one pressable text control: a chunky pill on a solid colour ledge.
///
/// Ported from `design/components/core/Button.jsx`. The label is a
/// `LocalizedStringKey` and resolves against the app bundle, so the only
/// String Catalog stays in the app target — this module ships no product text.
///
/// ```swift
/// ZButton("weiter", trailingIcon: .arrowRight) { advance() }
/// ```
///
/// Use `.disabled(_:)` as on any SwiftUI button; a disabled pill loses its
/// ledge and dims, exactly as in the JSX.
public struct ZButton: View {
    /// What the button is for. Never a decoration: `accent` is the one
    /// hoopoe-orange highlight per screen, `quiet` belongs to the grown-up
    /// area, `reward` to the celebration screens.
    public enum Tone: CaseIterable, Hashable, Sendable {
        case primary
        case accent
        case reward
        case quiet

        var palette: LedgePalette {
            switch self {
            case .primary: .primary
            case .accent: .accent
            case .reward: .reward
            case .quiet: .quiet
            }
        }
    }

    /// How big the pill is. `medium` is the grown-up size — never put it on a
    /// screen a child uses.
    public enum Size: CaseIterable, Hashable, Sendable {
        /// `md`, 64 pt: `--touch-min`.
        case medium
        /// `lg`, 96 pt: `--touch-comfy`.
        case large
        /// `xl`, 120 pt.
        case extraLarge

        var height: CGFloat {
            switch self {
            case .medium: ZSpacing.touchMinimum
            case .large: ZSpacing.touchComfortable
            // `spacing.css` jumps from `--touch-comfy` (96) straight to
            // `--touch-hero` (160); `Button.jsx` hard-codes `120px` for the
            // same reason. The one geometry value without a token.
            case .extraLarge: 120
            }
        }

        var horizontalPadding: CGFloat {
            switch self {
            case .medium: ZSpacing.step5
            case .large: ZSpacing.step6
            case .extraLarge: ZSpacing.step7
            }
        }

        var step: ZType.Step {
            switch self {
            case .medium: .label
            case .large: .headline
            case .extraLarge: .title
            }
        }

        var glyph: Icon.Size {
            switch self {
            case .medium: .small
            case .large: .standard
            case .extraLarge: .large
            }
        }

        /// `--ledge` under the small pill, `--ledge-lg` under the two big
        /// ones. `Button.jsx` puts an 8 px ledge under `lg`, a value
        /// `shadows.css` does not define.
        var ledgeDepth: CGFloat {
            switch self {
            case .medium: ZShadow.ledgeOffset
            case .large, .extraLarge: ZShadow.ledgeLargeOffset
            }
        }
    }

    private let title: LocalizedStringKey
    private let tone: Tone
    private let size: Size
    private let leadingIcon: ZIcon?
    private let trailingIcon: ZIcon?
    private let action: () -> Void

    /// - Parameters:
    ///   - title: One or two words, sentence case, no punctuation.
    ///   - tone: See ``Tone``.
    ///   - size: See ``Size``.
    ///   - leadingIcon: `Button.jsx`'s `icon`.
    ///   - trailingIcon: `Button.jsx`'s `iconRight` — the arrow on "Weiter".
    ///   - action: What the press does.
    public init(
        _ title: LocalizedStringKey,
        tone: Tone = .primary,
        size: Size = .large,
        leadingIcon: ZIcon? = nil,
        trailingIcon: ZIcon? = nil,
        action: @escaping () -> Void,
    ) {
        self.title = title
        self.tone = tone
        self.size = size
        self.leadingIcon = leadingIcon
        self.trailingIcon = trailingIcon
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            label
        }
        .buttonStyle(LedgeButtonStyle(palette: tone.palette, depth: size.ledgeDepth))
    }

    private var label: some View {
        HStack(spacing: ZSpacing.step3) {
            if let leadingIcon {
                Icon(leadingIcon, size: size.glyph)
            }
            Text(title)
                .font(size.step.font(.display, weight: .bold))
                .tracking(size.step.tracking(ZType.Tracking.looseEm))
            if let trailingIcon {
                Icon(trailingIcon, size: size.glyph)
            }
        }
        .padding(.horizontal, size.horizontalPadding)
        .frame(minHeight: size.height)
    }
}

#Preview("Tones") {
    VStack(spacing: ZSpacing.step5) {
        ForEach(ZButton.Tone.allCases, id: \.self) { tone in
            ZButton("\(String(describing: tone))", tone: tone, trailingIcon: .arrowRight) {}
        }
    }
    .padding(ZSpacing.step6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}

#Preview("Sizes") {
    VStack(spacing: ZSpacing.step5) {
        ForEach(ZButton.Size.allCases, id: \.self) { size in
            ZButton("\(String(describing: size))", size: size, leadingIcon: .play) {}
        }
    }
    .padding(ZSpacing.step6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}

#Preview("Disabled") {
    VStack(spacing: ZSpacing.step5) {
        ForEach(ZButton.Tone.allCases, id: \.self) { tone in
            ZButton("\(String(describing: tone))", tone: tone) {}
                .disabled(true)
        }
    }
    .padding(ZSpacing.step6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}
