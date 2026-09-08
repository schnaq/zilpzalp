import Foundation
import Testing
import ZilpZalpData

/// Every test gets its own directory under the system's temporary one and
/// removes it again, so nothing here can see another test's file — or the
/// machine's real Application Support.
@Suite("Parental settings store")
struct ParentalSettingsStoreTests {
    /// Runs `body` against a store rooted in a directory that exists only for
    /// the duration of the test.
    private func withTemporaryStore(
        _ body: (ParentalSettingsStore, URL) async throws -> Void,
    ) async throws {
        let root = URL.temporaryDirectory.appending(path: UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        try await body(ParentalSettingsStore(directory: root), root)
    }

    private func settingsFile(under root: URL) -> URL {
        root.appending(path: "Settings").appending(path: "parental.json")
    }

    @Test("a device that has never been to the grown-ups' area gets the defaults")
    func loadsDefaultsWithoutAFile() async throws {
        try await withTemporaryStore { store, _ in
            let settings = try await store.load()

            #expect(settings.showNames)
            #expect(settings.dailyLimitMinutes == nil)
        }
    }

    @Test("reading the defaults writes nothing")
    func loadDoesNotCreateTheFile() async throws {
        try await withTemporaryStore { store, root in
            _ = try await store.load()

            #expect(!FileManager.default.fileExists(atPath: settingsFile(under: root).path))
        }
    }

    @Test("what was saved comes back")
    func roundTripsEveryField() async throws {
        try await withTemporaryStore { store, _ in
            let saved = ParentalSettings(showNames: false, dailyLimitMinutes: 30)
            try await store.save(saved)

            #expect(try await store.load() == saved)
        }
    }

    @Test("no limit survives the round trip as no limit")
    func roundTripsTheAbsentLimit() async throws {
        try await withTemporaryStore { store, root in
            try await store.save(ParentalSettings(dailyLimitMinutes: nil))

            #expect(try await store.load().dailyLimitMinutes == nil)
            // Stated in the file rather than left out of it: a grown-up
            // reading the file sees the setting exists and stands at "none".
            let written = try String(contentsOf: settingsFile(under: root), encoding: .utf8)
            #expect(written.contains("\"dailyLimitMinutes\""))
            #expect(written.contains("null"))
        }
    }

    /// The version has to be in the file, or a later app version's document
    /// cannot be recognised as one.
    ///
    /// Deliberately not "and it is the first key": JSON objects are unordered,
    /// and `JSONEncoder` writes a keyed container in the hash order of its
    /// keys, which Swift seeds per process — the same document came out in
    /// four different orders over five runs. A test on position would fail
    /// three CI runs in four. Reading the version before the rest is
    /// `SchemaProbe`'s job and needs no help from the layout.
    @Test("the version is written with the settings")
    func writesTheVersion() async throws {
        try await withTemporaryStore { store, root in
            try await store.save(ParentalSettings())

            let written = try String(contentsOf: settingsFile(under: root), encoding: .utf8)
            #expect(written.contains("\"schemaVersion\" : 1"))
        }
    }

    /// The same settings are written the same way on any run, which is what
    /// makes a diff of this file mean something.
    ///
    /// Asserted as the sorted layout rather than as "two saves match": Swift's
    /// hash seed is fixed within a process, so two saves in one test run come
    /// out identical whether the keys are sorted or not. Only the order itself
    /// tells the two apart.
    @Test("the keys are written in a fixed order")
    func writesDeterministically() async throws {
        try await withTemporaryStore { store, root in
            try await store.save(ParentalSettings(dailyLimitMinutes: 15))

            let written = try String(contentsOf: settingsFile(under: root), encoding: .utf8)
            let positions = try ["dailyLimitMinutes", "schemaVersion", "showNames"]
                .map { try #require(written.range(of: "\"\($0)\"")).lowerBound }
            #expect(positions == positions.sorted())
        }
    }

    @Test("a directory that does not exist yet is created")
    func createsTheDirectory() async throws {
        try await withTemporaryStore { store, root in
            try await store.save(ParentalSettings())

            #expect(FileManager.default.fileExists(atPath: settingsFile(under: root).path))
        }
    }

    @Test("saving twice leaves one readable file")
    func overwritesCleanly() async throws {
        try await withTemporaryStore { store, _ in
            try await store.save(ParentalSettings(dailyLimitMinutes: 45))
            try await store.save(ParentalSettings(showNames: false))

            let settings = try await store.load()
            #expect(!settings.showNames)
            #expect(settings.dailyLimitMinutes == nil)
        }
    }

    @Test("a file that is not this document is refused, not guessed at")
    func refusesACorruptFile() async throws {
        try await withTemporaryStore { store, root in
            try write("{ \"schemaVersion\": 1, \"showNames\":", to: root)

            await #expect(throws: ParentalSettingsStoreError.self) {
                try await store.load()
            }
        }
    }

    @Test("a file with the wrong types is refused")
    func refusesTheWrongTypes() async throws {
        try await withTemporaryStore { store, root in
            try write(
                #"{"schemaVersion": 1, "showNames": "ja"}"#,
                to: root,
            )

            await #expect(throws: ParentalSettingsStoreError.self) {
                try await store.load()
            }
        }
    }

    /// Reading a later version as version 1 would drop whatever it added, and
    /// the next save would write the loss to disk.
    @Test("a file from a later app version is refused")
    func refusesAHigherSchemaVersion() async throws {
        try await withTemporaryStore { store, root in
            try write(
                #"{"schemaVersion": 2, "showNames": false}"#,
                to: root,
            )

            let error = try await #require(throws: ParentalSettingsStoreError.self) {
                try await store.load()
            }
            guard case let .unsupportedSchemaVersion(found, supported) = error else {
                Issue.record("expected an unsupported version, got \(error)")
                return
            }
            #expect(found == 2)
            #expect(supported == ParentalSettingsStore.schemaVersion)
        }
    }

    @Test("a file without a version is a broken file")
    func refusesAFileWithoutAVersion() async throws {
        try await withTemporaryStore { store, root in
            try write(#"{"showNames": true}"#, to: root)

            await #expect(throws: ParentalSettingsStoreError.self) {
                try await store.load()
            }
        }
    }

    /// Every device that has been to the grown-ups' area before #138 has a
    /// file naming `callsEnabled`. The switch is gone and the version stayed
    /// at 1, so that key has to read as what it now is: nothing.
    @Test("a file from before the calls switch was dropped still reads")
    func ignoresTheDroppedCallsKey() async throws {
        try await withTemporaryStore { store, root in
            try write(
                #"{"schemaVersion": 1, "callsEnabled": false, "showNames": false}"#,
                to: root,
            )

            #expect(try await store.load() == ParentalSettings(showNames: false))
        }
    }

    private func write(_ json: String, to root: URL) throws {
        let directory = root.appending(path: "Settings")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: directory.appending(path: "parental.json"))
    }
}
