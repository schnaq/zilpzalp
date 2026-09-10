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
/// A screen with a title passes it as `TopBar(title:)` and gets
/// ``TopBarTitle`` in the centre — the design's line box, one line, and the
/// whole row minus what the side slots need. The generic centre slot stays
/// for content that draws itself — the wordmark on the profile picker is the
/// one screen that still takes it up; the quiz gave it back when its bar took
/// the game's name and its leaf row moved underneath (#220).
///
/// That slot still inherits the grown-up title style, so a stray `Text`
/// there is typeset rather than left at the system font — but in the face's
/// own line box, which is the 77 pt bar #93 was about. No screen takes it up
/// any more; it stays as the softer failure for a title put in the wrong
/// slot, and `TopBarTests` pins it so the difference cannot go quiet.
///
/// Placement stays with the caller. The bar draws itself and nothing else;
/// pinning it above a scroll view and letting it reach into the safe area is
/// a screen decision, not a component one.
public struct TopBar<Leading: View, Center: View, Trailing: View>: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

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

    /// The screen margin the bar keeps.
    ///
    /// `--gutter-screen` is the iPad safe margin. On a phone it is 96 pt of
    /// the 375 the narrowest supported screen has, which is what starved the
    /// centre until the title read "Für Erwac…" — see
    /// ``TopBarMetrics/compactGutter``.
    ///
    /// Nothing outside iOS sets a size class, so a `swift test` render and a
    /// macOS preview both take the roomy branch unless they say otherwise —
    /// which they can: the key exists on every platform the package builds
    /// for, and `TopBarTests` sets it to measure the phone geometry.
    private var gutter: CGFloat {
        horizontalSizeClass == .compact ? TopBarMetrics.compactGutter : ZSpacing.gutterScreen
    }

    public var body: some View {
        TopBarRow(spacing: TopBarMetrics.slotSpacing) {
            // Each slot is wrapped in an `HStack` so that the row always has
            // exactly three subviews to place. A `Layout` never sees an
            // `EmptyView` — SwiftUI drops it before the layout runs — so an
            // unwrapped empty slot would shift the two others onto the wrong
            // positions.
            HStack(spacing: 0) { leading }

            HStack(spacing: ZSpacing.step4) {
                center
            }
            // Not `singleLine`: this sets the type for whatever the caller
            // puts in the centre — a progress row as readily as a title —
            // and a fixed line box would size that content too. A title
            // takes ``TopBarTitle``, which brings its own box.
            .typeStyle(.headline, .display, weight: .bold)
            .foregroundStyle(ZColor.textStrong)

            HStack(spacing: 0) { trailing }
        }
        .padding(.vertical, ZSpacing.step4)
        .padding(.horizontal, gutter)
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

public extension TopBar where Center == TopBarTitle {
    /// A bar whose centre is a title.
    ///
    /// The typed entry point. It exists because the generic slot cannot both
    /// stay generic and give a title the design's box: the centre inherits
    /// the headline step but not a line box, so a `Text` there was laid out
    /// in Baloo 2's own 44.9 pt box and took the bar to 77 pt.
    ///
    /// - Parameter title: Already resolved — the package carries no product
    ///   text. Screens pass `String(localized:)`, as they do for the icon
    ///   button labels.
    init(
        title: String,
        @ViewBuilder leading: () -> Leading = { EmptyView() },
        @ViewBuilder trailing: () -> Trailing = { EmptyView() },
    ) {
        self.init(leading: leading, center: { TopBarTitle(title) }, trailing: trailing)
    }
}

/// The title in a ``TopBar``'s centre: display face, headline step, bold, one
/// line, in the box the design draws.
///
/// Public because ``TopBar/init(title:leading:trailing:)`` names it in its
/// `where` clause. A screen that needs a title *and* something else in the
/// centre can put it in the generic slot itself.
public struct TopBarTitle: View {
    /// How far the title may shrink before it would rather break: down to
    /// `--text-caption`, the smallest size the design allows anywhere, and
    /// grown-ups-only at that.
    ///
    /// A guard, not a target. SwiftUI shrinks only as far as it must, and on
    /// the narrowest supported screen it does not have to go nearly this
    /// far: the longest title in the catalog, "Deine Vogel-Leiter", needs
    /// 0.72 at 375 pt with both side slots filled — 20 pt, the floor for
    /// anything a child reads.
    nonisolated static let minimumScaleFactor: CGFloat =
        ZType.Step.caption.size / ZType.Step.headline.size

    private let title: String

    public init(_ title: String) {
        self.title = title
    }

    public var body: some View {
        Text(verbatim: title)
            .typeStyle(.headline, .display, weight: .bold)
            .lineLimit(1)
            .minimumScaleFactor(Self.minimumScaleFactor)
            .foregroundStyle(ZColor.textStrong)
            // `var(--text-headline)/1` in the JSX — the bar's title is the
            // one place the design tightens the line box to the type size,
            // and it is what makes the bar 60 pt. Deliberately not
            // `typeStyle(singleLine:)`, which applies `--lh-headline` (1.2)
            // and would leave the bar at 65.6 pt.
            .frame(height: ZType.Step.headline.size)
    }
}

/// The bar's row: the side slots take what they need, the centre takes the
/// rest, and the centre stays on the bar's midline whatever sits beside it.
///
/// An `HStack` cannot do both halves of that. Giving both outer slots
/// `maxWidth: .infinity` keeps the midline but splits the row in three, so on
/// a phone the centre got about a third of the width and the title
/// truncated; letting the slots size to their content gives the centre the
/// rest but drops it off the midline as soon as only one slot is filled.
///
/// So the row reserves `max(leading, trailing)` on *both* sides — literally
/// what the JSX does with its `<span style={{ width: 72 }} />` on the empty
/// side — and hands everything that is left to the centre.
struct TopBarRow: Layout {
    /// The gap between a side slot and the centre. Not counted when both
    /// side slots are empty: a bar with only a title has no gap to draw.
    let spacing: CGFloat

    /// How the row divides a width. Pure, so the arithmetic can be tested
    /// without a render, and in one place, so the two `Layout` methods cannot
    /// drift apart.
    struct Slots {
        /// Reserved on the left *and* on the right.
        let side: CGFloat
        /// What both reserves and both gaps take together.
        let reserved: CGFloat

        /// What is left for the centre.
        func center(in barWidth: CGFloat) -> CGFloat {
            max(0, barWidth - reserved)
        }
    }

    static func slots(leadingWidth: CGFloat, trailingWidth: CGFloat, spacing: CGFloat) -> Slots {
        let side = max(leadingWidth, trailingWidth)
        // A bar with nothing beside the centre has no gap to draw.
        return Slots(side: side, reserved: side > 0 ? 2 * (side + spacing) : 0)
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let leading = subviews[0].sizeThatFits(.unspecified)
        let trailing = subviews[2].sizeThatFits(.unspecified)
        let slots = Self.slots(
            leadingWidth: leading.width,
            trailingWidth: trailing.width,
            spacing: spacing,
        )

        // Without a width to divide — a `fixedSize`, a sizing pass, an
        // infinite proposal — the row asks for what its three slots want
        // side by side.
        let width: CGFloat = if let offered = proposal.width, offered.isFinite {
            offered
        } else {
            slots.reserved + subviews[1].sizeThatFits(.unspecified).width
        }

        // The centre is measured against the width it will actually get: a
        // title that has to shrink still reports the same box, but content
        // that wraps would not.
        let centerHeight = subviews[1]
            .sizeThatFits(ProposedViewSize(width: slots.center(in: width), height: proposal.height))
            .height

        return CGSize(width: width, height: max(leading.height, centerHeight, trailing.height))
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout (),
    ) {
        let slots = Self.slots(
            leadingWidth: subviews[0].sizeThatFits(.unspecified).width,
            trailingWidth: subviews[2].sizeThatFits(.unspecified).width,
            spacing: spacing,
        )

        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.midY),
            anchor: .leading,
            proposal: ProposedViewSize(width: slots.side, height: bounds.height),
        )
        subviews[1].place(
            at: CGPoint(x: bounds.midX, y: bounds.midY),
            anchor: .center,
            proposal: ProposedViewSize(
                width: slots.center(in: bounds.width),
                height: bounds.height,
            ),
        )
        subviews[2].place(
            at: CGPoint(x: bounds.maxX, y: bounds.midY),
            anchor: .trailing,
            proposal: ProposedViewSize(width: slots.side, height: bounds.height),
        )
    }
}

