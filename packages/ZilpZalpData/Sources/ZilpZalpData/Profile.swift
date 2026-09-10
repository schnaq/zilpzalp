import Foundation

/// One child's profile: the name it picked, the avatar it picked and
/// everything the app remembers between rounds.
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
    /// How often each bird has been recognised — answered right at the first
    /// attempt — keyed by the bird id from the pack manifests.
    ///
    /// The album is derived from this and stored nowhere: a bird's sticker is
    /// in it once the counter reaches the five that `Scoring` in
    /// `ZilpZalpCore` names (#177). The threshold is not repeated here,
    /// because this module does not depend on that one and should not for one
    /// number; the app target links both and answers the question in one
    /// place.
    public var recognitions: [String: Int]
    /// Seconds played per calendar day, keyed as ``dayKey(for:calendar:)``
    /// spells it. ``ProfileStore`` keeps the last seven days and drops the
    /// rest — the daily limit needs today, the parents area needs the week,
    /// and nothing needs more than that.
    public var playtime: [String: TimeInterval]
    /// Which birds this child's rounds ask about: the id of one installed
    /// pack, or `nil` for every bird there is (#187).
    ///
    /// A field of the child rather than of the device, because it is a taste
    /// and not a setting — one sibling wants Africa, the next one wants
    /// everything, and handing the iPad on has to hand the choice on with it.
    ///
    /// Nothing here checks that such a pack is installed. A grown-up may
    /// delete one while the choice stands, so the id is resolved against what
    /// is on the device every time it is read — see ``PackCollections`` — and
    /// it is deliberately left standing when it resolves to nothing: a read
    /// must not write, and downloading the pack again brings the choice back.
    ///
    /// Not the sticker album, which is `collection.*` in the String Catalog
    /// and ``recognitions`` in this file.
    public var collection: String?
    /// Stars earned per calendar day, keyed and pruned exactly as
    /// ``playtime`` is.
    ///
    /// Kept beside the running total rather than derived from it, because
    /// nothing else can answer "what did today bring?" — and "Zeit fürs Nest"
    /// (#36) is a screen a child may reach after a relaunch, hours after the
    /// stars were earned. A counter that only remembered this run of the app
    /// would tell that child it had collected nothing today.
    public var dailyStars: [String: Int]

    public init(
        id: UUID,
        name: String,
        avatar: String,
        totalStars: Int = 0,
        roundsPlayed: Int = 0,
        recognitions: [String: Int] = [:],
        collection: String? = nil,
        playtime: [String: TimeInterval] = [:],
        dailyStars: [String: Int] = [:],
    ) {
        self.id = id
        self.name = name
        self.avatar = avatar
        self.totalStars = totalStars
        self.roundsPlayed = roundsPlayed
        self.recognitions = recognitions
        self.collection = collection
        self.playtime = playtime
        self.dailyStars = dailyStars
    }

    /// Written by hand for the keys that arrived after the file format did: a
    /// profile written before ``dailyStars`` is a profile with no days counted
    /// yet, one written before ``recognitions`` is a profile with nothing
    /// counted yet, and one written before ``collection`` is a profile that
    /// plays with every bird — none of them is a broken file. Everything else
    /// decodes as it always has. The schema version stays 1, which is what
    /// lets this build read every file written before it.
    ///
    /// A file from before #177 also carries a `collectedSpecies` array, and it
    /// is deliberately ignored: those stickers were handed out for meeting a
    /// bird in a round, which is not what a sticker means any more. The stars
    /// such a profile earned are untouched, and the next write drops the key.
    ///
    /// **That last part only reads forwards.** A build from before #177
    /// decodes `collectedSpecies` as required, so once this one has written a
    /// profile, going back to that build finds no such key and reports the
    /// whole file unreadable — not one missing sticker but every child's
    /// stars. The version is left at 1 all the same: the app is pre-release,
    /// nobody downgrades a TestFlight build over a sticker rule, and bumping
    /// it would cost every tester their profiles today to spare a case that
    /// cannot happen tomorrow (#177).
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        avatar = try container.decode(String.self, forKey: .avatar)
        totalStars = try container.decode(Int.self, forKey: .totalStars)
        roundsPlayed = try container.decode(Int.self, forKey: .roundsPlayed)
        recognitions = try container.decodeIfPresent([String: Int].self, forKey: .recognitions)
            ?? [:]
        collection = try container.decodeIfPresent(String.self, forKey: .collection)
        playtime = try container.decode([String: TimeInterval].self, forKey: .playtime)
        dailyStars = try container.decodeIfPresent([String: Int].self, forKey: .dailyStars) ?? [:]
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
        case recognitions
        case collection
        case playtime
        case dailyStars
    }
}
