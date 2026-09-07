/// A seedable random number generator for reproducible rounds in tests.
///
/// SplitMix64 as published by Vigna: one addition and three mixing steps. It
/// is short enough to read at a glance and gives the same sequence on every
/// machine, which is the whole point here.
struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var result = state
        result = (result ^ (result >> 30)) &* 0xBF58_476D_1CE4_E5B9
        result = (result ^ (result >> 27)) &* 0x94D0_49BB_1331_11EB
        return result ^ (result >> 31)
    }
}
