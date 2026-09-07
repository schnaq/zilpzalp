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

            #expect(settings.callsEnabled)
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
            let saved = ParentalSettings(
                callsEnabled: false,
                showNames: false,
                dailyLimitMinutes: 30,
            )
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

    /// The version has to be readable before anything else is, so a later app
    /// version's file can be recognised as such. That only holds if it is
    /// written first.
    @Test("the version is the file's first key")
    func writesTheVersionFirst() async throws {
        try await withTemporaryStore { store, root in
            try await store.save(ParentalSettings())

            let written = try String(contentsOf: settingsFile(under: root), encoding: .utf8)
            let version = try #require(written.range(of: "\"schemaVersion\""))
            let firstSetting = try #require(written.range(of: "\"callsEnabled\""))
            #expect(version.lowerBound < firstSetting.lowerBound)
            #expect(written.contains("\"schemaVersion\" : 1"))
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
            try await store.save(ParentalSettings(callsEnabled: false, dailyLimitMinutes: 45))
            try await store.save(ParentalSettings(showNames: false))

            let settings = try await store.load()
            #expect(settings.callsEnabled)
            #expect(!settings.showNames)
            #expect(settings.dailyLimitMinutes == nil)
        }
    }

    @Test("a file that is not this document is refused, not guessed at")
    func refusesACorruptFile() async throws {
        try await withTemporaryStore { store, root in
            try write("{ \"schemaVersion\": 1, \"callsEnabled\":", to: root)

            await #expect(throws: ParentalSettingsStoreError.self) {
                try await store.load()
            }
        }
    }

    @Test("a file with the wrong types is refused")
    func refusesTheWrongTypes() async throws {
        try await withTemporaryStore { store, root in
            try write(
                #"{"schemaVersion": 1, "callsEnabled": "ja", "showNames": true}"#,
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
                #"{"schemaVersion": 2, "callsEnabled": false, "showNames": false}"#,
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
            try write(#"{"callsEnabled": true, "showNames": true}"#, to: root)

            await #expect(throws: ParentalSettingsStoreError.self) {
                try await store.load()
            }
        }
    }

    private func write(_ json: String, to root: URL) throws {
        let directory = root.appending(path: "Settings")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(json.utf8).write(to: directory.appending(path: "parental.json"))
    }
}
