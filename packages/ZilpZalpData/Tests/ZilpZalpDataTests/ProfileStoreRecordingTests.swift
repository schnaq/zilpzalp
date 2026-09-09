import Foundation
import Testing
import ZilpZalpData

@Suite("Recording a round")
struct ProfileStoreRecordingTests {
    @Test("a round adds its stars, one round, its recognitions and its seconds")
    func recordsRound() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)
            let mila = try await store.add(name: "Mila", avatar: "feather")

            let recorded = try await store.record(
                round: PlayedRound(
                    stars: 3,
                    recognitions: ["amsel": 2, "zilpzalp": 1],
                    playtime: 92,
                ),
                for: mila.id,
                on: noon(2026, 9, 8),
                calendar: testCalendar,
            )

            #expect(recorded.totalStars == 3)
            #expect(recorded.roundsPlayed == 1)
            #expect(recorded.recognitions == ["amsel": 2, "zilpzalp": 1])
            #expect(recorded.playtime == ["2026-09-08": 92])
            #expect(recorded.dailyStars == ["2026-09-08": 3])
            #expect(try await store.profiles() == [recorded])
        }
    }

    @Test("a second round on the same day adds up, recognitions included")
    func accumulatesRounds() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)
            let mila = try await store.add(name: "Mila", avatar: "feather")
            let day = try noon(2026, 9, 8)
            try await store.record(
                round: PlayedRound(
                    stars: 3,
                    recognitions: ["amsel": 3, "zilpzalp": 1],
                    playtime: 92,
                ),
                for: mila.id,
                on: day,
                calendar: testCalendar,
            )

            let recorded = try await store.record(
                round: PlayedRound(
                    stars: 1,
                    recognitions: ["amsel": 2, "kohlmeise": 1],
                    playtime: 60,
                ),
                for: mila.id,
                on: day,
                calendar: testCalendar,
            )

            #expect(recorded.totalStars == 4)
            #expect(recorded.roundsPlayed == 2)
            // Added up rather than replaced, which is what carries a bird over
            // its fifth recognition across two sittings.
            #expect(recorded.recognitions == ["amsel": 5, "kohlmeise": 1, "zilpzalp": 1])
            #expect(recorded.playtime == ["2026-09-08": 152])
            #expect(recorded.dailyStars == ["2026-09-08": 4])
        }
    }

    @Test("a round on the next day opens its own key")
    func recordsPerDay() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)
            let mila = try await store.add(name: "Mila", avatar: "feather")
            try await store.record(
                round: PlayedRound(stars: 2, recognitions: ["amsel": 1], playtime: 92),
                for: mila.id,
                on: noon(2026, 9, 8),
                calendar: testCalendar,
            )

            let recorded = try await store.record(
                round: PlayedRound(stars: 2, recognitions: ["amsel": 1], playtime: 45),
                for: mila.id,
                on: noon(2026, 9, 9),
                calendar: testCalendar,
            )

            #expect(recorded.playtime == ["2026-09-08": 92, "2026-09-09": 45])
            // A new day starts at nothing collected, which is what makes the
            // budget and the day's take reset without anybody resetting them.
            #expect(recorded.dailyStars == ["2026-09-08": 2, "2026-09-09": 2])
        }
    }

    @Test("a write keeps seven days of playtime and stars, in every profile")
    func prunesPlaytime() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)
            var mila = try await store.add(name: "Mila", avatar: "feather")
            var jonte = try await store.add(name: "Jonte", avatar: "egg")
            // Six days back is the oldest day the week keeps; seven days back
            // is the first one it drops.
            mila.playtime = ["2026-09-01": 300, "2026-09-02": 240, "2026-09-08": 60]
            mila.dailyStars = ["2026-09-01": 9, "2026-09-02": 6, "2026-09-08": 2]
            jonte.playtime = ["2026-09-01": 120, "2026-09-02": 90]
            jonte.dailyStars = ["2026-09-01": 4, "2026-09-02": 3]
            try await store.update(mila)
            try await store.update(jonte)

            let recorded = try await store.record(
                round: PlayedRound(stars: 3, recognitions: ["amsel": 1], playtime: 30),
                for: mila.id,
                on: noon(2026, 9, 8),
                calendar: testCalendar,
            )

            #expect(recorded.playtime == ["2026-09-02": 240, "2026-09-08": 90])
            #expect(recorded.dailyStars == ["2026-09-02": 6, "2026-09-08": 5])
            let others = try await store.profiles()
            #expect(others.last?.playtime == ["2026-09-02": 90])
            #expect(others.last?.dailyStars == ["2026-09-02": 3])
        }
    }

    @Test("recording for a profile that is not in the file is an error")
    func rejectsUnknownRound() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)
            let id = UUID()

            await #expect(throws: ProfileStoreError.unknownProfile(id)) {
                try await store.record(
                    round: PlayedRound(stars: 3, recognitions: [:], playtime: 10),
                    for: id,
                    on: noon(2026, 9, 8),
                    calendar: testCalendar,
                )
            }
        }
    }
}
