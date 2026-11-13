import SwiftUI
import Testing
@testable import ZilpZalpUI

// What the difficulty-level components decide before they draw: the glyph's
// name, how many photos a quartet lays out, the quartet's numbers in both
// styles, and that the badge's glyph can be read on its disc. Rendering is
// left to the `#Preview` blocks.

@MainActor
@Suite("Difficulty components")
struct DifficultyComponentTests {
    @Test("The binoculars glyph resolves to the vendored imageset")
    func binocularsRawValue() {
        #expect(ZIcon.binoculars.rawValue == "binoculars")
    }

    @Test("One photo fills the square, anything else is a two-by-two")
    func quartetLayout() {
        #expect(PhotoQuartet.layout(photoCount: 1) == (columns: 1, cells: 1))
        #expect(PhotoQuartet.layout(photoCount: 4) == (columns: 2, cells: 4))
    }

    @Test("An iPad-sized tile is ChoiceTile's large papier tile")
    func largeTileMetrics() {
        let metrics = PhotoQuartetMetrics(style: .tile, size: 200)

        #expect(metrics.radius == ZRadius.tile)
        #expect(metrics.rim == ZBorder.widthThick)
        #expect(metrics.ledge == ZShadow.ledgeLargeOffset)
        #expect(metrics.gutter == 6)
        #expect(metrics.outerCorner == 25)
        #expect(metrics.innerCorner == 10)
        #expect(metrics.soloCorner == metrics.outerCorner)
    }

    @Test("A phone-sized tile steps down to the small radius and ledge")
    func smallTileMetrics() {
        let metrics = PhotoQuartetMetrics(style: .tile, size: 96)

        #expect(metrics.radius == ZRadius.large)
        #expect(metrics.rim == ZBorder.widthThick)
        #expect(metrics.ledge == ZShadow.ledgeOffset)
        #expect(metrics.gutter == 4)
        #expect(metrics.outerCorner == 18)
        #expect(metrics.innerCorner == 6)
    }

    @Test("The large tile starts at 160 pt")
    func tileThreshold() {
        #expect(PhotoQuartetMetrics(style: .tile, size: 160).radius == ZRadius.tile)
        #expect(PhotoQuartetMetrics(style: .tile, size: 159).radius == ZRadius.large)
    }

    @Test("The mosaic is bare photos with hairline gutters")
    func mosaicMetrics() {
        let metrics = PhotoQuartetMetrics(style: .mosaic, size: 48)

        #expect(metrics.rim == 0)
        #expect(metrics.ledge == 0)
        #expect(metrics.inset == 0)
        #expect(metrics.gutter == 2)
        #expect(metrics.outerCorner == ZRadius.medium)
        #expect(metrics.innerCorner == 3)
        // Rounder than this, a lone photo would read as a sticker disc.
        #expect(metrics.soloCorner == 16)
    }

    @Test("The badge glyph reads on its sun disc")
    func badgeGlyphContrast() {
        let pair = ContrastPair(
            name: "GlyphBadge glyph",
            foreground: ZColor.bark700,
            background: ZColor.sun300,
        )
        #expect(pair.ratio >= WCAG.normalText)
    }
}
