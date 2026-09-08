import SwiftUI
import Testing
@testable import ZilpZalpUI

/// The titles the German catalog holds today, longest last.
///
/// File scope rather than a member of the suite: `@Test(arguments:)` reads
/// them from outside the actor, which a `@MainActor` suite does not allow.
private let catalogTitles = [
    "Fotos & Dank",
    "Wie heißt du?",
    "Unser Schwarm",
    "Meine Sammlung",
    "Für Erwachsene",
    "Wer spielt heute?",
    "Deine Vogel-Leiter",
]

/// A roomy width, so nothing in the height tests is decided by a squeeze.
private let regularWidth: CGFloat = 768

/// What a title gets on an iPhone SE with both side slots filled:
/// 375 − 2 × 16 gutter − 2 × 24 gap − 2 × 64 button.
private let compactTitleWidth = TopBarRow.slots(
    leadingWidth: ZSpacing.touchMinimum,
    trailingWidth: ZSpacing.touchMinimum,
    spacing: TopBarMetrics.slotSpacing,
).center(in: 375 - 2 * TopBarMetrics.compactGutter)

/// The smallest the title may ever get: the caption step.
private let captionFloor = ZType.Step.headline.size * TopBarTitle.minimumScaleFactor

/// What the bar measures and how it divides its row — the two things #93 was
/// about.
///
/// The heights are rendered rather than computed: `ImageRenderer` lays the
/// real view out and reports the size it would draw, so a change to the
/// padding or to the title's line box fails here rather than on a device.
/// The widths are arithmetic against CoreText, because a truncated `Text`
/// reports the width it was given — a headless render cannot see an
/// ellipsis. The screenshots in the pull request cover that half.
@MainActor
@Suite("Top bar")
struct TopBarTests {
    // MARK: - Height

    @Test("A bar with a title measures the 60 pt the design draws")
    func aTitleGivesTheBarTheDesignsHeight() {
        // `--space-4` above and below `--text-headline` at line-height 1:
        // 16 + 28 + 16.
        let height = renderedSize(TopBar(title: "Für Erwachsene")).height

        #expect(abs(height - 60) < 0.5, "the bar rendered \(height) pt, not 60")
    }