/// The values the bar needs that no token carries. They sit beside the type
/// rather than inside it because ``TopBar`` is generic, and a generic type
/// cannot hold a static stored property.
enum TopBarMetrics {
    /// `color-mix(in oklab, var(--cream-50) 90%, transparent)` from the JSX:
    /// the cream sits at 90 % so the blurred content stays readable.
    static let tintOpacity: Double = 0.9

    /// The screen margin on a compact width.
    ///
    /// `--gutter-screen` is 48 pt on each side, which a 375 pt phone cannot
    /// spare: with two 64 pt buttons beside it the title was left 103 pt, and
    /// no scale factor down to the caption step fits "Für Erwachsene" into
    /// that. `--space-4` leaves 167 pt, which every title in the catalog
    /// fits. The same step down that `QuizScreen` and the collection screens
    /// already make with their own gutters.
    static let compactGutter: CGFloat = ZSpacing.step4

    /// The gap between a side slot and the centre, `--space-5` from the JSX.
    static let slotSpacing: CGFloat = ZSpacing.step5
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
            // Stands in for content that draws itself and brings its own
            // width, which is what the generic centre slot is for.
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
        TopBar(title: "Für Erwachsene") {
            PreviewSlotButton(icon: .chevronLeft)
        }

        Spacer()
    }
    .background(ZColor.surfacePage)
}

// The case #93 was opened for: the longest title in the catalog, both side
// slots filled with 64 pt buttons, at the width of the narrowest supported
// screen. The title has to stay on one line, on the midline, unclipped.
//
// The size class is set rather than left to the canvas, because the width
// alone does not carry it — and the compact gutter is half of what this
// preview is here to show.
#Preview("Worst case — iPhone SE width") {
    VStack(spacing: 0) {
        TopBar(title: "Deine Vogel-Leiter") {
            PreviewSlotButton(icon: .chevronLeft)
        } trailing: {
            PreviewSlotButton(icon: .userRoundCog)
        }

        Spacer()
    }
    .frame(width: 375)
    .environment(\.horizontalSizeClass, .compact)
    .background(ZColor.surfacePage)
}

#Preview("Every slot empty") {
    VStack(spacing: 0) {
        TopBar()

        Spacer()
    }
    .background(ZColor.surfacePage)
}
