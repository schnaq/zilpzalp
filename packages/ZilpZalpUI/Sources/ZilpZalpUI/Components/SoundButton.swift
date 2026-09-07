import SwiftUI

/// "Play the call again" — the big round hoopoe-orange button a child taps to
/// hear a bird.
///
/// Ported from `design/components/quiz/SoundButton.jsx`. It is the one control
/// in the quiz that is not a photo, so it is deliberately huge: 160 pt by
/// default, never below 120.
///
/// The button reports a tap and nothing else. Whether a call is audible is
/// ``isPlaying``, which the screen owns — this package plays no audio and
/// keeps no timers.
///
/// ```swift
/// SoundButton(isPlaying: player.isPlaying, label: "Ruf noch einmal hören") {
///     player.play(call)
/// }
/// ```
public struct SoundButton: View {
    /// The floor issue #11 sets for this control — nearly twice the 64 pt
    /// touch minimum, because a child looks for it without reading.
    public static let minimumDiameter: CGFloat = 120

    /// How much of the circle the glyph fills, from the JSX (`size * 0.4`).
    static let glyphRatio: CGFloat = 0.4

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let label: String
    private let action: () -> Void

    /// Whether a call is audible right now.
    let isPlaying: Bool
    /// The diameter actually drawn, already clamped to ``minimumDiameter``.
    let diameter: CGFloat

    /// - Parameters:
    ///   - isPlaying: True while the call sounds. Swaps the glyph from `play`
    ///     to `volume-2` and sends two rings outward.
    ///   - label: What VoiceOver announces. Mandatory: the button carries no
    ///     words, so without it there is nothing to announce.
    ///   - diameter: Clamped up to ``minimumDiameter``. The default
    ///     `--touch-hero` is the size the quiz screen uses.
    ///   - action: Run on tap. Tapping while playing is a legitimate "again",
    ///     so the button never disables itself.
    public init(
        isPlaying: Bool = false,
        label: String,
        diameter: CGFloat = ZSpacing.touchHero,
        action: @escaping () -> Void = {},
    ) {
        self.isPlaying = isPlaying
        self.label = label
        self.diameter = max(diameter, Self.minimumDiameter)
        self.action = action
    }

    /// `volume-2` while a call sounds, `play` while it waits.
    var glyph: ZIcon {
        isPlaying ? .volume2 : .play
    }

    public var body: some View {
        Button(action: action) {
            Icon(glyph, size: .custom((diameter * Self.glyphRatio).rounded()))
                .frame(width: diameter, height: diameter)
                // The rings sit behind the glyph and in front of the capsule
                // the button style paints, as in the JSX. A background never
                // touches the layout, so the ring's overshoot beyond the
                // circle cannot push the button's neighbours around.
                .background { rings }
        }
        // `--ledge-lg`, the depth the JSX gives this button, on the shared
        // capsule press of `ZButton` and `IconButton`: a circle is a capsule
        // whose width equals its height, so there is nothing to extend here.
        .buttonStyle(LedgeButtonStyle(palette: .accent, depth: ZShadow.ledgeLargeOffset))
        .accessibilityLabel(label)
    }

    @ViewBuilder private var rings: some View {
        if isPlaying {
            ZStack {
                // With reduced motion the button still says "sound is coming
                // out of me" — one steady ring instead of two travelling
                // ones. Silence would leave a deaf child guessing.
                PulseRing(delay: 0, isAnimated: !reduceMotion)
                if !reduceMotion {
                    PulseRing(delay: SoundButtonMetrics.pulse / 2, isAnimated: true)
                }
            }
        }
    }
}

/// One ring travelling outward from the button and fading as it goes.
private struct PulseRing: View {
    /// How far into the cycle this ring starts, so two rings are evenly
    /// spaced rather than stacked.
    let delay: TimeInterval
    /// False when the child has asked for reduced motion: the ring is then
    /// drawn once, at rest, and never moves.
    let isAnimated: Bool

    @State private var expanded = false

    /// Where the ring waits before it sets off.
    ///
    /// A travelling ring starts on the button's own edge and becomes visible
    /// by leaving it. A ring that never travels cannot do that: at scale 1 it
    /// is a `--color-accent` circle drawn on the `--color-accent` capsule, the
    /// same size, so it is not a faint ring — it is no ring at all. The static
    /// one therefore starts clear of the face, where it reads against the
    /// cream page.
    private var restingScale: CGFloat {
        isAnimated ? 1 : SoundButtonMetrics.restingRingScale
    }

    var body: some View {
        Circle()
            .strokeBorder(ZColor.accent, lineWidth: ZBorder.widthThick)
            .scaleEffect(expanded ? SoundButtonMetrics.ringScale : restingScale)
            .opacity(expanded ? 0 : SoundButtonMetrics.ringOpacity)
            .onAppear {
                guard isAnimated else { return }
                withAnimation(
                    ZMotion.easeOut.animation(duration: SoundButtonMetrics.pulse)
                        .repeatForever(autoreverses: false)
                        .delay(delay),
                ) {
                    expanded = true
                }
            }
    }
}

/// The button's own numbers, from the `zz-ring` keyframes in
/// `design/guidelines/motion.css`.
enum SoundButtonMetrics {
    /// One outward journey.
    ///
    /// The JSX runs the ring over 1.4 s, which `design/readme.md` itself
    /// forbids two paragraphs later ("nothing exceeds 900ms"). `--dur-celebrate`
    /// is that ceiling and the longest duration the token layer has, so the
    /// ring keeps the guideline rather than the literal.
    static let pulse = ZMotion.celebrate
    /// `zz-ring` ends at `scale(1.55)`.
    static let ringScale: CGFloat = 1.55
    /// Where the one static ring sits when the child has asked for reduced
    /// motion: partway along the journey the animated rings make, far enough
    /// out to clear the button's own edge and be seen at all. No JSX
    /// equivalent — the JSX has no reduced-motion case.
    static let restingRingScale: CGFloat = 1.25
    /// …and starts at `opacity: .7`, fading to nothing.
    static let ringOpacity: Double = 0.7
}

// MARK: - Previews

#Preview("Playing and waiting") {
    HStack(spacing: ZSpacing.step7) {
        SoundButton(isPlaying: false, label: "Ruf anhören")
        SoundButton(isPlaying: true, label: "Ruf anhören")
    }
    .padding(ZSpacing.step7)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}

#Preview("Diameters, floor included") {
    HStack(alignment: .top, spacing: ZSpacing.step6) {
        // 40 pt is below the floor and is clamped up to 120.
        SoundButton(isPlaying: true, label: "Ruf anhören", diameter: 40)
        SoundButton(isPlaying: true, label: "Ruf anhören", diameter: SoundButton.minimumDiameter)
        SoundButton(isPlaying: true, label: "Ruf anhören", diameter: ZSpacing.touchHero)
    }
    .padding(ZSpacing.step7)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}

#Preview("Beside the question, as the quiz screen has it") {
    HStack(spacing: ZSpacing.step6) {
        SoundButton(isPlaying: true, label: "Ruf anhören", diameter: 150)
        Text(verbatim: "Wer singt da?")
            .font(ZType.Step.display2.font(.display, weight: .extraBold))
            .foregroundStyle(ZColor.textStrong)
    }
    .padding(ZSpacing.step7)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}
