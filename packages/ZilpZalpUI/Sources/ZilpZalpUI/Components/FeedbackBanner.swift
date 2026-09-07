import SwiftUI

/// What the app says back after a tap: praise, encouragement, or a nudge.
///
/// Ported from `design/components/quiz/FeedbackBanner.jsx`. The message is
/// always a parameter — this package carries no product copy — and the tone
/// is carried by colour and a glyph so that the meaning survives a child who
/// cannot read the sentence.
///
/// **``Kind/retry`` is not an error.** It is sun yellow with an open hand, and
/// the sentence behind it is "Fast! Hör nochmal hin." There is no red variant
/// and no X in this component, and there will not be one.
///
/// ```swift
/// FeedbackBanner("Genau! Das ist der Zilpzalp.", kind: .correct)
/// ```
public struct FeedbackBanner: View {
    /// The three things the app ever has to say.
    public enum Kind: CaseIterable, Hashable, Sendable {
        /// Right. Olive, and a party popper.
        case correct
        /// Not this one — try again. Sun yellow, and an open hand.
        case retry
        /// A hint, unprompted or asked for. Clay, and a lightbulb.
        case hint

        var palette: FeedbackBannerPalette {
            switch self {
            case .correct:
                FeedbackBannerPalette(
                    fill: ZColor.correctSoft,
                    edge: ZColor.correct,
                    foreground: ZColor.olive800,
                    icon: .partyPopper,
                )
            case .retry:
                FeedbackBannerPalette(
                    fill: ZColor.retrySoft,
                    edge: ZColor.retry,
                    foreground: ZColor.bark700,
                    icon: .handHeart,
                )
            case .hint:
                FeedbackBannerPalette(
                    fill: ZColor.clay50,
                    edge: ZColor.clay300,
                    foreground: ZColor.clay700,
                    icon: .lightbulb,
                )
            }
        }
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hasAppeared = false

    private let message: String
    private let icon: ZIcon?

    /// Which of the three things is being said.
    let kind: Kind

    /// - Parameters:
    ///   - message: The finished sentence, in the app's language. Short: it is
    ///     read aloud by a grown-up or ignored by a child who already got the
    ///     colour.
    ///   - kind: See ``Kind``.
    ///   - icon: Overrides the glyph the kind brings. The quiz screen does not
    ///     need it; a screen that wants `check` or `rotate-ccw` to echo the
    ///     tile it sits under can ask for one.
    public init(_ message: String, kind: Kind = .correct, icon: ZIcon? = nil) {
        self.message = message
        self.kind = kind
        self.icon = icon
    }

    /// The glyph actually drawn: the caller's if there is one, the kind's
    /// otherwise.
    var displayedIcon: ZIcon {
        icon ?? kind.palette.icon
    }

    public var body: some View {
        let palette = kind.palette

        return HStack(spacing: ZSpacing.step4) {
            Icon(displayedIcon, size: .custom(FeedbackBannerMetrics.glyph))
            Text(verbatim: message)
                .font(ZType.Step.headline.font(.display, weight: .bold))
                .lineSpacing(ZType.Step.headline.lineSpacing)
        }
        .padding(.vertical, ZSpacing.step4)
        .padding(.horizontal, ZSpacing.step6)
        .foregroundStyle(palette.foreground)
        .background(Capsule().fill(palette.fill))
        .overlay(Capsule().strokeBorder(palette.edge, lineWidth: ZBorder.width))
        .shadow(
            color: ZShadow.small.color,
            radius: ZShadow.small.radius,
            x: ZShadow.small.offsetX,
            y: ZShadow.small.offsetY,
        )
        // `zz-pop`: in from 60 % with `--ease-bounce`, whose overshoot supplies
        // the keyframe's 108 % bump on its own.
        .scaleEffect(isVisible ? 1 : FeedbackBannerMetrics.entryScale)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            // A `@State` flag rather than a `.transition`: the banner's
            // insertion belongs to whatever animation the screen wraps it in,
            // and the screen must not have to know that this component wants
            // to pop.
            guard !reduceMotion else { return }
            withAnimation(ZMotion.easeBounce.animation(duration: ZMotion.slow)) {
                hasAppeared = true
            }
        }
        // One announcement, glyph and sentence together — VoiceOver should
        // read the message, not walk into it.
        .accessibilityElement(children: .combine)
    }

    /// Reduced motion skips the entrance rather than fading it: the banner is
    /// simply there.
    private var isVisible: Bool {
        hasAppeared || reduceMotion
    }
}

/// The four things one banner kind decides.
struct FeedbackBannerPalette: Sendable, Hashable {
    let fill: Color
    let edge: Color
    let foreground: Color
    /// The glyph the kind brings, overridable per banner.
    let icon: ZIcon
}

/// The banner's own numbers, from the JSX.
enum FeedbackBannerMetrics {
    /// The glyph beside the sentence, `size={38}` in the JSX — between the
    /// 32 pt and 44 pt presets, so it is spelled out.
    static let glyph: CGFloat = 38
    /// `zz-pop` starts at `scale(.6)`.
    static let entryScale: CGFloat = 0.6
}

// MARK: - Previews

#Preview("All three kinds") {
    VStack(alignment: .leading, spacing: ZSpacing.step5) {
        FeedbackBanner("Genau! Das ist der Zilpzalp.", kind: .correct)
        FeedbackBanner("Fast! Hör nochmal hin.", kind: .retry)
        FeedbackBanner("Der Zilpzalp singt seinen eigenen Namen.", kind: .hint)
    }
    .padding(ZSpacing.step6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}

#Preview("Overridden glyphs and a long sentence") {
    VStack(alignment: .leading, spacing: ZSpacing.step5) {
        FeedbackBanner("Genau!", kind: .correct, icon: .check)
        FeedbackBanner("Probier es noch einmal.", kind: .retry, icon: .rotateCcw)
        FeedbackBanner(
            "Hör genau hin: der Zilpzalp wiederholt zwei Töne, immer wieder, wie eine kleine Uhr.",
            kind: .hint,
        )
    }
    .padding(ZSpacing.step6)
    .frame(maxWidth: 720)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}
