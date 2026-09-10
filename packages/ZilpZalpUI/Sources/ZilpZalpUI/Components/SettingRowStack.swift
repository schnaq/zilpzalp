import SwiftUI

/// The shape a ``SettingRow`` takes.
///
/// The design draws one row: icon, text, value — three columns. That row is an
/// iPad row. On a phone the same three columns behind the same 48 pt gutter
/// leave the text about 54 pt at 390 pt, so "Spielzeit pro Tag" broke over
/// four lines and its hint broke mid-word (#142). Below the regular size class
/// the row keeps a column for the icon alone and stacks the rest.
///
/// An accessibility text size does the same thing to an iPad that a phone
/// does to the design's row: the grown-ups' screens scale their type with the
/// system (#239), and at AX1 a title is already wider than the column three
/// of them leave it. So the size counts here beside the size class — the cap
/// in ``ZType/dynamicTypeCap`` says how far the type grows, and this says
/// what the row does about it.
enum SettingRowLayout: Equatable {
    /// Icon, the text block and the trailing slot side by side, each in a
    /// column of its own — the design's row, and what an iPad shows.
    case columns
    /// Icon and title on one line with the trailing slot at its end, the hint
    /// underneath across the whole text column.
    case rows
    /// Icon and title on one line, the hint underneath, the trailing slot on a
    /// line of its own along the trailing edge. For a value that would not
    /// leave the title a line: "Kein Limit ›" on a 390 pt phone.
    case rowsWithTrailingLine

    /// Which of the three, from the size class and the widths involved.
    ///
    /// Pure, so the rule can be read and tested without a render — the same
    /// split ``TopBarRow/slots(leadingWidth:trailingWidth:spacing:)`` makes.
    /// ``SettingRowStack`` measures the widths and asks this.
    ///
    /// - Parameters:
    ///   - sizeClass: `nil` takes the roomy branch, as it does in ``TopBar``:
    ///     nothing outside iOS sets a size class, so a `swift test` render and
    ///     a macOS preview get the iPad row unless they say otherwise.
    ///   - typeSize: The system text size. Anything from AX1 up stacks
    ///     whatever the size class says. The default is the system's own, so
    ///     a caller that does not scale its type need not mention it.
    ///   - textWidth: What is left of the row once the icon has had its column.
    ///   - titleWidth: The title on one line.
    ///   - trailingWidth: The value and its chevron. Zero on a switch row,
    ///     whose switch is placed by `Toggle` and never by this layout — so a
    ///     row without a trailing slot never takes a line for one.
    ///   - spacing: The gap between title and trailing slot.
    static func choose(
        sizeClass: UserInterfaceSizeClass?,
        typeSize: DynamicTypeSize = .large,
        textWidth: CGFloat,
        titleWidth: CGFloat,
        trailingWidth: CGFloat,
        spacing: CGFloat,
    ) -> Self {
        guard sizeClass == .compact || typeSize.isAccessibilitySize else { return .columns }
        guard trailingWidth > 0 else { return .rows }

        // The title is the string here that may not be squeezed: it is what a
        // grown-up looks for, and it is the one that wrapped. So the value
        // shares its line exactly as long as both fit on it, and takes a line
        // of its own otherwise — where the title has the whole column and the
        // value is still where the eye looks for it, on the trailing edge.
        return titleWidth + spacing + trailingWidth <= textWidth ? .rows : .rowsWithTrailingLine
    }
}

/// Which slot of a ``SettingRow`` is which subview. The order is the order of
/// the tree, and the tree is what VoiceOver reads.
///
/// File scope so that the subscript below can name it.
private enum SettingRowSlot: Int {
    case icon, title, hint, trailing
}

