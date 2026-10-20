import Testing
import ZilpZalpCore

@Test(
    "The new-birds badge appears at four in five installed stickers",
    arguments: [
        (0, 0, false),
        (0, 70, false),
        (55, 70, false),
        (56, 70, true),
        (70, 70, true),
        (8, 10, true),
        (7, 10, false),
    ],
)
func newBirdsHint(collected: Int, total: Int, due: Bool) {
    #expect(NewBirdsHint.isDue(collected: collected, of: total) == due)
}
