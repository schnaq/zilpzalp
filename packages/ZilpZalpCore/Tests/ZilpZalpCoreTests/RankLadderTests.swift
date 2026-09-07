import Testing
import ZilpZalpCore

@Test("The ranks are ordered by ascending threshold")
func ranksAreOrderedByAscendingThreshold() {
    #expect(Rank.allCases.map(\.threshold) == [0, 25, 60, 100, 150, 220, 300, 400])
}

@Test("The raw values are the stable rank identifiers")
func rawValuesAreStableIdentifiers() {
    #expect(Rank.allCases.map(\.rawValue) == [
        "kohlmeise",
        "amsel",
        "blaumeise",
        "rotkehlchen",
        "star",
        "buntspecht",
        "eisvogel",
        "wiedehopf",
    ])
}

@Test(
    "The rank is the highest one whose threshold the stars reach",
    arguments: [
        (-1, Rank.kohlmeise),
        (0, .kohlmeise),
        (24, .kohlmeise),
        (25, .amsel),
        (59, .amsel),
        (60, .blaumeise),
        (99, .blaumeise),
        (100, .rotkehlchen),
        (149, .rotkehlchen),
        (150, .star),
        (219, .star),
        (220, .buntspecht),
        (299, .buntspecht),
        (300, .eisvogel),
        (399, .eisvogel),
        (400, .wiedehopf),
        (10000, .wiedehopf),
    ],
)
func rankForStars(stars: Int, expected: Rank) {
    #expect(RankLadder.rank(forStars: stars) == expected)
}

@Test(
    "Every rank knows its successor",
    arguments: [
        (Rank.kohlmeise, Rank.amsel),
        (.amsel, .blaumeise),
        (.blaumeise, .rotkehlchen),
        (.rotkehlchen, .star),
        (.star, .buntspecht),
        (.buntspecht, .eisvogel),
        (.eisvogel, .wiedehopf),
    ],
)
func nextAfterRank(rank: Rank, expected: Rank) {
    #expect(RankLadder.next(after: rank) == expected)
}

@Test("The highest rank has no successor")
func nextAfterHighestRankIsNil() {
    #expect(RankLadder.next(after: .wiedehopf) == nil)
}

@Test(
    "The missing stars count up to the next threshold",
    arguments: [
        (Int.min, 25),
        (-5, 25),
        (0, 25),
        (24, 1),
        (25, 35),
        (399, 1),
    ],
)
func starsMissingFromStars(stars: Int, expected: Int) {
    #expect(RankLadder.starsMissing(from: stars) == expected)
}

@Test(
    "Nothing is missing once the highest rank is reached",
    arguments: [400, 10000],
)
func starsMissingAtTheTopIsNil(stars: Int) {
    #expect(RankLadder.starsMissing(from: stars) == nil)
}