    @Test("The same title through the generic slot still takes Baloo 2's own box")
    func theGenericSlotKeepsTheFacesBox() throws {
        try #require(BundledFonts.registered)

        // The bug, kept as a control: the centre inherits the headline step
        // but no line box, so Baloo 2 lays the line out in 28 × 1.602 and
        // takes the bar to about 77 pt. No screen goes this way any more,
        // and the number is here so that it cannot come back unnoticed —
        // it is why a title has its own entry point rather than a fix to
        // the generic slot, which has to stay generic for `QuizProgress`
        // and the wordmark.
        let height = renderedSize(TopBar(center: { Text(verbatim: "Für Erwachsene") })).height

        #expect(
            height > 70,
            "the generic centre rendered \(height) pt — the control no longer holds",
        )
        #expect(abs(height - (ZType.Step.headline.naturalBoxHeight(for: .display) + 32)) < 1)
    }

    @Test("A 64 pt button sets the height, and a wordless centre adds nothing")
    func theTallestSlotSetsTheHeight() {
        let height = renderedSize(
            TopBar(title: "Für Erwachsene") {
                Color.clear.frame(width: ZSpacing.touchMinimum, height: ZSpacing.touchMinimum)
            },
        ).height

        #expect(
            abs(height - (ZSpacing.touchMinimum + 32)) < 0.5,
            "the bar rendered \(height) pt, not 96",
        )
    }

    @Test("A wordless centre is sized by the row, not the other way round")
    func theQuizCentreIsUnaffected() {
        // The quiz call site: a back button beside the leaf row. The row's
        // width changed with #93 — the centre is now offered what the sides
        // do not need rather than a third of the bar — and this is what says
        // that made no difference to content whose width is its own. Ten
        // 44 pt leaves are 548 pt wide however they are asked.
        let height = renderedSize(
            TopBar {
                Color.clear.frame(width: ZSpacing.touchMinimum, height: ZSpacing.touchMinimum)
            } center: {
                QuizProgress(total: 10, completed: 2, current: 2, label: "Fortschritt")
            },
        ).height

        #expect(abs(height - (ZSpacing.touchMinimum + 32)) < 0.5, "the bar rendered \(height) pt")
    }

    // MARK: - The row

    @Test("Both sides reserve what the wider of them needs, so the centre stays on the midline")
    func theCentreStaysOnTheMidline() {
        // One slot filled — the grown-ups' area and the credits screen. The
        // JSX reserves the same width on the empty side; without that the
        // title would sit 44 pt right of the bar's middle.
        //
        // The width is a named `CGFloat` rather than a literal: inside
        // `#expect` a literal-only expression is inferred as `Int`, and
        // `343 / 2` would then quietly be 171.
        let barWidth: CGFloat = 343
        let slots = TopBarRow.slots(
            leadingWidth: ZSpacing.touchMinimum,
            trailingWidth: 0,
            spacing: TopBarMetrics.slotSpacing,
        )

        #expect(slots.side == ZSpacing.touchMinimum)
        #expect(slots.reserved == 2 * ZSpacing.touchMinimum + 2 * TopBarMetrics.slotSpacing)

        // The centre's own middle is the bar's middle: the reserve and the
        // gap are the same on both sides.
        let leftEdge = slots.side + TopBarMetrics.slotSpacing
        #expect(leftEdge + slots.center(in: barWidth) / 2 == barWidth / 2)
    }

    @Test("A bar with nothing beside the title spends no width on gaps")
    func anEmptyRowHasNoGaps() {
        let barWidth: CGFloat = 343
        let slots = TopBarRow.slots(
            leadingWidth: 0,
            trailingWidth: 0,
            spacing: TopBarMetrics.slotSpacing,
        )

        #expect(slots.side == 0)
        #expect(slots.reserved == 0)
        #expect(slots.center(in: barWidth) == barWidth)
    }

    @Test("The centre is never handed a negative width")
    func theCentreNeverGoesNegative() {
        let slots = TopBarRow.slots(
            leadingWidth: ZSpacing.touchMinimum,
            trailingWidth: ZSpacing.touchMinimum,
            spacing: TopBarMetrics.slotSpacing,
        )

        #expect(slots.center(in: 100) == 0)
    }

    // MARK: - Width, at the narrowest screen there is

    @Test(
        "Every title in the catalog fits an iPhone SE without an ellipsis",
        arguments: catalogTitles,
    )
    func everyTitleFitsTheNarrowestScreen(title: String) throws {
        try #require(BundledFonts.registered)

        let smallest = BundledFonts.width(
            of: title,
            postScriptName: "Baloo2-Bold",
            size: captionFloor,
        )

        #expect(
            smallest <= compactTitleWidth,
            "\(title) needs \(smallest) pt even at the caption floor, and the bar offers \(compactTitleWidth)",
        )
    }

    @Test(
        "No title in the catalog has to shrink below the kid-facing floor",
        arguments: catalogTitles,
    )
    func noTitleShrinksBelowTwentyPoints(title: String) throws {
        try #require(BundledFonts.registered)

        // The scale factor is a guard, not a target: SwiftUI shrinks only as
        // far as it must. The longest title today lands on 20 pt, which is
        // ``ZType/Step/body`` — the smallest size anything a child reads is
        // allowed to take. An eighth title longer than that is a design
        // decision, and this is where it reports itself.
        let natural = BundledFonts.width(
            of: title,
            postScriptName: "Baloo2-Bold",
            size: ZType.Step.headline.size,
        )
        let rendered = min(
            ZType.Step.headline.size,
            ZType.Step.headline.size * compactTitleWidth / natural,
        )

        #expect(
            rendered >= ZType.Step.body.size,
            "\(title) would render at \(rendered) pt on an iPhone SE",
        )
    }

    @Test("The iPad gutter is what starved the centre")
    func theIPadGutterCouldNotFitTheTitle() throws {
        try #require(BundledFonts.registered)

        // The control for ``TopBarMetrics/compactGutter``: with 48 pt on
        // each side the centre is 103 pt, and "Für Erwachsene" needs 114.5
        // even at the caption floor. That is the "Für Erwac…" in #93, and no
        // scale factor reaches it.
        let starved = TopBarRow.slots(
            leadingWidth: ZSpacing.touchMinimum,
            trailingWidth: ZSpacing.touchMinimum,
            spacing: TopBarMetrics.slotSpacing,
        ).center(in: 375 - 2 * ZSpacing.gutterScreen)

        #expect(starved == 103)
        #expect(BundledFonts.width(
            of: "Für Erwachsene",
            postScriptName: "Baloo2-Bold",
            size: captionFloor,
        ) > starved)
    }

    @Test("The title never shrinks past the smallest size the design allows")
    func theScaleFactorStopsAtTheCaptionStep() {
        #expect(captionFloor == ZType.Step.caption.size)
    }

    // MARK: - Helpers

    /// The size the view lays out to at ``regularWidth``, without drawing it.
    private func renderedSize(_ view: some View) -> CGSize {
        var measured = CGSize.zero
        ImageRenderer(content: view.frame(width: regularWidth))
            .render { size, _ in measured = size }
        return measured
    }
}