/// A ``SettingRow``'s geometry: four slots, and which ``SettingRowLayout``
/// they end up in.
///
/// A `Layout` rather than stacks, because the choice needs a measurement no
/// stack exposes — how wide the title would be on one line, against the width
/// the row actually has. `ViewThatFits` would find the same answer and could
/// not be asked for it; this way the rule is one function that can be tested.
///
/// The slots are always four, in this order: icon, title, hint, trailing. A
/// navigation row is a `Button`, so SwiftUI folds them into the one element
/// #121 settled on and announces them in that order — moving the value under
/// the hint on screen leaves it where it was in the tree.
struct SettingRowStack: Layout {
    let sizeClass: UserInterfaceSizeClass?
    /// The system text size, for the half of the rule that is not the size
    /// class. ``SettingRow`` reads it off the environment.
    let typeSize: DynamicTypeSize
    /// The gap after the icon, and between title and trailing slot.
    let spacing: CGFloat
    /// The gap between title and hint, and above a trailing line.
    let hintSpacing: CGFloat

    /// One pass: what the four slots measure, how the width was divided and
    /// the height that follows. Both `Layout` methods take it from the one
    /// function below rather than dividing the width themselves, so the two
    /// cannot disagree about the shape.
    private struct Pass {
        let layout: SettingRowLayout
        /// Where title and hint start: the icon's column, or 0 without one.
        let indent: CGFloat
        let icon: CGSize
        /// The title's own size at ``titleWidth``, and the hint's at
        /// ``hintWidth`` — a text reports what it needs, not what it was
        /// offered.
        let title: CGSize
        let hint: CGSize
        let trailing: CGSize
        /// What title and hint were offered. Kept so that placing them can
        /// propose the same width they were measured against: proposing the
        /// width a text reported instead is how a line that fitted comes back
        /// wrapped, half a point short of itself.
        let titleWidth: CGFloat
        let hintWidth: CGFloat
        /// The line the icon and the title share — with the trailing slot in
        /// ``SettingRowLayout/rows``, without it in the other two.
        let firstLine: CGFloat
        /// Title and hint together, their gap included.
        let textBlock: CGFloat
        let height: CGFloat

        var hasHint: Bool {
            hint.height > 0
        }
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let width = width(from: proposal, subviews: subviews)
        return CGSize(width: width, height: pass(subviews, width: width).height)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal _: ProposedViewSize,
        subviews: Subviews,
        cache _: inout (),
    ) {
        let pass = pass(subviews, width: bounds.width)
        let leading = bounds.minX + pass.indent
        let stacked = pass.layout != .columns

        // In the design's row the three columns are centred against each
        // other, which is what an `HStack` does. In the stacked ones the icon
        // rides the title's line.
        subviews[.icon].place(
            at: CGPoint(
                x: bounds.minX,
                y: stacked ? bounds.minY + pass.firstLine / 2 : bounds.midY,
            ),
            anchor: .leading,
            proposal: ProposedViewSize(pass.icon),
        )

        let titleTop = stacked
            ? bounds.minY + (pass.firstLine - pass.title.height) / 2
            : bounds.midY - pass.textBlock / 2
        subviews[.title].place(
            at: CGPoint(x: leading, y: titleTop),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: pass.titleWidth, height: nil),
        )

        let hintTop = stacked
            ? bounds.minY + pass.firstLine + hintSpacing
            : titleTop + pass.title.height + hintSpacing
        // Placed whether or not there is a hint: a `Layout` owes every
        // subview a place, and an unplaced one is dropped at the container's
        // middle. The empty slot is invisible there today, and would not stay
        // invisible the day it carries something without a height.
        subviews[.hint].place(
            at: CGPoint(x: leading, y: hintTop),
            anchor: .topLeading,
            proposal: ProposedViewSize(width: pass.hintWidth, height: nil),
        )

