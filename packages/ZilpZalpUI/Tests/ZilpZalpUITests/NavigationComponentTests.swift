import SwiftUI
import Testing
@testable import ZilpZalpUI

/// What a navigation component decides before it draws anything: which colours
/// a tone resolves to, how many stars survive, and what a locked tile shows.
/// Only the label goes through a real render, and only to read back the size
/// it was drawn at (#229); how the result looks is what the `#Preview` blocks
/// and the screenshots in the pull request are for.
///
/// The suite is `@MainActor` because SwiftUI's `View` is: constructing a
/// `HomeTile` and reading its properties is main-actor work, even without a
/// window.
@MainActor
@Suite("Navigation components")
struct NavigationComponentTests {
    @Test("Each tile tone resolves to the ramp the JSX names")
    func tileTonesResolveToTheirRamps() {
        #expect(HomeTile.Tone.leaf.palette.background == ZColor.olive100)
        #expect(HomeTile.Tone.leaf.palette.edge == ZColor.primary)
        #expect(HomeTile.Tone.leaf.palette.foreground == ZColor.olive700)

        #expect(HomeTile.Tone.clay.palette.background == ZColor.clay100)
        #expect(HomeTile.Tone.clay.palette.edge == ZColor.info)
        #expect(HomeTile.Tone.clay.palette.foreground == ZColor.clay700)

        #expect(HomeTile.Tone.sun.palette.background == ZColor.sun200)
        #expect(HomeTile.Tone.sun.palette.edge == ZColor.sun400)
        // The one tone that does not take its foreground from its own ramp:
        // `sun600` on `sun200` is 2.87:1, so the label is dark ink, as
        // everything written on sun yellow in this system is (#238).
        #expect(HomeTile.Tone.sun.palette.foreground == ZColor.ink900)

        #expect(HomeTile.Tone.hoopoe.palette.background == ZColor.orange100)
        #expect(HomeTile.Tone.hoopoe.palette.edge == ZColor.accent)
        #expect(HomeTile.Tone.hoopoe.palette.foreground == ZColor.orange700)
    }

    @Test("The four tones are four different tiles, and none of them looks locked")
    func tilePalettesAreDistinctAndUnlike() {
        let palettes = HomeTile.Tone.allCases.map(\.palette)

        #expect(palettes.count == 4)
        #expect(Set(palettes).count == 4)
        #expect(!palettes.contains(HomeTilePalette.locked))
    }

    @Test(
        "Stars are clamped into 0…3 instead of rejected",
        arguments: [
            (-7, 0),
            (-1, 0),
            (0, 0),
            (1, 1),
            (2, 2),
            (3, 3),
            (5, 3),
            (Int.max, 3),
        ],
    )
    func starsAreClamped(given: Int, expected: Int) {
        #expect(HomeTile(title: "Wer singt da?", stars: given).stars == expected)
    }

    @Test("A locked tile shows an egg and no stars, whatever it was handed")
    func lockedTilesShowAnEggAndNoStars() {
        let locked = HomeTile(title: "Bald!", icon: .volume2, stars: 3, locked: true)

        #expect(locked.displayedIcon == .egg)
        #expect(locked.displayedStars == 0)
    }

    @Test("An open tile keeps its own glyph and its stars")
    func openTilesKeepTheirGlyphAndStars() {
        let open = HomeTile(title: "Wer singt da?", icon: .volume2, stars: 2)

        #expect(open.displayedIcon == .volume2)
        #expect(open.displayedStars == 2)
    }

    @Test("The default tile is far larger than the touch floor")
    func theDefaultTileIsFarLargerThanTheTouchFloor() {
        #expect(HomeTile.defaultSize == 240)
        #expect(HomeTile(title: "Wer singt da?").size >= ZSpacing.touchMinimum)
    }

    /// The tile's own rule, not a taste: a step is worn as long as the
    /// widest label a tile carries still fits between the paddings, so the
    /// boundaries are 193 pt for `label` and 237 pt for `headline`. A tile a
    /// point short of one steps down rather than truncating (#92).
    @Test(
        "The label's step follows the tile's size",
        arguments: [
            (ZSpacing.touchMinimum, ZType.Step.body),
            // Two tiles side by side on the shortest supported phone, which
            // the home screen's phone gutter makes 159 pt (#145).
            (159, .body),
            (192, .body),
            (193, .label),
            (236, .label),
            (237, .headline),
            // The JSX's own tile, `HomeTile.defaultSize` — spelled out because
            // an argument list is evaluated off the main actor.
            (240, .headline),
        ],
    )
    func theLabelStepFollowsTheTileSize(size: CGFloat, expected: ZType.Step) {
        #expect(HomeTile(title: "Wer singt da?", size: size).labelStep == expected)
    }

