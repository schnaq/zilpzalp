import SwiftUI
import Testing
@testable import ZilpZalpUI

// What the row of markers under a bird decides before it draws anything: how
// many markers there are, how many of them are filled, and that a careless
// count cannot make either of those nonsense. Its own suite rather than a
// section of `QuizComponentTests`, which stands at SwiftLint's ceiling for a
// type body.
//
// There is no "renders no digits" test, for the reason `QuizProgress` gives:
// the row builds no `Text` at all. `filled` below is its complete visible
// model — five booleans, no numerals.

@MainActor
@Suite("Sticker progress")
struct StickerProgressTests {
    @Test("One marker per recognition the sticker takes, and never more")
    func drawsOneMarkerPerRecognition() {
        #expect(StickerProgress(count: 2, of: 5, label: "").filled.count == 5)
        #expect(StickerProgress(count: 0, of: 5, label: "").filled.count == 5)
        #expect(StickerProgress(count: 1, of: 0, label: "").filled.isEmpty)
        // A negative row is read as no row rather than trapping.
        #expect(StickerProgress(count: 1, of: -5, label: "").filled.isEmpty)
    }

    @Test(
        "Recognitions are clamped into the row, so a well-known bird is one full sticker",
        arguments: [(-3, 0), (0, 0), (3, 3), (5, 5), (20, 5), (Int.max, 5)],
    )
    func countIsClamped(given: Int, expected: Int) {
        let progress = StickerProgress(count: given, of: 5, label: "")

        #expect(progress.count == expected)
        #expect(progress.filled.count(where: { $0 }) == expected)
    }

    @Test("The markers fill from the left")
    func markersFillFromTheLeft() {
        #expect(StickerProgress(count: 2, of: 5, label: "").filled == [
            true, true, false, false, false,
        ])
        #expect(!StickerProgress(count: 5, of: 5, label: "").filled.contains(false))
    }

    @Test("A marker is cut from the sticker's rim, not from a star or a leaf")
    func markersWearTheStickerColours() {
        // The stars are the round's score and the leaves are the round's
        // progress; a sticker's markers are neither, so they take the gold of
        // the rim the sticker is drawn with (#177).
        #expect(StickerProgress.filled == ZColor.rewardShadow)
        #expect(StickerProgress.filled != ZColor.reward)
        #expect(StickerProgress.filled != ZColor.primary)
        #expect(StickerProgress.empty == ZColor.surfaceSunken)
        // The gaps never grow wider than half a marker, so the row stays a row
        // of markers rather than a dotted line. How wide it may be altogether
        // is the screen's business — it knows the sticker it sits under.
        #expect(StickerProgressMetrics.gapRatio < 0.5)
    }
}
