import Testing
import ZilpZalpCore

@Test(
    "The stars follow the thresholds nine and six",
    arguments: [
        (-3, 1),
        (0, 1),
        (5, 1),
        (6, 2),
        (8, 2),
        (9, 3),
        (10, 3),
    ],
)
func starsForFirstTryCorrect(firstTryCorrect: Int, expected: Int) {
    #expect(Scoring.stars(firstTryCorrect: firstTryCorrect) == expected)
}

@Test("A sticker takes three or five recognitions of the same bird")
func stickerThresholds() {
    // Five is what Christian and Johanna settled on in #177; three is the
    // choice a grown-up gets for a younger child (#260). The grown-ups' area
    // offers exactly these, in this order.
    #expect(Scoring.stickerThresholds == [3, 5])
}

@Test("No round earns more than the stars a screen draws places for")
func starsNeverExceedTheMaximum() {
    for firstTryCorrect in -3 ... 20 {
        #expect(Scoring.stars(firstTryCorrect: firstTryCorrect) <= Scoring.maximumStars)
    }
    #expect(Scoring.stars(firstTryCorrect: 10) == Scoring.maximumStars)
}
