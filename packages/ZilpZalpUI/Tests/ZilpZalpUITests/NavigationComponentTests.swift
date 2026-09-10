import SwiftUI
import Testing
@testable import ZilpZalpUI

/// What a navigation component decides before it draws anything: which colours
/// a tone resolves to, how many stars survive, and what a locked tile shows.
/// Nothing here renders — the visual result is what the `#Preview` blocks and
/// the screenshot in the pull request are for.
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
        #expect(HomeTile.Tone.sun.palette.foreground == ZColor.sun600)

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
    /// "Sterne sammeln" is the widest label the component carries anywhere; it
    /// comes from the previews below, and it has to survive whole at each size
    /// the step boundaries step up at. „Wer singt da?" has to survive at
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

    /// „Finde den Vogel" (#220) is the first shipped label that does not fit
    /// the narrowest tile whole: 142.4 pt at 20 pt against the 127 pt a 159 pt
    /// tile leaves. It is not cut off — the component shrinks it instead — and
    /// this is where that guarantee stops being theory: the label has to fit
    /// once it has shrunk as far as ``HomeTileMetrics/labelScaleFloor`` lets
    /// it, which puts it at 17.8 pt on a 375 pt phone and leaves it whole.
    ///
    /// Separate from the test above rather than folded into it, because the
    /// two say different things: every other label keeps its step, and this
    /// one is allowed to lose it.
    @Test("A label too wide for the narrowest tile shrinks rather than breaks")
    func theWidestShippedLabelSurvivesByShrinking() throws {
        try #require(BundledFonts.registered)

        let label = "Finde den Vogel"
        let tile: CGFloat = 159
        let step = HomeTile(title: label, size: tile).labelStep
        let width = BundledFonts.width(of: label, postScriptName: "Baloo2-Bold", size: step.size)
        let available = tile - 2 * ZSpacing.step4

        #expect(width > available)
        #expect(width * HomeTileMetrics.labelScaleFloor <= available)
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
