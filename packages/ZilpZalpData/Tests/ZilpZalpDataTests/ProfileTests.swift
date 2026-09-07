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
