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

@Test("A sticker takes five recognitions of the same bird")
func recognitionsForSticker() {
    // The number Christian and Johanna settled on in #177, in the one place
    // it is written. A screen drawing the markers reads it from here, so a
    // change to the rule cannot leave a row of five behind.
    #expect(Scoring.recognitionsForSticker == 5)
}

@Test("No round earns more than the stars a screen draws places for")
func starsNeverExceedTheMaximum() {
    for firstTryCorrect in -3 ... 20 {
        #expect(Scoring.stars(firstTryCorrect: firstTryCorrect) <= Scoring.maximumStars)
    }
    #expect(Scoring.stars(firstTryCorrect: 10) == Scoring.maximumStars)
}
