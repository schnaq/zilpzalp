import Foundation

/// One child's profile: the name it picked, the avatar it picked and
/// everything the app remembers between rounds.
///
/// The rank is deliberately absent. It follows from ``totalStars`` through
/// `RankLadder` in `ZilpZalpCore` and is derived on every read, so it cannot
/// drift away from the stars that earned it. This module does not depend on
/// `ZilpZalpCore` — the derivation belongs to the caller.
///
/// Nothing here leaves the device. There is no account, no identifier that
/// means anything outside this installation, and no field a child could not
/// see for itself on the screen.
public struct Profile: Codable, Sendable, Hashable, Identifiable {
    /// The avatars a profile can be created with.
    ///
    /// Raw values of `ZIcon` in `ZilpZalpUI`, spelled out as strings because
    /// the data layer does not know the design system. When Johanna's
    /// pictures arrive (#45) they take the same field: a picture's file name
    /// is a string as well.
    public static let avatarChoices = [
        "bird",
        "egg",
        "feather",
        "leaf",
        "star",
        "sparkles",
        "house",
        "lightbulb",
    ]

    public var id: UUID
    public var name: String
    /// One of ``avatarChoices``. Not an enum: see there.
    public var avatar: String
    public var totalStars: Int
    public var roundsPlayed: Int
    /// Bird ids from the pack manifests.
    public var collectedSpecies: Set<String>
    /// Seconds played per calendar day, keyed as ``dayKey(for:calendar:)``
    /// spells it. ``ProfileStore`` keeps the last seven days and drops the
    /// rest — the daily limit needs today, the parents area needs the week,
    /// and nothing needs more than that.
    public var playtime: [String: TimeInterval]

    public init(
        id: UUID,
        name: String,
        avatar: String,
        totalStars: Int = 0,
        roundsPlayed: Int = 0,
        collectedSpecies: Set<String> = [],
        playtime: [String: TimeInterval] = [:],
    ) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.totalStars = totalStars
        self.roundsPlayed = roundsPlayed
        self.collectedSpecies = collectedSpecies
        self.playtime = playtime
    }

    /// The ``playtime`` key of `date`: the Gregorian `YYYY-MM-DD` of the day
    /// `date` falls on in `calendar`'s time zone.
    ///
    /// Built from date components rather than through a `DateFormatter`,
    /// which carries a calendar and a time zone of its own and would quietly
    /// disagree with the one it was handed. The zero-padded fields also make
    /// the keys sort and compare as dates, which is what the pruning in
    /// ``ProfileStore`` relies on.
    public static func dayKey(for date: Date, calendar: Calendar = .current) -> String {
        let day = days(in: calendar).dateComponents([.year, .month, .day], from: date)
        // The three components were just requested, so they are all there.
        return String(format: "%04d-%02d-%02d", day.year ?? 0, day.month ?? 0, day.day ?? 0)
    }

    /// The calendar the day keys are counted in: Gregorian, in `calendar`'s
    /// time zone.
    ///
    /// Only the time zone is taken from the caller, because that is what
    /// decides when a day turns over. The year and the month are not: on a
    /// device set to the Japanese calendar, `Calendar.current` numbers this
    /// year 8, and a family that changed their region afterwards would end up
    /// with two sets of keys that no longer sort against each other — which
    /// is exactly what the seven-day pruning compares.
    static func days(in calendar: Calendar) -> Calendar {
        var days = Calendar(identifier: .gregorian)
        days.timeZone = calendar.timeZone
        return days
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case avatar
        case totalStars
        case roundsPlayed
        case collectedSpecies
        case playtime
    }

    /// Written by hand for one reason: a `Set` iterates in an order that
    /// changes from run to run, and `JSONEncoder`'s `.sortedKeys` sorts the
    /// keys of objects, not the elements of an array. Without this the
    /// file's bytes would churn without a single value having changed.
    /// ``playtime`` needs no such help — `.sortedKeys` covers it.
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(avatar, forKey: .avatar)
        try container.encode(totalStars, forKey: .totalStars)
        try container.encode(roundsPlayed, forKey: .roundsPlayed)
        try container.encode(collectedSpecies.sorted(), forKey: .collectedSpecies)
        try container.encode(playtime, forKey: .playtime)
    }
}
