import Foundation
import os

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
    /// How often the round recognised each species: answered right at the
    /// first attempt, and nothing else. Added onto the profile's counters,
    /// where the profile's threshold of them earns the bird's sticker (#177,
    /// #260).
    ///
    /// A bird the round merely asked about is not in here. Meeting a bird used
    /// to be enough to collect it; with four choices the right tile is always
    /// found in the end, and an album filled that way said what the child had
    /// seen rather than what it knows.
    public var recognitions: [String: Int]
    /// How long the round took, in seconds.
    public var playtime: TimeInterval

    public init(stars: Int, recognitions: [String: Int], playtime: TimeInterval) {
        self.stars = stars
        self.recognitions = recognitions
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
///
/// **Backed up to iCloud** when the app hands over a ``CloudKeyValueStore``:
/// one key per profile, one for the deleted ones. Every write merges what the
/// cloud holds into the file first and mirrors the result back — see
/// ``Profile/merged(with:)`` — and ``sync(now:)`` does the same without a
/// change of its own, at launch and whenever another device wrote. The file
/// stays what the app reads; the cloud is how it reaches the next device and
/// survives a reinstall.
public actor ProfileStore {
    /// The version this build writes. A file carrying anything else is not
    /// read — ``ProfileStoreError/unsupportedSchemaVersion(_:)`` — and a
    /// migration from an older version hooks in where that check stands.
    private static let schemaVersion = 1

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
    private let cloud: (any CloudKeyValueStore)?

    /// - Parameters:
    ///   - directory: the directory holding `Profiles/profiles.json`. The app
    ///     passes ``applicationSupport()``, tests a temporary directory. It
    ///     does not have to exist; the first write creates it.
    ///   - cloud: where the profiles are backed up, `nil` for nowhere — the
    ///     screenshot run and most tests.
    public init(directory: URL, cloud: (any CloudKeyValueStore)? = nil) {
        self.directory = directory.appending(path: "Profiles")
        file = self.directory.appending(path: "profiles.json")
        self.cloud = cloud
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
        try read().profiles
    }

    /// Merges what the cloud holds into the file and the file into the cloud,
    /// and returns the profiles as they now stand.
    ///
    /// Called at launch — so that a reinstalled app finds its children before
    /// it asks for a new one — and whenever another device changed the cloud.
    /// A file that cannot be read is never overwritten from the cloud: it
    /// throws exactly as ``profiles()`` does.
    ///
    /// - Parameter now: decides which deleted ids are old enough to forget.
    public func sync(now: Date = Date()) throws -> [Profile] {
        let stored = try read()
        guard let cloud else { return stored.profiles }
        var local = stored
        // A profile from before iCloud has no creation date. Spelled out once
        // from the file's order, so that the cloud — which has none — hands
        // the next device the children in the order this one shows them.
        for index in local.profiles.indices where local.profiles[index].createdAt == .distantPast {
            local.profiles[index].createdAt = Date.distantPast.addingTimeInterval(Double(index))
        }
        let merged = Self.merged(local, Self.contents(of: cloud), now: now)
        if merged != stored {
            try writeFile(merged)
        }
        mirror(merged, to: cloud)
        return merged.profiles
    }

    /// Creates a profile with no stars, no rounds and nothing recognised.
    ///
    /// - Returns: the profile that was created, with its fresh id.
    @discardableResult
    public func add(name: String, avatar: String, now: Date = Date()) throws -> Profile {
        var stored = try read()
        let profile = Profile(
            id: UUID(),
            name: name,
            avatar: avatar,
            createdAt: now,
            modifiedAt: now,
        )
        stored.profiles.append(profile)
        try write(stored, now: now)
        return profile
    }

    /// Replaces the profile carrying `profile`'s id, and marks it changed at
    /// `now`.
    ///
    /// - Throws: ``ProfileStoreError/unknownProfile(_:)`` when no profile
    ///   carries that id.
    public func update(_ profile: Profile, now: Date = Date()) throws {
        var stored = try read()
        guard let index = stored.profiles.firstIndex(where: { $0.id == profile.id }) else {
            throw ProfileStoreError.unknownProfile(profile.id)
        }
        stored.profiles[index] = profile
        stored.profiles[index].modifiedAt = now
        try write(stored, now: now)
    }

    /// Gives the profile with `id` a new name and avatar, and touches nothing
    /// else.
    ///
    /// Read from the file rather than handed a whole profile, so a copy the
    /// app has held since before the last round cannot write its stars back
    /// over the ones that round booked. The id stays, and with it everything
    /// the child has collected.
    ///
    /// - Returns: the profile as it now stands.
    /// - Throws: ``ProfileStoreError/unknownProfile(_:)`` when no profile
    ///   carries `id`.
    @discardableResult
    public func edit(
        _ id: Profile.ID,
        name: String,
        avatar: String,
        now: Date = Date(),
    ) throws -> Profile {
        var stored = try read()
        guard let index = stored.profiles.firstIndex(where: { $0.id == id }) else {
            throw ProfileStoreError.unknownProfile(id)
        }
        stored.profiles[index].name = name
        stored.profiles[index].avatar = avatar
        stored.profiles[index].modifiedAt = now
        try write(stored, now: now)
        return stored.profiles[index]
    }

    /// Deletes the profile with `id` and everything it collected — on every
    /// device, when there is a cloud: its id is kept as deleted, so that no
    /// other device's copy brings it back.
    ///
    /// - Throws: ``ProfileStoreError/unknownProfile(_:)`` when no profile
    ///   carries that id.
    public func delete(_ id: Profile.ID, now: Date = Date()) throws {
        var stored = try read()
        guard let index = stored.profiles.firstIndex(where: { $0.id == id }) else {
            throw ProfileStoreError.unknownProfile(id)
        }
        stored.profiles.remove(at: index)
        if cloud != nil {
            stored.deleted[id.uuidString] = now
        }
        try write(stored, now: now)
    }

    /// Books a finished round onto a profile: its stars, one more round, its
    /// recognitions onto the counters — and any sticker they now reach into
    /// the album — and its stars and seconds onto `date`'s day.
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
        var stored = try read()
        var profiles = stored.profiles
        guard let index = profiles.firstIndex(where: { $0.id == id }) else {
            throw ProfileStoreError.unknownProfile(id)
        }

        profiles[index].totalStars += round.stars
        profiles[index].roundsPlayed += 1
        for (species, times) in round.recognitions {
            profiles[index].recognitions[species, default: 0] += times
        }
        let today = Profile.dayKey(for: date, calendar: calendar)
        profiles[index].playtime[today, default: 0] += round.playtime
        profiles[index].dailyStars[today, default: 0] += round.stars

        stored.profiles = profiles
        let written = try write(stored, now: date, pruningDaysIn: calendar)
        return written.profiles.first { $0.id == id } ?? profiles[index]
    }

    /// What the file holds: the profiles, and — keyed by `UUID` string, with
    /// when — the ids of the ones deleted, for as long as another device might
    /// still bring one back.
    struct Contents: Equatable {
        var profiles: [Profile] = []
        var deleted: [String: Date] = [:]
    }

    /// The file's shape, for reading. Writing goes through
    /// ``document(of:)`` — see there.
    ///
    /// `deleted` is optional because a file from before iCloud has none, and
    /// an older build reading a newer file simply passes over it.
    private struct Document: Decodable {
        let profiles: [Profile]
        let deleted: [String: Date]?
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

    private func read() throws -> Contents {
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            // No file yet is the normal state of a fresh install, not a fault.
            return Contents()
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
            let document = try JSONDecoder().decode(Document.self, from: data)
            return Contents(profiles: document.profiles, deleted: document.deleted ?? [:])
        } catch {
            throw ProfileStoreError.corruptFile(reason: String(describing: error))
        }
    }

    /// Writes `contents` — merged with the cloud first, when there is one, and
    /// mirrored back to it after — and returns what was written.
    ///
    /// - Parameter calendar: prunes the days by it, after the merge: the
    ///   cloud still holds the days this device dropped last time.
    @discardableResult
    private func write(
        _ contents: Contents,
        now: Date,
        pruningDaysIn calendar: Calendar? = nil,
    ) throws -> Contents {
        var written = contents
        if let cloud {
            written = Self.merged(contents, Self.contents(of: cloud), now: now)
        }
        if let calendar {
            written.profiles = Self.pruned(written.profiles, on: now, calendar: calendar)
        }
        try writeFile(written)
        if let cloud {
            mirror(written, to: cloud)
        }
        return written
    }

    private func writeFile(_ contents: Contents) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Self.document(of: contents).write(to: file, options: .atomic)
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
    private static func document(of contents: Contents) throws -> Data {
        var document = Data("{\n  \"schemaVersion\" : \(schemaVersion),\n  \"profiles\" : ".utf8)
        try append(contents.profiles, to: &document)
        // Only when there is something to say, so that a device without a
        // cloud writes the file it always wrote.
        if !contents.deleted.isEmpty {
            document.append(contentsOf: ",\n  \"deleted\" : ".utf8)
            try append(contents.deleted, to: &document)
        }
        document.append(contentsOf: "\n}\n".utf8)
        return document
    }

    /// `value` pretty-printed from column zero, in a document that holds it
    /// one level in — so every line break gains two spaces. Line breaks inside
    /// a value cannot be hit: the encoder escapes them.
    private static func append(_ value: some Encodable, to document: inout Data) throws {
        for byte in try encoder.encode(value) {
            document.append(byte)
            if byte == UInt8(ascii: "\n") {
                document.append(contentsOf: "  ".utf8)
            }
        }
    }
}
