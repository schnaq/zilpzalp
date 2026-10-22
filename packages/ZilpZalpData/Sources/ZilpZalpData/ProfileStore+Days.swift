import Foundation

/// The days a profile keeps: today and the six before it.
extension ProfileStore {
    /// How many days of ``Profile/playtime`` and ``Profile/dailyStars`` the
    /// file keeps, today included.
    fileprivate static let retainedDays = 7

    /// Every profile, not only the one that played, with only the days
    /// ``oldestRetainedDay(on:calendar:)`` keeps: a child who stopped playing
    /// a fortnight ago should not keep a fortnight of days in the file just
    /// because nobody touched its profile.
    static func pruned(
        _ profiles: [Profile],
        on date: Date,
        calendar: Calendar,
    ) -> [Profile] {
        let oldest = oldestRetainedDay(on: date, calendar: calendar)
        // The keys are zero-padded `YYYY-MM-DD`, so comparing them as strings
        // compares them as dates. Days in the future — a clock that was set
        // back — are kept.
        return profiles.map { profile in
            var profile = profile
            profile.playtime = profile.playtime.filter { $0.key >= oldest }
            profile.dailyStars = profile.dailyStars.filter { $0.key >= oldest }
            return profile
        }
    }

    /// The oldest ``Profile/playtime`` and ``Profile/dailyStars`` key a write
    /// keeps: `date`'s day and the six before it.
    fileprivate static func oldestRetainedDay(on date: Date, calendar: Calendar) -> String {
        // The same calendar the keys are formed in, so that counting days
        // back and spelling them out cannot disagree.
        let days = Profile.days(in: calendar)
        let today = days.startOfDay(for: date)
        // Subtracting days from a midnight has no failing case; falling back
        // on the day itself would merely keep one day instead of seven.
        let oldest = days.date(byAdding: .day, value: -(retainedDays - 1), to: today) ?? today
        return Profile.dayKey(for: oldest, calendar: calendar)
    }
}
