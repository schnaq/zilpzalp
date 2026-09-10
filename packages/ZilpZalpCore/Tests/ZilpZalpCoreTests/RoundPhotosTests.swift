import Testing
import ZilpZalpCore

/// Every tile of a round — the species it shows and the photo it was dealt —
/// in the order the questions ask them.
private func dealt(_ photos: RoundPhotos, in round: Round) -> [(species: String, photo: Int)] {
    round.questions.enumerated().flatMap { index, question in
        question.choices.map { (species: $0, photo: photos.photo(for: $0, question: index)) }
    }
}

private func round(seed: UInt64) throws -> Round {
    var generator = SplitMix64(seed: seed)
    return try Round.make(from: distinctGenera(10), using: &generator)
}

// MARK: - The rule

@Test("A species shows every photo before it shows one again", arguments: [1, 2, 3] as [UInt64])
func dealsEveryPhotoBeforeRepeating(seed: UInt64) throws {
    let round = try round(seed: seed)
    let counts = Dictionary(uniqueKeysWithValues: distinctGenera(10).map { ($0.id, 3) })

    var generator = SplitMix64(seed: seed)
    let photos = RoundPhotos(round: round, photoCounts: counts, using: &generator)

    // Every species that stands three times or fewer used three distinct
    // photos; one that stands more often repeats only after all three.
    var seen: [String: [Int]] = [:]
    for tile in dealt(photos, in: round) {
        seen[tile.species, default: []].append(tile.photo)
    }
    for (species, indices) in seen {
        for window in stride(from: 0, to: indices.count, by: 3) {
            let pass = indices[window ..< min(window + 3, indices.count)]
            #expect(
                Set(pass).count == pass.count,
                "'\(species)' repeated a photo inside one pass: \(Array(indices))",
            )
        }
        #expect(indices.allSatisfy { (0 ..< 3).contains($0) })
    }
}

@Test("A species with one photo always shows it")
func singlePhotoSpeciesStayAtZero() throws {
    let round = try round(seed: 7)
    let counts = Dictionary(uniqueKeysWithValues: distinctGenera(10).map { ($0.id, 1) })

    var generator = SplitMix64(seed: 7)
    let photos = RoundPhotos(round: round, photoCounts: counts, using: &generator)

    #expect(dealt(photos, in: round).allSatisfy { $0.photo == 0 })
}

@Test("A species nobody counted shows its first photo")
func unknownSpeciesStayAtZero() throws {
    let round = try round(seed: 11)

    var generator = SplitMix64(seed: 11)
    let photos = RoundPhotos(round: round, photoCounts: [:], using: &generator)

    #expect(dealt(photos, in: round).allSatisfy { $0.photo == 0 })
    // A question the round does not have, which is what a session asks for in
    // the moment a round is over.
    #expect(photos.photo(for: "species-0", question: round.questions.count) == 0)
}

// MARK: - Determinism

@Test("The same round and the same seed yield the same photos")
func isReproducible() throws {
    let round = try round(seed: 3)
    let counts = Dictionary(uniqueKeysWithValues: distinctGenera(10).map { ($0.id, 4) })

    var first = SplitMix64(seed: 42)
    var second = SplitMix64(seed: 42)

    #expect(
        RoundPhotos(round: round, photoCounts: counts, using: &first)
            == RoundPhotos(round: round, photoCounts: counts, using: &second),
    )
}

@Test("A pool of single-photo species consumes no randomness")
func singlePhotoSpeciesConsumeNothing() throws {
    let round = try round(seed: 9)
    let counts = Dictionary(uniqueKeysWithValues: distinctGenera(10).map { ($0.id, 1) })

    var generator = SplitMix64(seed: 13)
    _ = RoundPhotos(round: round, photoCounts: counts, using: &generator)

    var untouched = SplitMix64(seed: 13)
    #expect(generator.next() == untouched.next())
}

// MARK: - What a round asks to be opened

@Test("The dealt photos are exactly the ones the tiles show", arguments: [1, 5, 8] as [UInt64])
func dealtPhotosAreWhatTheTilesShow(seed: UInt64) throws {
    let round = try round(seed: seed)
    let counts = Dictionary(uniqueKeysWithValues: distinctGenera(10).map { ($0.id, 3) })

    var generator = SplitMix64(seed: seed)
    let photos = RoundPhotos(round: round, photoCounts: counts, using: &generator)

    var shown: [String: Set<Int>] = [:]
    for tile in dealt(photos, in: round) {
        shown[tile.species, default: []].insert(tile.photo)
    }
    // Every species offered is named, and with neither a photo the tiles skip
    // nor one they show and nobody opened.
    #expect(photos.dealtPhotos == shown)
    #expect(Set(photos.dealtPhotos.keys) == Set(round.questions.flatMap(\.choices)))
}

@Test("A species with one photo asks for its portrait alone")
func dealtPhotosNameSinglePhotoSpecies() throws {
    let round = try round(seed: 4)
    let counts = Dictionary(uniqueKeysWithValues: distinctGenera(10).map { ($0.id, 1) })

    var generator = SplitMix64(seed: 4)
    let photos = RoundPhotos(round: round, photoCounts: counts, using: &generator)

    #expect(Set(photos.dealtPhotos.keys) == Set(round.questions.flatMap(\.choices)))
    #expect(photos.dealtPhotos.values.allSatisfy { $0 == [0] })
}

@Test("A species the round leaves out asks for nothing")
func dealtPhotosLeaveOutUnaskedSpecies() throws {
    let species = distinctGenera(20)
    var generator = SplitMix64(seed: 6)
    let round = try Round.make(from: species, using: &generator)
    let counts = Dictionary(uniqueKeysWithValues: species.map { ($0.id, 3) })

    var dealing = SplitMix64(seed: 6)
    let photos = RoundPhotos(round: round, photoCounts: counts, using: &dealing)

    let asked = Set(round.questions.flatMap(\.choices))
    #expect(asked.count < species.count)
    #expect(photos.dealtPhotos.keys.allSatisfy { asked.contains($0) })
}
