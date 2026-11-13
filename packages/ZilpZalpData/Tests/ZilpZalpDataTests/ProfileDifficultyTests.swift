import Foundation
import Testing
import ZilpZalpData

@Suite("Difficulty")
struct ProfileDifficultyTests {
    /// A profile file as an older or a newer build wrote it: `extra` is spliced
    /// in as one more key, or nothing for a file from before levels existed.
    private static func profile(extra: String = "") throws -> Profile {
        let json = """
        {
          "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
          "name": "Mila",
          "avatar": "amsel",
          "totalStars": 0,
          "roundsPlayed": 0,
          "playtime": {}\(extra)
        }
        """
        return try JSONDecoder().decode(Profile.self, from: Data(json.utf8))
    }

    @Test("a profile written before levels existed plays Klassisch")
    func defaultsToClassic() throws {
        #expect(try Self.profile().difficulty == "classic")
        #expect(Profile.defaultDifficulty == "classic")
    }

    @Test("a new profile starts at Klassisch")
    func startsAtClassic() {
        #expect(Profile(id: UUID(), name: "Mila", avatar: "amsel").difficulty == "classic")
    }

    @Test("a chosen level round-trips through encoding")
    func roundTrips() throws {
        let hard = Profile(id: UUID(), name: "Mila", avatar: "amsel", difficulty: "hard")

        let written = try JSONEncoder().encode(hard)

        #expect(try JSONDecoder().decode(Profile.self, from: written).difficulty == "hard")
    }

    @Test("a level this build does not know is kept as written")
    func keepsUnknownLevel() throws {
        let profile = try Self.profile(extra: #", "difficulty": "nightmare""#)

        #expect(profile.difficulty == "nightmare")
        let written = try JSONEncoder().encode(profile)
        #expect(try JSONDecoder().decode(Profile.self, from: written).difficulty == "nightmare")
    }

    @Test("a changed level is persisted by the store")
    func updatePersists() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)
            var mila = try await store.add(name: "Mila", avatar: "amsel")
            mila.difficulty = "easy"
            try await store.update(mila)

            #expect(try await store.profiles().first?.difficulty == "easy")
        }
    }

    @Test("a merge takes the level from the copy changed last, in both directions")
    func mergeTakesNewerLevel() {
        let id = UUID()
        let older = Profile(
            id: id, name: "Mila", avatar: "amsel", difficulty: "easy",
            modifiedAt: Date(timeIntervalSince1970: 100),
        )
        let newer = Profile(
            id: id, name: "Mila", avatar: "amsel", difficulty: "hard",
            modifiedAt: Date(timeIntervalSince1970: 200),
        )

        #expect(older.merged(with: newer).difficulty == "hard")
        #expect(newer.merged(with: older).difficulty == "hard")
    }

    @Test("the samples cover the four levels with birds of the bundled pack")
    func samplesAreBundledBirds() throws {
        let bundled = try Set(PackCatalog.bundled().pack.birds.map(\.id))

        #expect(Set(Profile.difficultySamples.keys) == ["easy", "medium", "hard", "classic"])
        for (level, species) in Profile.difficultySamples {
            #expect(species.count == (level == "classic" ? 1 : 4), "\(level)")
            for id in species {
                #expect(bundled.contains(id), "\(id) is not in the bundled pack")
            }
        }
    }
}
