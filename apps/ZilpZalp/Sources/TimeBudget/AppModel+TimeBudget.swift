import Foundation
import ZilpZalpCore
import ZilpZalpData

/// What the daily limit needs from the shell, beside ``AppModel`` rather than
/// in it only because that file sits at SwiftLint's length ceiling.
extension AppModel {
    /// The playing child's day against the limit the grown-ups set.
    ///
    /// Computed on every read, never stored, and that is the whole of the
    /// day-rollover handling: today's key is formed from `Date()` each time,
    /// so an app left open past midnight asks about the new day the next time
    /// anybody asks at all. Nothing has to notice the day turning over.
    ///
    /// Without a chosen child there is nothing to count, and the answer is a
    /// budget nobody has spent — never an exhausted one, which would strand
    /// the profile picker behind "Zeit fürs Nest".
    var timeBudget: TimeBudget {
        TimeBudget(
            limitMinutes: parental.settings.dailyLimitMinutes,
            playedToday: activeProfile?.playtime[Self.today] ?? 0,
        )
    }

    /// Stars the playing child has collected today, across every round and
    /// every launch of the app — what "Zeit fürs Nest" tells it about its day.
    var starsToday: Int {
        activeProfile?.dailyStars[Self.today] ?? 0
    }

    /// Today's key into ``Profile/playtime`` and ``Profile/dailyStars``, in
    /// the device's own calendar and time zone.
    private static var today: String {
        Profile.dayKey(for: Date())
    }
}
