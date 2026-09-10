import Foundation

/// What can go wrong while reading the grown-ups' settings.
///
/// Both cases mean the same thing to the screen — the file cannot be trusted —
/// but they are told apart because only one of them is worth reporting to a
/// grown-up as "this app is older than its data".
public enum ParentalSettingsStoreError: Error, Sendable {
    /// The file is there and is not the document this store writes: truncated,
    /// half-written by a version that crashed, or edited by hand.
    case unreadable(any Error)
    /// The file was written by a later version of the app. Reading it as
    /// version 1 would silently drop whatever that version added, and writing
    /// it back would destroy it, so the store refuses both.
    case unsupportedSchemaVersion(found: Int, supported: Int)
}

/// What grown-ups decide about the app, for everybody who plays on this device.
///
/// Not per profile: these are house rules, and a four-year-old switching to
/// their own nest should not win itself another quarter of an hour. The daily
/// limit (#36) is the one value that will grow a per-profile twin, which is
/// why it sits here as a plain number and not as a type yet.
public struct ParentalSettings: Codable, Sendable, Hashable {
    /// Minutes of play per day, `nil` for no limit. Counted in `ZilpZalpCore`
    /// from values the shell passes in (#36); nothing here keeps a clock.
    public var dailyLimitMinutes: Int?

    /// Whether the app says its sentences out loud: the bird's name in game 1,
    /// the praise at the end of a round, the name of a sticker that is tapped,
    /// every headline a screen reads to a child who cannot read it.
    ///
    /// On until a grown-up switches it off (#231). A child who cannot read is
    /// told what to look for by the voice, so silence is something somebody
    /// chooses rather than a state a device can drift into.
    ///
    /// Not the bird calls: those are the recordings game 2 asks its question
    /// with, and where there are calls, that game is there (#138).
    public var speechEnabled: Bool

    /// The state a device that has never been to the grown-ups' area is in:
    /// nothing limited, and everything said out loud.
    public init(
        dailyLimitMinutes: Int? = nil,
        speechEnabled: Bool = true,
    ) {
        self.dailyLimitMinutes = dailyLimitMinutes
        self.speechEnabled = speechEnabled
    }
}

/// Reads and writes `Settings/parental.json` under the directory it is given.
///
/// An actor because the screen writes on every change while the games read:
/// one file, one owner of it. The directory is a parameter rather than
/// `URL.applicationSupportDirectory` so the tests run against a temporary one
/// and never touch the machine they run on.
///
/// Nothing is cached. A settings file is one field read at most once per
/// screen, and a cache would be one more thing that can be stale.
public actor ParentalSettingsStore {
    /// The shape this store writes. Raised only together with a migration
    /// step; a file that names a higher one is refused rather than guessed at.
    public static let schemaVersion = 1

    private static let directoryName = "Settings"
    private static let fileName = "parental.json"

    private let directory: URL
    private let file: URL

    /// - Parameter directory: Where `Settings/parental.json` lives underneath.
    ///   The app passes Application Support; the tests pass a temporary
    ///   directory. Neither has to exist yet.
    public init(directory: URL) {
        self.directory = directory.appending(path: Self.directoryName)
        file = self.directory.appending(path: Self.fileName)
    }

    /// The settings on disk, or the defaults when there is no file yet.
    ///
    /// - Throws: ``ParentalSettingsStoreError`` when a file exists but cannot
    ///   be read as version ``schemaVersion``.
    public func load() throws -> ParentalSettings {
        let data: Data
        do {
            data = try Data(contentsOf: file)
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            // A device that has never been to the grown-ups' area. Not a
            // failure, and writing the defaults out here would only turn a
            // read into a write.
            return ParentalSettings()
        } catch {
            throw ParentalSettingsStoreError.unreadable(error)
        }

        let decoder = JSONDecoder()
        let version: Int
        do {
            // The version alone first, so a file from a later app version is
            // told apart from a broken one even when its other fields no
            // longer decode.
            version = try decoder.decode(SchemaProbe.self, from: data).schemaVersion
        } catch {
            throw ParentalSettingsStoreError.unreadable(error)
        }

        guard version <= Self.schemaVersion else {
            throw ParentalSettingsStoreError.unsupportedSchemaVersion(
                found: version,
                supported: Self.schemaVersion,
            )
        }

        do {
            return try decoder.decode(Document.self, from: data).settings
        } catch {
            throw ParentalSettingsStoreError.unreadable(error)
        }
    }

    /// Writes the settings out, replacing whatever was there.
    ///
    /// Atomic: the file a child's iPad finds after a battery death is either
    /// the old one or the new one, never half of each.
    public func save(_ settings: ParentalSettings) throws {
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
        )

        let encoder = JSONEncoder()
        // Readable on purpose — this is a file a grown-up may well open — and
        // sorted because the alternative is not "the order they were encoded
        // in" but a different order on every run: `JSONEncoder` writes a keyed
        // container in the hash order of its keys, and Swift seeds its hashing
        // per process. Measured over five runs of the same code, this document
        // came out in four different orders. Sorting is the only way to get
        // the same bytes twice, which is what makes a diff of this file mean
        // something.
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(Document(settings: settings)).write(to: file, options: .atomic)
    }
}

