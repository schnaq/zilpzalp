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
            // Two tiles side by side on the shortest supported phone.
            (127, .body),
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

    /// The ratio those boundaries are derived from, checked against the face
    /// itself rather than trusted. "Sterne sammeln" is the widest label this
    /// tile is drawn with — it comes from the component's own previews — and
    /// it has to survive whole at every size the tile steps up at, so a font
    /// swap that widened it fails the derivation before a screenshot.
    @Test(
        "The step a tile picks keeps the widest label it carries whole",
        arguments: [193, 237, 240] as [CGFloat],
    )
    func theLabelStepKeepsTheLongestLabelWhole(size: CGFloat) throws {
        try #require(BundledFonts.registered)

        let longest = "Sterne sammeln"
        let step = HomeTile(title: longest, size: size).labelStep
        let width = BundledFonts.width(of: longest, postScriptName: "Baloo2-Bold", size: step.size)

        #expect(width <= size - 2 * ZSpacing.step4)
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
