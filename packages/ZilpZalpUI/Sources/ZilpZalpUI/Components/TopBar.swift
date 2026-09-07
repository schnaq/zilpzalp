import SwiftUI

/// The fixed header of every screen: a back door on the left, a wordless
/// centre, the grown-ups door on the right.
///
/// Ported from `design/components/navigation/TopBar.jsx`. The bar is the one
/// translucent surface in the system — 90 % cream over a blur, so content
/// scrolls underneath it instead of vanishing at a hard edge.
///
/// All three slots are `ViewBuilder` content, so the bar never learns what it
/// carries: the app puts a back button on the left, a progress view or the
/// wordmark in the centre, the grown-ups button on the right. Every slot is
/// optional and defaults to nothing.
///
/// The centre inherits the grown-up title style — display face, headline
/// step, bold, strong ink — so a screen that wants a title passes a plain
/// `Text` and gets it typeset correctly, while a view that draws itself
/// (progress, wordmark) ignores the inherited font. Kid screens keep the
/// centre wordless.
///
/// Placement stays with the caller. The bar draws itself and nothing else;
/// pinning it above a scroll view and letting it reach into the safe area is
/// a screen decision, not a component one.
public struct TopBar<Leading: View, Center: View, Trailing: View>: View {
    private let leading: Leading
    private let center: Center
    private let trailing: Trailing

    public init(
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder center: () -> Center = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
    ) {
        self.leading = leading()
        self.center = center()
        self.trailing = trailing()
    }

    public var body: some View {
        HStack(spacing: ZSpacing.step5) {
            // Both outer slots claim the same share of the row, so the centre
            // stays on the screen's midline whatever sits beside it.
            leading
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack(spacing: ZSpacing.step4) {
                center
            }
            .font(ZType.Step.headline.font(.display, weight: .bold))
            .foregroundStyle(ZColor.textStrong)

            trailing
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, ZSpacing.step4)
        .padding(.horizontal, ZSpacing.gutterScreen)
        .background {
            ZColor.cream50
                .opacity(TopBarMetrics.tintOpacity)
                .background(.ultraThinMaterial)
                .overlay(alignment: .bottom) {
                    ZColor.borderCard
                        .frame(height: ZBorder.width)
                }
        }
    }
}

/// The one value the bar needs that no token carries. It sits beside the type
/// rather than inside it because ``TopBar`` is generic, and a generic type
/// cannot hold a static stored property. There will never be a second
/// consumer: the design allows exactly one translucent surface in the system.
private enum TopBarMetrics {
    /// `color-mix(in oklab, var(--cream-50) 90%, transparent)` from the JSX:
    /// the cream sits at 90 % so the blurred content stays readable.
    static let tintOpacity: Double = 0.9
}

// MARK: - Previews

/// Stands in for `IconButton`, which another pull request is building right
/// now. A glyph on a circle is enough to show that a slot holds content.
private struct PreviewSlotButton: View {
    let icon: ZIcon

    var body: some View {
        Icon(icon, size: .large)
            .foregroundStyle(ZColor.textOnColor)
            .frame(width: ZSpacing.touchMinimum, height: ZSpacing.touchMinimum)
            .background(ZColor.primary, in: Circle())
    }
}

#Preview("Kid screen — wordless centre") {
    VStack(spacing: 0) {
        TopBar {
            PreviewSlotButton(icon: .chevronLeft)
        } center: {
            // Stands in for `QuizProgress`, which arrives with the quiz
            // components.
            ForEach(0 ..< 5) { step in
                Circle()
                    .fill(step < 2 ? ZColor.primary : ZColor.sand300)
                    .frame(width: ZSpacing.step5, height: ZSpacing.step5)
            }
        } trailing: {
            PreviewSlotButton(icon: .userRoundCog)
        }

        ScrollView {
            VStack(spacing: ZSpacing.step4) {
                ForEach(0 ..< 12) { row in
                    RoundedRectangle(cornerRadius: ZRadius.card, style: .continuous)
                        .fill(row.isMultiple(of: 2) ? ZColor.olive200 : ZColor.orange200)
                        .frame(height: ZSpacing.step9)
                }
            }
            .padding(ZSpacing.step6)
        }
    }
    .background(ZColor.surfacePage)
}

#Preview("Grown-up screen — title in the centre") {
    VStack(spacing: 0) {
        TopBar {
            PreviewSlotButton(icon: .chevronLeft)
        } center: {
            Text(verbatim: "Für Erwachsene")
        }

        Spacer()
    }
    .background(ZColor.surfacePage)
}

#Preview("Every slot empty") {
    VStack(spacing: 0) {
        TopBar()

        Spacer()
    }
    .background(ZColor.surfacePage)
}
