import SwiftUI
import Testing
@testable import ZilpZalpUI

/// The gap between the title and the trailing slot — ``SettingRow`` passes
/// `--space-4`, and the rule is written against it.
private let spacing = ZSpacing.step4

/// What a settings row leaves its text at a given screen width on a phone:
/// the compact gutter on both sides, the card's outline, the row's own
/// padding, and the icon's column.
private func textColumn(at screen: CGFloat, gutter: CGFloat = ZSpacing.step4) -> CGFloat {
    screen
        - 2 * gutter
        - 2 * ZBorder.width
        - 2 * ZSpacing.step5
        - (Icon.Size.standard.points + spacing)
}

/// One line of a row's title, in the face and step ``SettingRow`` sets.
private func titleWidth(_ title: String) -> CGFloat {
    BundledFonts.width(of: title, postScriptName: "Nunito-Bold", size: ZType.Step.body.size)
}

/// A value and the chevron behind it: the whole trailing slot of a navigation
/// row, gap included.
private func valueWidth(_ value: String) -> CGFloat {
    BundledFonts.width(of: value, postScriptName: "Nunito-SemiBold", size: ZType.Step.body.size)
        + ZSpacing.step2
        + Icon.Size.small.points
}

/// How ``SettingRow`` divides its width — the decision #142 is about.
///
/// Arithmetic rather than pixels:
/// ``SettingRowLayout/choose(sizeClass:textWidth:titleWidth:trailingWidth:spacing:)``
/// is the whole rule, and a rendered bitmap cannot be asked which of the
/// three it drew. What the strings actually measure comes from CoreText with
/// the bundled faces registered, exactly as `TopBarTests` measures titles;
/// that the row is wired to the rule at all is the one case at the bottom
/// that goes through ``renderedSize(_:width:)``, and the screenshots in the
/// pull request cover how it looks.
@MainActor
@Suite("Setting row layout")
struct SettingRowLayoutTests {
    // MARK: - The rule

