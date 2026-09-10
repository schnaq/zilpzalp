/// Deals values in a random order and does not repeat one while another has
/// not come up yet: a shuffled pass through everything, then the next pass.
///
/// The rule two things in this module need. A round asks for a species and
/// pushes the repeats of a small pool to the end (``Round``), and a tile asks
/// for a photo of the species it shows and does not show the same one twice
/// while the bird has another (``RoundPhotos``). Both are the same sentence
/// about a different set, and it is written once so that a fix to it cannot
/// land in only one of them.
///
/// Randomness comes solely from the generator handed to ``next(using:)``, so
/// the same bag with the same seed deals the same order.
struct ShuffleBag<Element> {
    /// Everything the bag holds, for the next pass.
    private let all: [Element]

    /// What is left of the pass being dealt, in the order it will come out of
    /// the back.
    private var pass: [Element] = []

    init(_ all: [Element]) {
        self.all = all
    }

    /// The next value, `nil` for a bag that holds nothing at all.
    ///
    /// Refilled when the pass runs out rather than when it is emptied, so a
    /// bag nobody asks again shuffles nothing.
    mutating func next(using generator: inout some RandomNumberGenerator) -> Element? {
        if pass.isEmpty {
            pass = all.shuffled(using: &generator)
        }
        return pass.popLast()
    }
}