// MARK: - The file format

/// Just enough of the file to learn how to read the rest of it.
private struct SchemaProbe: Decodable {
    let schemaVersion: Int
}

/// The document on disk: the version and the settings, flat.
///
/// Its own type rather than `Codable` on ``ParentalSettings`` itself, which
/// carries no version and would nest if it were a field here.
///
/// Where the version sits in the file is not this type's business and cannot
/// be: JSON objects are unordered, and `JSONEncoder` proves it by writing the
/// same document in a different order on every run. What the plan's contract
/// is actually after — reading the version before trusting anything else —
/// is ``SchemaProbe``'s job, and that works whatever order the file is in.
private struct Document: Codable {
    let schemaVersion: Int
    let dailyLimitMinutes: Int?
    /// `Bool?` where the setting is a plain `Bool`, so that a file written
    /// before #231 — which is every file on every device today — decodes
    /// instead of throwing on a key it does not carry. ``settings`` fills the
    /// gap with the default.
    let speechEnabled: Bool?

    /// Decoding is synthesised: for an `Int?` it already reads both spellings
    /// of "no limit", the explicit `null` this store writes and an absent key,
    /// and for a `Bool?` an absent key is what a file from before the setting
    /// existed has. Which is why every field here is optional.
    ///
    /// It also passes over a key it does not know, and that is why dropping
    /// `callsEnabled` (#138) and `showNames` (#208) left the version at 1:
    /// every file already on a device may still name one or both settings,
    /// and every one of them still reads.
    var settings: ParentalSettings {
        ParentalSettings(
            dailyLimitMinutes: dailyLimitMinutes,
            speechEnabled: speechEnabled ?? true,
        )
    }

    init(settings: ParentalSettings) {
        schemaVersion = ParentalSettingsStore.schemaVersion
        dailyLimitMinutes = settings.dailyLimitMinutes
        speechEnabled = settings.speechEnabled
    }

    /// The one half that cannot be synthesised: `encodeIfPresent` would leave
    /// the key out for "no limit", and the file states that setting rather
    /// than leaving it to be inferred from a gap.
    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        if let dailyLimitMinutes {
            try container.encode(dailyLimitMinutes, forKey: .dailyLimitMinutes)
        } else {
            try container.encodeNil(forKey: .dailyLimitMinutes)
        }
        // Stated too, and never `encodeIfPresent`: the setting always stands
        // somewhere, and a file that left the key out would read back as a
        // file from before the setting existed.
        try container.encode(speechEnabled ?? true, forKey: .speechEnabled)
    }
}
