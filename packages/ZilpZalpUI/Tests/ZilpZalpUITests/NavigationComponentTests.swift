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
}