        switch pass.layout {
        case .columns, .rows:
            // On the row's midline where the columns are centred, on the
            // title's line where they are stacked.
            subviews[.trailing].place(
                at: CGPoint(
                    x: bounds.maxX,
                    y: pass.layout == .rows ? bounds.minY + pass.firstLine / 2 : bounds.midY,
                ),
                anchor: .trailing,
                proposal: ProposedViewSize(pass.trailing),
            )
        case .rowsWithTrailingLine:
            // Under whatever came before it, against the trailing edge.
            let above = pass.hasHint ? hintTop + pass.hint.height : bounds.minY + pass.firstLine
            subviews[.trailing].place(
                at: CGPoint(x: bounds.maxX, y: above + hintSpacing),
                anchor: .topTrailing,
                proposal: ProposedViewSize(pass.trailing),
            )
        }
    }

    /// Measures the four slots against `width` and divides it.
    private func pass(_ subviews: Subviews, width: CGFloat) -> Pass {
        let icon = subviews[.icon].sizeThatFits(.unspecified)
        let trailing = subviews[.trailing].sizeThatFits(.unspecified)
        let indent = column(of: icon.width)
        let trailingColumn = column(of: trailing.width)
        let textWidth = max(0, width - indent)

        let layout = SettingRowLayout.choose(
            sizeClass: sizeClass,
            typeSize: typeSize,
            textWidth: textWidth,
            titleWidth: subviews[.title].sizeThatFits(.unspecified).width,
            trailingWidth: trailing.width,
            spacing: spacing,
        )

        // The title's width is the only one the three disagree about. The
        // hint gets the whole text column, except in the design's row, where
        // it stands beside the trailing slot along with the title.
        let titleWidth = layout == .rowsWithTrailingLine
            ? textWidth
            : max(0, textWidth - trailingColumn)
        let hintWidth = layout == .columns ? titleWidth : textWidth
        let title = subviews[.title]
            .sizeThatFits(ProposedViewSize(width: titleWidth, height: nil))
        let hint = subviews[.hint]
            .sizeThatFits(ProposedViewSize(width: hintWidth, height: nil))

        // A row without a hint has no gap to leave for one.
        let hintBlock = hint.height > 0 ? hintSpacing + hint.height : 0
        let firstLine = layout == .rows
            ? max(icon.height, title.height, trailing.height)
            : max(icon.height, title.height)
        let height: CGFloat = switch layout {
        case .columns: max(icon.height, title.height + hintBlock, trailing.height)
        case .rows: firstLine + hintBlock
        case .rowsWithTrailingLine: firstLine + hintBlock + hintSpacing + trailing.height
        }

        return Pass(
            layout: layout,
            indent: indent,
            icon: icon,
            title: title,
            hint: hint,
            trailing: trailing,
            titleWidth: titleWidth,
            hintWidth: hintWidth,
            firstLine: firstLine,
            textBlock: title.height + hintBlock,
            height: height,
        )
    }

    /// What a slot of this width takes off the row: itself and the gap beside
    /// it, or nothing at all. An empty slot has no gap to draw — the rule
    /// `TopBarRow` has for a bar with nothing beside its centre.
    private func column(of slotWidth: CGFloat) -> CGFloat {
        slotWidth > 0 ? slotWidth + spacing : 0
    }

    /// The width to divide. Without one — a sizing pass, an infinite
    /// proposal — the row asks for what its slots want side by side, exactly
    /// as `TopBarRow` does.
    private func width(from proposal: ProposedViewSize, subviews: Subviews) -> CGFloat {
        if let offered = proposal.width, offered.isFinite {
            return offered
        }

        let icon = subviews[.icon].sizeThatFits(.unspecified).width
        let title = subviews[.title].sizeThatFits(.unspecified).width
        let hint = subviews[.hint].sizeThatFits(.unspecified).width
        let trailing = subviews[.trailing].sizeThatFits(.unspecified).width

        return column(of: icon) + max(title + column(of: trailing), hint)
    }
}

private extension LayoutSubviews {
    /// Reads a slot by name rather than by index.
    subscript(slot: SettingRowSlot) -> LayoutSubview {
        self[slot.rawValue]
    }
}
