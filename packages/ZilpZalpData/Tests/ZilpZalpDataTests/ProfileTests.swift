import Foundation
import Testing
import ZilpZalpData

@Suite("Profile")
struct ProfileTests {
    @Test("a day key is the zero-padded date in the given calendar")
    func formsDayKey() throws {
        let day = try noon(2026, 9, 8)

        #expect(Profile.dayKey(for: day, calendar: testCalendar) == "2026-09-08")
    }

    @Test("the day turns over in the calendar's time zone")
    func formsDayKeyInTimeZone() throws {
        var berlin = testCalendar
        berlin.timeZone = try #require(TimeZone(identifier: "Europe/Berlin"))
        // Half past eleven at night in London is already the next day in Berlin.
        let lateEvening = try #require(
            testCalendar.date(from: DateComponents(
                year: 2026,
                month: 9,
                day: 8,
                hour: 23,
                minute: 30,
            )),
        )

        #expect(Profile.dayKey(for: lateEvening, calendar: testCalendar) == "2026-09-08")
        #expect(Profile.dayKey(for: lateEvening, calendar: berlin) == "2026-09-09")
    }

    @Test("a day key stays Gregorian on a device that is not")
    func formsGregorianDayKey() throws {
        var japanese = Calendar(identifier: .japanese)
        japanese.timeZone = .gmt
        let day = try noon(2026, 9, 8)

        // The Japanese calendar numbers this year 8. A key that followed it
        // would neither match the day the app wrote yesterday nor sort
        // against it.
        #expect(Profile.dayKey(for: day, calendar: japanese) == "2026-09-08")
    }

    @Test("a profile written before the daily stars existed reads as none")
    func decodesWithoutDailyStars() throws {
        // Exactly what version 1 of the file wrote before #36 added a key to
        // it. A family that played yesterday must not lose its profiles to a
        // field that did not exist then. Its `collectedSpecies` is the key
        // #177 took away again — the test below is that half.
        let older = Data(
            """
            {
              "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
              "name": "Mila",
              "avatar": "feather",
              "totalStars": 24,
              "roundsPlayed": 9,
              "collectedSpecies": ["amsel"],
              "playtime": { "2026-09-08": 92 }
            }
            """.utf8,
        )

        let profile = try JSONDecoder().decode(Profile.self, from: older)

        #expect(profile.dailyStars.isEmpty)
        #expect(profile.totalStars == 24)
        #expect(profile.playtime == ["2026-09-08": 92])
    }

    @Test("a profile written before the recognitions keeps its stars, not its stickers")
    func decodesWithoutRecognitions() throws {
        // A file from before #177. Its `collectedSpecies` was filled by
        // meeting a bird in a round, which is not what a sticker means any
        // more, so it reads as nothing recognised yet — while the stars the
        // child earned stay exactly where they were.
        let older = Data(
            """
            {
              "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
              "name": "Mila",
              "avatar": "feather",
              "totalStars": 24,
              "roundsPlayed": 9,
              "collectedSpecies": ["amsel", "zilpzalp"],
              "playtime": { "2026-09-08": 92 },
              "dailyStars": { "2026-09-08": 3 }
            }
            """.utf8,
        )

        let profile = try JSONDecoder().decode(Profile.self, from: older)

        #expect(profile.recognitions.isEmpty)
        #expect(profile.totalStars == 24)
        #expect(profile.dailyStars == ["2026-09-08": 3])
    }

    @Test("a profile with recognitions reads them back and writes them again")
    func decodesRecognitions() throws {
        let file = Data(
            """
            {
              "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
              "name": "Mila",
              "avatar": "feather",
              "totalStars": 24,
              "roundsPlayed": 9,
              "recognitions": { "amsel": 5, "zilpzalp": 2 },
              "playtime": {},
              "dailyStars": {}
            }
            """.utf8,
        )

        let profile = try JSONDecoder().decode(Profile.self, from: file)

        #expect(profile.recognitions == ["amsel": 5, "zilpzalp": 2])
        // The way out is the way in: a round trip reshapes nothing, and the
        // key #177 retired is not written back.
        let written = try JSONEncoder().encode(profile)
        #expect(try JSONDecoder().decode(Profile.self, from: written) == profile)
        let text = try #require(String(data: written, encoding: .utf8))
        #expect(!text.contains("collectedSpecies"))
    }

    @Test("a profile written before the collections plays with every bird")
    func decodesWithoutCollection() throws {
        // A file from before #187, which is every file written so far. The
        // children who are testing the app must not lose their profiles to a
        // choice they never made — and „no choice" is the choice that plays
        // with all of it.
        let older = Data(
            """
            {
              "id": "3F2504E0-4F89-11D3-9A0C-0305E82C3301",
              "name": "Mila",
              "avatar": "feather",
              "totalStars": 24,
              "roundsPlayed": 9,
              "recognitions": { "amsel": 5 },
              "playtime": {},
              "dailyStars": {}
            }
            """.utf8,
        )

        let profile = try JSONDecoder().decode(Profile.self, from: older)

        #expect(profile.collection == nil)
        #expect(profile.recognitions == ["amsel": 5])
    }

    @Test("a chosen collection is read back, and no choice is not written")
    func decodesCollection() throws {
        let chosen = Profile(
            id: UUID(),
            name: "Mila",
            avatar: "feather",
            collection: "afrika",
        )
        let everything = Profile(id: UUID(), name: "Jonas", avatar: "bird")

        let written = try JSONEncoder().encode([chosen, everything])
        let read = try JSONDecoder().decode([Profile].self, from: written)

        #expect(read == [chosen, everything])
        #expect(read.map(\.collection) == ["afrika", nil])
        // A child who plays with every bird carries no key for it: the
        // optional encodes as absent rather than as `null`, which is exactly
        // what a file written before #187 looks like.
        let text = try #require(String(data: written, encoding: .utf8))
        #expect(text.contains("\"collection\":\"afrika\""))
        #expect(!text.contains("null"))
    }

    @Test("the avatar choices are the eight the profile picker offers")
    func offersEightAvatars() {
        #expect(
            Profile.avatarChoices == [
                "bird",
                "egg",
                "feather",
                "leaf",
                "star",
                "sparkles",
                "house",
                "lightbulb",
            ],
        )
    }
}
