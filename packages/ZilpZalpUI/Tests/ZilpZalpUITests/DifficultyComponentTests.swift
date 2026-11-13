import SwiftUI
import Testing
@testable import ZilpZalpUI

// What the difficulty-level components decide before they draw: how many
// photos a quartet lays out, where its large tile starts, the mosaic's
// numbers, and that the badge's glyph can be read on its disc. Rendering is
// left to the `#Preview` blocks.

@MainActor
@Suite("Difficulty components")
struct DifficultyComponentTests {
    @Test("One photo fills the square, anything else is a two-by-two")
    func quartetColumns() {
        #expect(PhotoQuartet.columns(photoCount: 1) == 1)
        #expect(PhotoQuartet.columns(photoCount: 4) == 2)
    }

    @Test("The large tile starts at 160 pt")
    func tileThreshold() {
        #expect(PhotoQuartetMetrics(style: .tile, size: 160).radius == ZRadius.tile)
        #expect(PhotoQuartetMetrics(style: .tile, size: 159).radius == ZRadius.large)
    }

    @Test("The mosaic is bare photos with hairline gutters")
    func mosaicMetrics() {
        let metrics = PhotoQuartetMetrics(style: .mosaic, size: 48)

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
