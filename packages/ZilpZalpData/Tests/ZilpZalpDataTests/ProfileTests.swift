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
