import Foundation
import Testing
import ZilpZalpData

@Suite("Recording a round")
struct ProfileStoreRecordingTests {
    @Test("a round adds its stars, one round, its species and its seconds")
    func recordsRound() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)
            let mila = try await store.add(name: "Mila", avatar: "feather")

            let recorded = try await store.record(
                round: PlayedRound(stars: 3, species: ["amsel", "zilpzalp"], playtime: 92),
                for: mila.id,
                on: noon(2026, 9, 8),
                calendar: testCalendar,
            )

            #expect(recorded.totalStars == 3)
            #expect(recorded.roundsPlayed == 1)
            #expect(recorded.collectedSpecies == ["amsel", "zilpzalp"])
            #expect(recorded.playtime == ["2026-09-08": 92])
            #expect(try await store.profiles() == [recorded])
        }
    }

    @Test("a second round on the same day adds up and unions the species")
    func accumulatesRounds() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)
            let mila = try await store.add(name: "Mila", avatar: "feather")
            let day = try noon(2026, 9, 8)
            try await store.record(
                round: PlayedRound(stars: 3, species: ["amsel", "zilpzalp"], playtime: 92),
                for: mila.id,
                on: day,
                calendar: testCalendar,
            )

            let recorded = try await store.record(
                round: PlayedRound(stars: 1, species: ["amsel", "kohlmeise"], playtime: 60),
                for: mila.id,
                on: day,
                calendar: testCalendar,
            )

            #expect(recorded.totalStars == 4)
            #expect(recorded.roundsPlayed == 2)
            #expect(recorded.collectedSpecies == ["amsel", "kohlmeise", "zilpzalp"])
            #expect(recorded.playtime == ["2026-09-08": 152])
        }
    }

    @Test("a round on the next day opens its own key")
    func recordsPerDay() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)
            let mila = try await store.add(name: "Mila", avatar: "feather")
            try await store.record(
                round: PlayedRound(stars: 2, species: ["amsel"], playtime: 92),
                for: mila.id,
                on: noon(2026, 9, 8),
                calendar: testCalendar,
            )

            let recorded = try await store.record(
                round: PlayedRound(stars: 2, species: ["amsel"], playtime: 45),
                for: mila.id,
                on: noon(2026, 9, 9),
                calendar: testCalendar,
            )

            #expect(recorded.playtime == ["2026-09-08": 92, "2026-09-09": 45])
        }
    }

    @Test("a write keeps seven days of playtime, in every profile")
    func prunesPlaytime() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)
            var mila = try await store.add(name: "Mila", avatar: "feather")
            var jonte = try await store.add(name: "Jonte", avatar: "egg")
            // Six days back is the oldest day the week keeps; seven days back
            // is the first one it drops.
            mila.playtime = ["2026-09-01": 300, "2026-09-02": 240, "2026-09-08": 60]
            jonte.playtime = ["2026-09-01": 120, "2026-09-02": 90]
            try await store.update(mila)
            try await store.update(jonte)

            let recorded = try await store.record(
                round: PlayedRound(stars: 3, species: ["amsel"], playtime: 30),
                for: mila.id,
                on: noon(2026, 9, 8),
                calendar: testCalendar,
            )

            #expect(recorded.playtime == ["2026-09-02": 240, "2026-09-08": 90])
            let others = try await store.profiles()
            #expect(others.last?.playtime == ["2026-09-02": 90])
        }
    }

    @Test("recording for a profile that is not in the file is an error")
    func rejectsUnknownRound() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)
            let id = UUID()

            await #expect(throws: ProfileStoreError.unknownProfile(id)) {
                try await store.record(
                    round: PlayedRound(stars: 3, species: [], playtime: 10),
                    for: id,
                    on: noon(2026, 9, 8),
                    calendar: testCalendar,
                )
            }
        }
    }
}
