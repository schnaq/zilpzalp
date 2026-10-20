import Foundation
import Testing
import ZilpZalpData

@Suite("Stickers and their threshold")
struct ProfileStickerTests {
    @Test("a profile written before #260 plays at five and keeps the album its counters gave it")
    func backfillsFromOlderFile() throws {
        let older = Data(
            """
            {
              "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
              "name": "Mila",
              "avatar": "amsel",
              "totalStars": 24,
              "roundsPlayed": 9,
              "recognitions": { "amsel": 7, "kohlmeise": 5, "zilpzalp": 4 },
              "playtime": {},
              "dailyStars": {}
            }
            """.utf8,
        )

        let profile = try JSONDecoder().decode(Profile.self, from: older)

        #expect(profile.stickerThreshold == 5)
        #expect(profile.stickers == ["amsel", "kohlmeise"])
    }

    @Test("a stored sticker survives a counter below the threshold, and round-trips")
    func readsStoredStickers() throws {
        let file = Data(
            """
            {
              "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
              "name": "Mila",
              "avatar": "amsel",
              "totalStars": 24,
              "roundsPlayed": 9,
              "recognitions": { "amsel": 3 },
              "stickerThreshold": 5,
              "stickers": ["amsel"],
              "playtime": {},
              "dailyStars": {}
            }
            """.utf8,
        )

        let profile = try JSONDecoder().decode(Profile.self, from: file)

        #expect(profile.hasSticker(for: "amsel"))
        let written = try JSONEncoder().encode(profile)
        #expect(try JSONDecoder().decode(Profile.self, from: written) == profile)
    }

    @Test("lowering the threshold to three hands over every bird at three or more")
    func loweringGrants() {
        var mila = Profile(
            id: UUID(),
            name: "Mila",
            avatar: "amsel",
            recognitions: ["amsel": 3, "kohlmeise": 4, "zilpzalp": 2],
        )
        #expect(mila.stickers.isEmpty)

        mila.stickerThreshold = 3

        #expect(mila.stickers == ["amsel", "kohlmeise"])
    }

    @Test("raising the threshold again takes nothing back")
    func raisingKeeps() {
        var mila = Profile(
            id: UUID(),
            name: "Mila",
            avatar: "amsel",
            recognitions: ["amsel": 3, "zilpzalp": 2],
            stickerThreshold: 3,
        )
        #expect(mila.stickers == ["amsel"])

        mila.stickerThreshold = 5
        mila.recognitions["zilpzalp", default: 0] += 1

        // The Amsel keeps the sticker it earned at three; the Zilpzalp, now at
        // three as well, has to go on to five.
        #expect(mila.stickers == ["amsel"])
    }

    @Test("a threshold of zero or less in a hand-edited file reads as five")
    func rejectsNonsenseThreshold() throws {
        let file = Data(
            """
            {
              "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
              "name": "Mila",
              "avatar": "amsel",
              "totalStars": 0,
              "roundsPlayed": 0,
              "recognitions": { "amsel": 0 },
              "stickerThreshold": 0,
              "playtime": {}
            }
            """.utf8,
        )

        let profile = try JSONDecoder().decode(Profile.self, from: file)

        #expect(profile.stickerThreshold == 5)
        #expect(profile.stickers.isEmpty)
    }

    @Test("a round that reaches the threshold writes the sticker to disk")
    func recordingGrants() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)
            var mila = try await store.add(name: "Mila", avatar: "amsel")
            mila.stickerThreshold = 3
            try await store.update(mila)

            _ = try await store.record(
                round: PlayedRound(stars: 2, recognitions: ["amsel": 3, "star": 2], playtime: 60),
                for: mila.id,
                on: noon(2026, 9, 8),
                calendar: testCalendar,
            )

            let reread = try #require(try await store.profiles().first)
            #expect(reread.stickerThreshold == 3)
            #expect(reread.stickers == ["amsel"])
        }
    }

    @Test("lowering the threshold through the store persists what it hands over")
    func updatingGrants() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)
            let mila = try await store.add(name: "Mila", avatar: "amsel")
            _ = try await store.record(
                round: PlayedRound(stars: 2, recognitions: ["amsel": 4], playtime: 60),
                for: mila.id,
                on: noon(2026, 9, 8),
                calendar: testCalendar,
            )
            var played = try #require(try await store.profiles().first)
            #expect(played.stickers.isEmpty)

            played.stickerThreshold = 3
            try await store.update(played)

            #expect(try await store.profiles().first?.stickers == ["amsel"])
        }
    }
}
