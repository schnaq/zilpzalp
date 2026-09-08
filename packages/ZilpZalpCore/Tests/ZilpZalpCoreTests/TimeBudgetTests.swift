import Foundation
import Testing
import ZilpZalpCore

@Test(
    "Without a limit nothing is ever exhausted and nothing is ever left over",
    arguments: [0.0, 60.0, 21600.0, 10_000_000.0],
)
func noLimitIsUnlimited(playedToday: TimeInterval) {
    let budget = TimeBudget(limit: nil, playedToday: playedToday)

    #expect(budget.remaining == nil)
    #expect(budget.isExhausted == false)
}

@Test("A limit in minutes is the same budget as the limit in seconds")
func minutesAreSeconds() {
    #expect(TimeBudget(limitMinutes: 30, playedToday: 0).limit == 1800)
    #expect(TimeBudget(limitMinutes: nil, playedToday: 0).limit == nil)
    #expect(
        TimeBudget(limitMinutes: 15, playedToday: 300)
            == TimeBudget(limit: 900, playedToday: 300),
    )
}

@Test(
    "What is left is the limit less the day, and never a debt",
    arguments: [
        // limit, played, remaining
        (1800.0, 0.0, 1800.0),
        (1800, 600, 1200),
        (1800, 1800, 0),
        // The round that used the last minute was played to its end.
        (1800, 2400, 0),
    ],
)
func remainingCountsDown(limit: TimeInterval, played: TimeInterval, expected: TimeInterval) {
    #expect(TimeBudget(limit: limit, playedToday: played).remaining == expected)
}

@Test(
    "The day is over exactly when nothing is left",
    arguments: [
        // limit, played, exhausted
        (1800.0, 1799.0, false),
        (1800, 1800, true),
        (1800, 1801, true),
        // A limit of zero is no preset, but a hand-edited file can hold one.
        (0, 0, true),
    ],
)
func exhaustionFollowsWhatIsLeft(limit: TimeInterval, played: TimeInterval, expected: Bool) {
    #expect(TimeBudget(limit: limit, playedToday: played).isExhausted == expected)
}

@Test("A day that counts backwards buys no extra time")
func negativeValuesAreClamped() {
    let played = TimeBudget(limit: 1800, playedToday: -600)
    #expect(played.playedToday == 0)
    #expect(played.remaining == 1800)
    #expect(played.isExhausted == false)

    // A negative limit is not "unlimited" — `nil` is the only way to say that.
    let limit = TimeBudget(limit: -1800, playedToday: 0)
    #expect(limit.limit == 0)
    #expect(limit.isExhausted)
}

@Test("Every preset the grown-ups' area offers behaves the same way")
func everyPresetCountsDown() {
    for minutes in [15, 30, 45, 60] {
        let full = TimeBudget(limitMinutes: minutes, playedToday: 0)
        #expect(full.isExhausted == false)
        #expect(full.remaining == TimeInterval(minutes) * 60)

        let spent = TimeBudget(limitMinutes: minutes, playedToday: TimeInterval(minutes) * 60)
        #expect(spent.isExhausted)
        #expect(spent.remaining == 0)
    }
}
