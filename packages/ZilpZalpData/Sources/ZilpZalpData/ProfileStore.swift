import Foundation

/// What can go wrong while reading or writing the profiles.
public enum ProfileStoreError: Error, Sendable, Equatable {
    /// The file is there but is not a profile document. Carries the decoder's
    /// complaint, because a file nobody can read is worth a look before it is
    /// thrown away.
    case corruptFile(reason: String)
    /// The file was written by a version of the app that this one does not
    /// know. Never overwrite it: a newer build's profiles are still the
    /// child's profiles.
    case unsupportedSchemaVersion(Int)
    case unknownProfile(Profile.ID)
}

/// A finished round as the store books it onto a profile.
///
/// Deliberately not the quiz's own round result: that one counts questions
/// and first-try answers, this one carries what a profile keeps. The screen
/// in between translates.
public struct PlayedRound: Sendable, Hashable {
    /// The stars the round earned — one, two or three.
    public var stars: Int
    /// The species the round asked for; they end up in the collection whether
    /// they were answered right or wrong. The album is a memory of what the
    /// child has seen, not a record of its mistakes.
    public var species: Set<String>
    /// How long the round took, in seconds.
    public var playtime: TimeInterval

    public init(stars: Int, species: Set<String>, playtime: TimeInterval) {
        self.stars = stars
        self.species = species
        self.playtime = playtime
    }
}

