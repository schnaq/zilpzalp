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

    @Test("an old profile and a new one both play Klassisch")
    func defaultsToClassic() throws {
        #expect(Profile.defaultDifficulty == "classic")
        #expect(try Self.profile().difficulty == "classic")
        #expect(Profile(id: UUID(), name: "Mila", avatar: "amsel").difficulty == "classic")
    }

    /// "nightmare" is a level a newer build might write: it is kept as
    /// written, for the app to map, rather than rejected here.
    @Test("a level round-trips as written", arguments: ["hard", "nightmare"])
    func roundTrips(level: String) throws {
        let profile = try Self.profile(extra: #", "difficulty": "\#(level)""#)

        let written = try JSONEncoder().encode(profile)

        #expect(profile.difficulty == level)
        #expect(try JSONDecoder().decode(Profile.self, from: written).difficulty == level)
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

    /// The pictures promise something: Leicht four birds nothing alike,
    /// Mittel one look-alike pair in front, Schwer three alike in front. A
    /// recuration of the manifests must not quietly break that promise.
    @Test("each level's picture shows what that level deals")
    func samplesShowTheirLevel() throws {
        let groups = try Dictionary(
            uniqueKeysWithValues: PackCatalog.bundled().pack.birds.map { ($0.id, $0.lookalike) },
        )
        func group(_ level: String) -> [String?] {
            (Profile.difficultySamples[level] ?? []).map { groups[$0] ?? nil }
        }

        let easy = group("easy")
        let medium = group("medium")
        let hard = group("hard")

        #expect(Set(easy).count == 4)
        #expect(medium[0] != nil && medium[0] == medium[1])
        #expect(Set(medium).count == 3)
        #expect(hard[0] != nil && Set(hard.prefix(3)).count == 1)
        #expect(hard[3] != hard[0])
    }
}