    @Test("A regular width keeps the design's three columns")
    func aRegularWidthKeepsTheColumns() {
        #expect(SettingRowLayout.choose(
            sizeClass: .regular,
            textWidth: 200,
            titleWidth: 400,
            trailingWidth: 120,
            spacing: spacing,
        ) == .columns)
    }

    @Test("No size class at all takes the roomy branch")
    func noSizeClassTakesTheRoomyBranch() {
        // A `swift test` render and a macOS preview set none — the same
        // branch `TopBar` gives them for its gutter. Only iOS says compact,
        // and only there does the row stack.
        #expect(SettingRowLayout.choose(
            sizeClass: nil,
            textWidth: 100,
            titleWidth: 400,
            trailingWidth: 120,
            spacing: spacing,
        ) == .columns)
    }

    @Test("A switch row stacks without ever taking a line for its switch")
    func aSwitchRowNeverTakesATrailingLine() {
        // The trailing slot of a switch row is empty: `Toggle` places the
        // switch, on the middle of the label. Whatever the width, there is
        // nothing here to move onto a line of its own.
        for width in [CGFloat(40), 256, 1000] {
            #expect(SettingRowLayout.choose(
                sizeClass: .compact,
                textWidth: width,
                titleWidth: 400,
                trailingWidth: 0,
                spacing: spacing,
            ) == .rows)
        }
    }

    @Test("The value shares the title's line while both fit on it")
    func theValueSharesTheLineWhileItFits() {
        let title: CGFloat = 100
        let value: CGFloat = 120

        // Exactly full still counts as fitting, and one point more does not.
        #expect(SettingRowLayout.choose(
            sizeClass: .compact,
            textWidth: title + spacing + value,
            titleWidth: title,
            trailingWidth: value,
            spacing: spacing,
        ) == .rows)
        #expect(SettingRowLayout.choose(
            sizeClass: .compact,
            textWidth: title + spacing + value - 1,
            titleWidth: title,
            trailingWidth: value,
            spacing: spacing,
        ) == .rowsWithTrailingLine)
    }

    // MARK: - The row the issue was opened for

    @Test("The time budget takes a trailing line on a 390 pt phone")
    func theTimeBudgetTakesATrailingLineOnAPhone() throws {
        try #require(BundledFonts.registered)

        // "Spielzeit pro Tag" needs 155.8 pt and "Kein Limit ›" 122.4, which
        // is 294.2 with the gap between them against a text column of 256.
        // So the value goes to a line of its own and the title gets the
        // column — one line, where it took four before (#142).
        #expect(SettingRowLayout.choose(
            sizeClass: .compact,
            textWidth: textColumn(at: 390),
            titleWidth: titleWidth("Spielzeit pro Tag"),
            trailingWidth: valueWidth("Kein Limit"),
            spacing: spacing,
        ) == .rowsWithTrailingLine)

        #expect(titleWidth("Spielzeit pro Tag") <= textColumn(at: 390))
    }

    @Test("The same row keeps its value on the title's line on a big phone")
    func theTimeBudgetStaysInlineOnABigPhone() throws {
        try #require(BundledFonts.registered)

        // An iPhone 17 Pro Max is 440 pt across, which leaves 306 — enough
        // for the pair. The rule is the width, not the device.
        #expect(SettingRowLayout.choose(
            sizeClass: .compact,
            textWidth: textColumn(at: 440),
            titleWidth: titleWidth("Spielzeit pro Tag"),
            trailingWidth: valueWidth("Kein Limit"),
            spacing: spacing,
        ) == .rows)
    }

    @Test("A short value and a short title stay on one line at 375 pt")
    func aShortPairStaysOnOneLine() throws {
        try #require(BundledFonts.registered)

        // "Sprache" and "Deutsch" need 198.3 pt together on the narrowest
        // phone's 241 — the row that never had the problem, and it does not
        // get a taller shape for nothing.
        #expect(SettingRowLayout.choose(
            sizeClass: .compact,
            textWidth: textColumn(at: 375),
            titleWidth: titleWidth("Sprache"),
            trailingWidth: valueWidth("Deutsch"),
            spacing: spacing,
        ) == .rows)
    }

    @Test("The iPad gutter and the iPad columns are what broke the title")
    func theIPadRowStarvedTheTitle() throws {
        try #require(BundledFonts.registered)

        // The control, kept as the number in the issue: behind
        // `--gutter-screen` and beside its value, the title of the time
        // budget was offered 53.6 pt of a 390 pt phone — a third of the
        // 155.8 it needs, which is the four lines in the screenshot.
        let starved = textColumn(at: 390, gutter: ZSpacing.gutterScreen)
            - valueWidth("Kein Limit")
            - spacing

        #expect(starved < 60)
        #expect(starved < titleWidth("Spielzeit pro Tag") / 2)
    }

    // MARK: - Wired up

    @Test("Stacked, the row that broke over four lines is the shorter one")
    func theStackedRowIsTheShorterOne() throws {
        try #require(BundledFonts.registered)

        // End to end rather than arithmetic: the same row at the same phone
        // width, and only the size class between the two renders. Three
        // lines of full width cost less height than two columns that both
        // wrap — which is the fix, and that the numbers differ at all is
        // what proves the row consults the rule.
        let row = SettingRow(
            title: "Spielzeit pro Tag",
            hint: "Danach schlafen die Vögel",
            icon: .clock,
            value: "Kein Limit",
            showsSeparator: false,
        ) {}
        let width = textColumn(at: 390) + Icon.Size.standard.points + spacing + 2 * ZSpacing.step5

        let stacked = renderedSize(
            row.environment(\.horizontalSizeClass, .compact),
            width: width,
        ).height
        let columns = renderedSize(
            row.environment(\.horizontalSizeClass, .regular),
            width: width,
        ).height

        #expect(stacked < columns, "the phone row rendered \(stacked) pt, the iPad row \(columns)")
        // Still a row a four-year-old's parent can hit, whatever the type
        // does: `--touch-min` holds every row at 64 pt.
        #expect(stacked >= ZSpacing.touchMinimum)
    }
}
