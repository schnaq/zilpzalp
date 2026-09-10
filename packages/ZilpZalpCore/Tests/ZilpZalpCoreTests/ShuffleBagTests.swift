import Testing
@testable import ZilpZalpCore

@Test("A pass deals everything once before anything comes again")
func dealsAPassBeforeRepeating() {
    var generator = SplitMix64(seed: 4)
    var bag = ShuffleBag(Array(1 ... 5))

    let dealt = (0 ..< 15).compactMap { _ in bag.next(using: &generator) }

    #expect(dealt.count == 15)
    for pass in stride(from: 0, to: 15, by: 5) {
        #expect(Set(dealt[pass ..< pass + 5]) == Set(1 ... 5))
    }
}

@Test("A bag of one deals it every time")
func dealsASingleValueForever() {
    var generator = SplitMix64(seed: 4)
    var bag = ShuffleBag(["amsel"])

    #expect((0 ..< 3).compactMap { _ in bag.next(using: &generator) } == [
        "amsel",
        "amsel",
        "amsel",
    ])
}

@Test("An empty bag has nothing to deal")
func dealsNothingWhenEmpty() {
    var generator = SplitMix64(seed: 4)
    var bag = ShuffleBag([Int]())

    #expect(bag.next(using: &generator) == nil)
    // And asking again neither traps nor starts answering.
    #expect(bag.next(using: &generator) == nil)
}

@Test("The same bag and the same seed deal the same order")
func dealsReproducibly() {
    var first = SplitMix64(seed: 99)
    var second = SplitMix64(seed: 99)
    var one = ShuffleBag(Array(1 ... 6))
    var two = ShuffleBag(Array(1 ... 6))

    let dealt = (0 ..< 12).compactMap { _ in one.next(using: &first) }

    #expect(dealt == (0 ..< 12).compactMap { _ in two.next(using: &second) })
}