/// The profiles, in one JSON file under a directory the caller names.
///
/// An actor over a file rather than SwiftData: there are at most a handful of
/// profiles, and JSON behind an actor stays inspectable, migratable and
/// testable without a simulator. The directory is an argument so that the app
/// passes Application Support and every test passes a temporary directory.
///
/// Every write goes through `Data.write(options: .atomic)`, so a crash
/// mid-write leaves either the old file or the new one, never half of both.
public actor ProfileStore {
    /// The version this build writes. A file carrying anything else is not
    /// read — ``ProfileStoreError/unsupportedSchemaVersion(_:)`` — and a
    /// migration from an older version hooks in where that check stands.
    private static let schemaVersion = 1

    /// How many days of ``Profile/playtime`` and ``Profile/dailyStars`` the
    /// file keeps, today included.
    private static let retainedDays = 7

    /// One encoder for every write. Sorted, so that a file only changes when
    /// a value in it changes; pretty-printed, so that a parent — or a
    /// developer chasing a bug report — can read it.
    private static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }()

    private let directory: URL
    private let file: URL

    /// - Parameter directory: the directory holding `Profiles/profiles.json`.
    ///   The app passes ``applicationSupport()``, tests a temporary
    ///   directory. It does not have to exist; the first write creates it.
    public init(directory: URL) {
        self.directory = directory.appending(path: "Profiles")
        file = self.directory.appending(path: "profiles.json")
    }

    /// The app's Application Support directory, created if it is not there
    /// yet — iOS ships an app without one.
    public static func applicationSupport() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true,
        )
    }

    /// Every profile, in the order it was created.
    ///
    /// - Returns: the profiles, empty when nothing has been saved yet.
    /// - Throws: ``ProfileStoreError`` when the file is unreadable, and the
    ///   underlying file system error when the file cannot be opened for a
    ///   reason other than not existing.
    public func profiles() throws -> [Profile] {
        try read()
    }

    /// Creates a profile with no stars, no rounds and nothing collected.
    ///
    /// - Returns: the profile that was created, with its fresh id.
    @discardableResult
    public func add(name: String, avatar: String) throws -> Profile {
        var profiles = try read()
        let profile = Profile(id: UUID(), name: name, avatar: avatar)
        profiles.append(profile)
        try write(profiles)
        return profile
    }

    /// Replaces the profile carrying `profile`'s id.
    ///
    /// - Throws: ``ProfileStoreError/unknownProfile(_:)`` when no profile
    ///   carries that id.
    public func update(_ profile: Profile) throws {
        var profiles = try read()
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            throw ProfileStoreError.unknownProfile(profile.id)
        }
        profiles[index] = profile
        try write(profiles)
    }

    /// Deletes the profile with `id` and everything it collected.
    ///
    /// - Throws: ``ProfileStoreError/unknownProfile(_:)`` when no profile
    ///   carries that id.
    public func delete(_ id: Profile.ID) throws {
        var profiles = try read()
        guard let index = profiles.firstIndex(where: { $0.id == id }) else {
            throw ProfileStoreError.unknownProfile(id)
        }
        profiles.remove(at: index)
        try write(profiles)
    }

    /// Books a finished round onto a profile: its stars, one more round, its
    /// species into the collection, and its stars and seconds onto `date`'s
    /// day.
    ///
    /// The only operation that knows what a round means. Whoever adds the
    /// stars by hand and calls ``update(_:)`` will sooner or later forget the
    /// playtime.
    ///
    /// - Parameters:
    ///   - round: what the round produced.
    ///   - id: the profile that played it.
    ///   - date: when it was played. An argument rather than `Date()` so that
    ///     the day boundary is the test's to decide.
    ///   - calendar: the calendar the day key is formed in.
    /// - Returns: the profile as it now stands.
    /// - Throws: ``ProfileStoreError/unknownProfile(_:)`` when no profile
    ///   carries `id`.
    @discardableResult
    public func record(
        round: PlayedRound,
        for id: Profile.ID,
        on date: Date,
        calendar: Calendar = .current,
    ) throws -> Profile {
        var profiles = try read()
        guard let index = profiles.firstIndex(where: { $0.id == id }) else {
            throw ProfileStoreError.unknownProfile(id)
        }

        profiles[index].totalStars += round.stars
        profiles[index].roundsPlayed += 1
        profiles[index].collectedSpecies.formUnion(round.species)
        let today = Profile.dayKey(for: date, calendar: calendar)
        profiles[index].playtime[today, default: 0] += round.playtime
        profiles[index].dailyStars[today, default: 0] += round.stars

        // Every profile, not only the one that played: a child who stopped
        // playing a fortnight ago should not keep a fortnight of days in the
        // file just because nobody touched its profile.
        let oldest = Self.oldestRetainedDay(on: date, calendar: calendar)
        for position in profiles.indices {
            // The keys are zero-padded `YYYY-MM-DD`, so comparing them as
            // strings compares them as dates. Days in the future — a clock
            // that was set back — are kept.
            profiles[position].playtime = profiles[position].playtime.filter { $0.key >= oldest }
            profiles[position].dailyStars = profiles[position].dailyStars
                .filter { $0.key >= oldest }
        }

        try write(profiles)
        return profiles[index]
    }

    /// The oldest ``Profile/playtime`` and ``Profile/dailyStars`` key a write
    /// keeps: `date`'s day and the six before it.
    private static func oldestRetainedDay(on date: Date, calendar: Calendar) -> String {
        // The same calendar the keys are formed in, so that counting days
        // back and spelling them out cannot disagree.
        let days = Profile.days(in: calendar)
        let today = days.startOfDay(for: date)
        // Subtracting days from a midnight has no failing case; falling back
        // on the day itself would merely keep one day instead of seven.
        let oldest = days.date(byAdding: .day, value: -(retainedDays - 1), to: today) ?? today
        return Profile.dayKey(for: oldest, calendar: calendar)
    }

    /// The file's shape, for reading. Writing goes through
    /// ``document(of:)`` — see there.
    private struct Document: Decodable {
        let profiles: [Profile]
    }

    /// Reads the version by itself, before the profiles.
    ///
    /// Two passes on purpose: a document from a newer build may spell a
    /// profile differently, and decoding it in one pass would report a
    /// mangled field where the honest answer is "this file is newer than I
    /// am".
    private struct SchemaProbe: Decodable {
        let schemaVersion: Int
    }

    private func read() throws -> [Profile] {
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            // No file yet is the normal state of a fresh install, not a fault.
            return []
        }

        let version: Int
        do {
            version = try JSONDecoder().decode(SchemaProbe.self, from: data).schemaVersion
        } catch {
            throw ProfileStoreError.corruptFile(reason: String(describing: error))
        }
        guard version == Self.schemaVersion else {
            throw ProfileStoreError.unsupportedSchemaVersion(version)
        }

        do {
            return try JSONDecoder().decode(Document.self, from: data).profiles
        } catch {
            throw ProfileStoreError.corruptFile(reason: String(describing: error))
        }
    }

    private func write(_ profiles: [Profile]) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.document(of: profiles).write(to: file, options: .atomic)
    }

    /// The bytes of the file.
    ///
    /// The document's own two keys are written here rather than encoded,
    /// because `JSONEncoder` decides the order of an object's keys itself: it
    /// ignores the order they were encoded in, and `.sortedKeys` — which the
    /// profiles need to stay byte-stable — would put `profiles` before
    /// `schemaVersion`. The version has to stand first: whoever meets a file
    /// from a build newer than their own should be able to see what they are
    /// holding before trying to understand the rest of it.
    private static func document(of profiles: [Profile]) throws -> Data {
        var document = Data("{\n  \"schemaVersion\" : \(schemaVersion),\n  \"profiles\" : ".utf8)
        // The array is pretty-printed from column zero; in the document it
        // sits one level in, so every line break gains two spaces. Line
        // breaks inside a value cannot be hit: the encoder escapes them.
        for byte in try encoder.encode(profiles) {
            document.append(byte)
            if byte == UInt8(ascii: "\n") {
                document.append(contentsOf: "  ".utf8)
            }
        }
        document.append(contentsOf: "\n}\n".utf8)
        return document
    }
}