    /// Every label the tile is drawn with, on every size that has to hold it,
    /// checked against the face itself rather than trusted — so a font swap
    /// that widened a glyph fails here before a screenshot finds it.
    ///
    /// "Sterne sammeln" is the widest label the component carries that still
    /// asks for a single line; it comes from the previews below, and it has to
    /// survive whole at each size the step boundaries step up at. „Wer singt da?" has to survive at
    /// 159 pt as well: two tiles side by side on a 375 pt phone with the 16 pt
    /// phone gutter, `(375 − 2 × 16 − 24) / 2`. On the 48 pt iPad gutter that
    /// tile was 127 pt and the label was cut off — the bug #145 reports, and a
    /// number a screenshot found before a test did.
    @Test(
        "The step a tile picks keeps the labels it carries whole",
        arguments: [
            ("Sterne sammeln", CGFloat(193)),
            ("Sterne sammeln", 237),
            ("Sterne sammeln", 240),
            ("Wer singt da?", 159),
        ],
    )
    func theLabelStepKeepsTheLabelsWhole(label: String, size: CGFloat) throws {
        try #require(BundledFonts.registered)

        let step = HomeTile(title: label, size: size).labelStep
        let width = BundledFonts.width(of: label, postScriptName: "Baloo2-Bold", size: step.size)

        #expect(width <= size - 2 * ZSpacing.step4)
    }

    /// „Erkenne den Vogel" (#229) is the first shipped label that does not fit
    /// the narrowest tile on one line: 166.7 pt at 20 pt against the 127 pt a
    /// 159 pt tile leaves. Shrinking it to fit would put it at 15.2 pt, under
    /// the floor the design sets for anything a child reads *and* under
    /// ``HomeTileMetrics/labelScaleFloor``, so the tile takes a second line
    /// instead and keeps the step it chose.
    ///
    /// Separate from the test above rather than folded into it, because the
    /// two say different things: every other label fits on one line, and this
    /// one is allowed to need two.
    @Test("A label too wide for the narrowest tile takes a second line")
    func theWidestShippedLabelSurvivesOnTwoLines() throws {
        try #require(BundledFonts.registered)

        let tile: CGFloat = 159
        let step = HomeTile(title: "Erkenne den Vogel", size: tile).labelStep
        let available = tile - 2 * ZSpacing.step4
        func width(_ text: String) -> CGFloat {
            BundledFonts.width(of: text, postScriptName: "Baloo2-Bold", size: step.size)
        }

        // One line does not fit, and shrinking is no way out of it.
        #expect(width("Erkenne den Vogel") > available)
        #expect(width("Erkenne den Vogel") * HomeTileMetrics.labelScaleFloor > available)

        // Two do, at the full step, and whichever way SwiftUI sets them:
        // it balanced the label to „Erkenne" over „den Vogel" on the phone
        // rather than filling the first line, so both splits are checked.
        #expect(width("Erkenne den") <= available)
        #expect(width("Vogel") <= available)
        #expect(width("Erkenne") <= available)
        #expect(width("den Vogel") <= available)
    }

    /// The other half of the second line: it has to fit *down* the tile too.
    ///
    /// The narrowest tile is the tightest case — glyph, gap and two line boxes
    /// against what the paddings leave — and it is the one a 375 pt phone
    /// draws. A tile of that size showing stars as well would be 35 pt over —
    /// a row of stars is `--space-3` plus a 24 pt glyph — which is why this is
    /// written down: the stars arrive with the progress persistence (#27), and
    /// this is where the tile reports that it has no room left for them.
    @Test("Two lines still fit down the narrowest tile")
    func twoLinesFitDownTheNarrowestTile() {
        let tile: CGFloat = 159
        let step = HomeTile(title: "Erkenne den Vogel", size: tile).labelStep
        let content = tile * HomeTileMetrics.iconRatio
            + ZSpacing.step3
            + 2 * step.lineBoxHeight

        #expect(content <= tile - 2 * ZSpacing.step4)
    }

    /// What #229 was reported for, on the tile rather than in the bar: the
    /// label is declared at a step and was drawn a step below it, because a
    /// `minimumScaleFactor` shrinks to fit the design's line box — tighter
    /// than Baloo 2's own — as readily as it shrinks to fit a width.
    ///
    /// Both tile sizes that pick a different step, because the gap between the
    /// design's box and the face's grows with the step: a `body` label drew at
    /// 18.75 pt instead of 20, and a `headline` one at 22.4 — there the scale
    /// floor was all that stopped it.
    @Test(
        "A label with room around it is drawn at the step its tile picked",
        arguments: [CGFloat(159), 240],
    )
    func theLabelKeepsItsStep(tile: CGFloat) throws {
        try #require(BundledFonts.registered)

        let label = "Wer singt da?"
        let component = HomeTile(title: label, size: tile)
        let step = component.labelStep
        let drawn = drawnSize(
            of: component.label(lines: 1, step: step),
            text: label,
            declaredAt: step,
        )

        // A point of tolerance: `ImageRenderer` reports whole points.
        #expect(
            abs(drawn - step.size) < 1,
            "the label was drawn at \(drawn) pt, not at \(step.size)",
        )
    }

    /// The one number in `SettingRow` that a screenshot caught and no unit
    /// test could: a settings row on a phone is narrow enough that its title
    /// wraps, and the gap to the hint has to beat the gap SwiftUI leaves
    /// between two lines of the same paragraph. Below that the wrapped title
    /// and the hint read as one run-on block (#121).
    @Test("A wrapped title is further from its hint than from its own next line")
    func theHintClearsAWrappedTitle() {
        #expect(SettingRowMetrics.hintSpacing > ZType.Step.body.lineSpacing(for: .body))
        #expect(ZSpacing.scale.contains(SettingRowMetrics.hintSpacing))
    }
}
