/// A child's daily play limit, and how much of today it has already used.
///
/// **Nothing here can end a round that is under way** — this type has no
/// notion of one. It answers a single question about a single day, and the
/// shell only ever asks it between rounds: when a game tile is tapped, and
/// once a finished round has been booked. That is the whole of the rule the
/// issue insists on. A child is never cut off mid-question, because there is
/// nothing to cut off with.
///
/// No clock either, per the module's boundary: both numbers are handed in.
/// Which day "today" is, and how many seconds of it are gone, is the shell's
/// to look up — freshly on every ask, so a day that turns over while the app
/// is open turns over here too.
///
/// Seconds are plain `Double` rather than `TimeInterval`, which is a
/// Foundation typealias for the same thing: this module imports nothing, and
/// a caller holding a `TimeInterval` passes it without noticing.
public struct TimeBudget: Hashable, Sendable {
    /// How long a day may last, in seconds. `nil` is no limit at all, which
    /// is what a family that has never opened the grown-ups' area gets.
    public let limit: Double?

    /// Seconds already played today. Clamped at zero on the way in: a file
    /// edited by hand — or a clock set backwards under a round — must not be
    /// able to hand a child extra time by counting downwards.
    public let playedToday: Double

    /// - Parameters:
    ///   - limit: seconds per day, `nil` for no limit.
    ///   - playedToday: seconds already played on the day being asked about.
    public init(limit: Double?, playedToday: Double) {
        self.limit = limit.map { Swift.max(0, $0) }
        self.playedToday = Swift.max(0, playedToday)
    }

    /// The same budget as the grown-ups' area states it: whole minutes, or
    /// `nil` for "Kein Limit".
    ///
    /// - Parameters:
    ///   - limitMinutes: `ParentalSettings.dailyLimitMinutes`.
    ///   - playedToday: seconds already played on the day being asked about.
    public init(limitMinutes: Int?, playedToday: Double) {
        self.init(
            limit: limitMinutes.map { Double($0) * Self.secondsPerMinute },
            playedToday: playedToday,
        )
    }

    /// How much of today is left, or `nil` when there is no limit.
    ///
    /// Never negative: a round that overran its limit — every round does, it
    /// is played to the end — leaves zero rather than a debt to carry into
    /// tomorrow.
    public var remaining: Double? {
        limit.map { Swift.max(0, $0 - playedToday) }
    }

    /// Whether today's play is over.
    ///
    /// `false` whenever there is no limit, whatever has been played. `true`
    /// the moment nothing is left — including a limit of zero, which no
    /// preset offers but a hand-edited settings file can hold.
    public var isExhausted: Bool {
        guard let remaining else { return false }
        return remaining <= 0
    }

    /// Seconds in the minutes the grown-ups' area counts in.
    private static let secondsPerMinute: Double = 60
}
