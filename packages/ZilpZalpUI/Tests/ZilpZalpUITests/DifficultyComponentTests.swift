import SwiftUI
import Testing
@testable import ZilpZalpUI

// What the difficulty-level components decide before they draw: the glyph's
// name, how many photos a quartet lays out, which colours a tone resolves to,
// and that the badge's glyph can be read on its disc. Rendering is left to the
// `#Preview` blocks.

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

    @Test("The four quartet tones have distinct fields, and none is the chosen olive")
    func quartetTonesAreDistinctAndNotOlive() {
        let fields = PhotoQuartet.Tone.allCases.map(\.palette.field)
        let edges = PhotoQuartet.Tone.allCases.map(\.palette.edge)

        #expect(fields.count == 4)
        #expect(Set(fields).count == 4)
        #expect(Set(edges).count == 4)
        for tone in PhotoQuartet.Tone.allCases {
            #expect(tone.palette.field != ZColor.primary)
            #expect(tone.palette.edge != ZColor.primary)
        }
    }

    @Test("The badge glyph reads on its reward disc")
    func badgeGlyphContrast() {
        let pair = ContrastPair(
            name: "GlyphBadge glyph",
            foreground: ZColor.textOnReward,
            background: ZColor.reward,
        )
        #expect(pair.ratio >= WCAG.normalText)
    }
}
