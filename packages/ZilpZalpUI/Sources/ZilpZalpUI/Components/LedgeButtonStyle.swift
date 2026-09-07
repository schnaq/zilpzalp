import SwiftUI

// The one press interaction of the design system, shared by ``ZButton`` and
// ``IconButton``: a capsule sitting on a solid ledge of its own colour. On
// press the capsule travels down onto the ledge — it never casts a drop
// shadow. `design/components/core/Button.jsx` and `IconButton.jsx` both build
// this from `box-shadow: 0 <depth> 0 <ledge>` plus a `translateY`.
//
// No black shadows anywhere: the ledge is always the dark shade of the tone
// itself (`--color-*-shadow`), never a neutral and never a transparency.

/// The colours one pressable tone paints with.
struct LedgePalette: Hashable {
    /// The capsule at rest.
    let face: Color
    /// The capsule while a finger is down.
    let pressedFace: Color
    /// The solid slab under the capsule: the tone's own dark shade.
    let ledge: Color
    /// Label and glyph colour.
    let foreground: Color
    /// `quiet` is the only tone painted in the page's own cream, so it is the
    /// only one that needs an outline to read as a control at all.
    let isOutlined: Bool

    init(
        face: Color,
        pressedFace: Color,
        ledge: Color,
        foreground: Color,
        isOutlined: Bool = false,
    ) {
        self.face = face
        self.pressedFace = pressedFace
        self.ledge = ledge
        self.foreground = foreground
        self.isOutlined = isOutlined
    }
}

/// The palettes themselves. They live here rather than in each control's tone
/// enum because `ZButton` and `IconButton` share three of them verbatim — and
/// the next capsule pressable, `SoundButton` (#11), is `accent` again.
///
/// Spelled `ZColor.…` throughout: `Color` has semantic members of its own
/// (`Color.primary` is the system label colour), so the leading-dot shorthand
/// would silently resolve to the wrong colour.
extension LedgePalette {
    static let primary = LedgePalette(
        face: ZColor.primary,
        pressedFace: ZColor.primaryPress,
        ledge: ZColor.primaryShadow,
        foreground: ZColor.textOnColor,
    )

    static let accent = LedgePalette(
        face: ZColor.accent,
        pressedFace: ZColor.accentPress,
        ledge: ZColor.accentShadow,
        foreground: ZColor.textOnColor,
    )

    /// Sun yellow has no 700 shade; `--color-reward-shadow` is `--sun-600`,
    /// and the label goes dark on it.
    static let reward = LedgePalette(
        face: ZColor.reward,
        pressedFace: ZColor.sun500,
        ledge: ZColor.rewardShadow,
        foreground: ZColor.textOnReward,
    )

    /// `--color-info`. The token layer has no `infoPress`/`infoShadow`, so the
    /// two darker steps come straight from the clay ramp, as in the JSX.
    static let clay = LedgePalette(
        face: ZColor.info,
        pressedFace: ZColor.clay600,
        ledge: ZColor.clay700,
        foreground: ZColor.textOnColor,
    )

    static let quiet = LedgePalette(
        face: ZColor.white,
        pressedFace: ZColor.cream100,
        ledge: ZColor.sand300,
        foreground: ZColor.textStrong,
        isOutlined: true,
    )
}

/// Presses a capsule down onto its ledge.
///
/// The whole geometry — the ledge included — stays inside the layout bounds,
/// so a button never shifts the views around it while it is held. That costs
/// one thing worth knowing: the laid-out height is the face height *plus*
/// ``depth`` (70 / 106 / 130 pt for the three ``ZButton/Size`` steps), where
/// the CSS `box-shadow` took no space at all. Next to a ledgeless sibling of
/// the same nominal height, align on the top edge rather than the centre.
struct LedgeButtonStyle: ButtonStyle {
    /// How far the face travels on press: `--space-1`, in 90 ms.
    ///
    /// Constant across all sizes, as issue #10 specifies. `Button.jsx` instead
    /// travels `depth − 2` px, which is 4 px only at the smallest size.
    ///
    /// `nonisolated`, like ``disabledOpacity``: `ButtonStyle` carries main
    /// actor isolation, and these two are plain constants, not UI state.
    nonisolated static let travel = ZSpacing.step1

    /// A disabled pressable, from the JSX. `design/tokens/` carries no
    /// disabled state, so this opacity is the one value without a token.
    nonisolated static let disabledOpacity = 0.45

    let palette: LedgePalette
    let depth: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        Face(palette: palette, depth: depth, isPressed: configuration.isPressed) {
            configuration.label
        }
    }
}

/// The pressed and unpressed rendering, written as a `View` rather than inline
/// in ``LedgeButtonStyle/makeBody(configuration:)`` because `@Environment` is
/// only read reliably from a view's body, not from a `ButtonStyle`.
private struct Face<Label: View>: View {
    @Environment(\.isEnabled) private var isEnabled

    let palette: LedgePalette
    let depth: CGFloat
    let isPressed: Bool
    @ViewBuilder let label: Label

    var body: some View {
        label
            .foregroundStyle(palette.foreground)
            .background {
                Capsule().fill(isPressed ? palette.pressedFace : palette.face)
            }
            .overlay {
                if palette.isOutlined {
                    Capsule().strokeBorder(ZColor.borderStrong, lineWidth: ZBorder.width)
                }
            }
            // `offset` moves the face without touching the layout, so the ledge
            // below stays where it is and the buttons around this one do not
            // shift while it is held.
            .offset(y: isPressed ? LedgeButtonStyle.travel : 0)
            .background {
                // A background, not a `ZStack` sibling: it is handed the
                // label's own size instead of stretching into whatever the
                // surrounding stack happens to offer. Hidden by opacity rather
                // than by an `if`, so enabling a button animates instead of
                // rebuilding the subtree.
                Capsule()
                    .fill(palette.ledge)
                    .opacity(isEnabled ? 1 : 0)
                    .offset(y: depth)
            }
            // Keeps the ledge inside the button's own bounds and makes it part
            // of the touch target.
            .padding(.bottom, depth)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : LedgeButtonStyle.disabledOpacity)
            .animation(ZMotion.easeOut.animation(duration: ZMotion.instant), value: isPressed)
    }
}

#Preview("Ledge — rest and pressed") {
    // The only way to see both states side by side: a `ButtonStyle` cannot be
    // put into its pressed state from the outside. The real buttons in the
    // other previews press interactively in the Xcode canvas.
    VStack(alignment: .leading, spacing: ZSpacing.step5) {
        ForEach(ZButton.Tone.allCases, id: \.self) { tone in
            HStack(spacing: ZSpacing.step5) {
                ForEach([false, true], id: \.self) { pressed in
                    Face(palette: tone.palette, depth: ZShadow.ledgeOffset, isPressed: pressed) {
                        Text(pressed ? "pressed" : "at rest")
                            .font(ZType.Step.label.font(.display, weight: .bold))
                            .padding(.horizontal, ZSpacing.step5)
                            .frame(minHeight: ZSpacing.touchMinimum)
                    }
                }
            }
        }
    }
    .padding(ZSpacing.step6)
    .background(ZColor.surfacePage)
}
