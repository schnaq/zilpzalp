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
