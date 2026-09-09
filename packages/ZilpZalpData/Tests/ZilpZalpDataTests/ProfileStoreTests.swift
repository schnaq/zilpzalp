import Foundation
import Testing
import ZilpZalpData

@Suite("Profile store")
struct ProfileStoreTests {
    // MARK: - Reading an empty store

    @Test("a directory without a file holds no profiles, and reading creates nothing")
    func readsMissingFileAsEmpty() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)

            let profiles = try await store.profiles()

            #expect(profiles.isEmpty)
            #expect(!FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)))
        }
    }

    // MARK: - Adding, updating, deleting

    @Test("added profiles come back in creation order, empty of progress")
    func addsProfiles() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)

            let mila = try await store.add(name: "Mila", avatar: "feather")
            try await store.add(name: "Jonte", avatar: "egg")

            #expect(mila.totalStars == 0)
            #expect(mila.roundsPlayed == 0)
            #expect(mila.recognitions.isEmpty)
            #expect(mila.playtime.isEmpty)

            let profiles = try await store.profiles()
            #expect(profiles.map(\.name) == ["Mila", "Jonte"])
            #expect(profiles.map(\.avatar) == ["feather", "egg"])
            #expect(Set(profiles.map(\.id)).count == 2)
        }
    }

    @Test("a profile survives a write and a new store instance unchanged")
    func roundTripsThroughTheFile() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)
            var mila = try await store.add(name: "Mila", avatar: "feather")
            mila.totalStars = 63
            mila.roundsPlayed = 24
            mila.recognitions = ["zilpzalp": 5, "amsel": 2]
            mila.playtime = ["2026-09-08": 185.5]
            try await store.update(mila)

            let reopened = try await ProfileStore(directory: directory).profiles()

            #expect(reopened == [mila])
        }
    }

    @Test("updating replaces the profile with that id")
    func updatesProfile() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)
            try await store.add(name: "Jonte", avatar: "egg")
            var mila = try await store.add(name: "Mila", avatar: "feather")

            mila.name = "Mila Rosa"
            mila.avatar = "star"
            try await store.update(mila)

            let profiles = try await store.profiles()
            #expect(profiles.map(\.name) == ["Jonte", "Mila Rosa"])
            #expect(profiles.last?.avatar == "star")
        }
    }

    @Test("updating a profile that is not in the file is an error")
    func rejectsUnknownUpdate() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)
            let stranger = Profile(id: UUID(), name: "Niemand", avatar: "bird")

            await #expect(throws: ProfileStoreError.unknownProfile(stranger.id)) {
                try await store.update(stranger)
            }
        }
    }

    @Test("deleting removes only that profile")
    func deletesProfile() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)
            let mila = try await store.add(name: "Mila", avatar: "feather")
            try await store.add(name: "Jonte", avatar: "egg")

            try await store.delete(mila.id)

            let profiles = try await store.profiles()
            #expect(profiles.map(\.name) == ["Jonte"])
        }
    }

    @Test("deleting the last profile leaves a file that still reads")
    func deletesLastProfile() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)
            let mila = try await store.add(name: "Mila", avatar: "feather")

            try await store.delete(mila.id)

            #expect(try await ProfileStore(directory: directory).profiles().isEmpty)
            #expect(try profileFileText(in: directory).hasPrefix("{\n  \"schemaVersion\" : 1,"))
        }
    }

    @Test("deleting a profile that is not in the file is an error")
    func rejectsUnknownDelete() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)
            let id = UUID()

            await #expect(throws: ProfileStoreError.unknownProfile(id)) {
                try await store.delete(id)
            }
        }
    }

    // MARK: - The file itself

    @Test("the file starts with its schema version and sorts what it holds")
    func writesReadableFile() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)
            var mila = try await store.add(name: "Mila", avatar: "feather")
            mila.recognitions = ["zilpzalp": 5, "amsel": 3, "kohlmeise": 1]
            mila.playtime = ["2026-09-08": 60, "2026-09-02": 30]
            try await store.update(mila)

            let text = try profileFileText(in: directory)

            let firstKey = try #require(text.split(separator: "\"").dropFirst().first)
            #expect(firstKey == "schemaVersion")
            #expect(text.hasPrefix("{\n  \"schemaVersion\" : 1,\n  \"profiles\" : ["))
            // A `Dictionary` iterates differently from run to run; written
            // sorted, the file's bytes only change when a value does.
            try #expect(position(of: "amsel", in: text) < position(of: "kohlmeise", in: text))
            try #expect(position(of: "kohlmeise", in: text) < position(of: "zilpzalp", in: text))
            try #expect(position(of: "2026-09-02", in: text) < position(of: "2026-09-08", in: text))
        }
    }

    @Test("an atomic write leaves nothing but the file behind")
    func leavesNoTemporaryFiles() async throws {
        try await withTemporaryDirectory { directory in
            let store = ProfileStore(directory: directory)
            let mila = try await store.add(name: "Mila", avatar: "feather")
            try await store.add(name: "Jonte", avatar: "egg")
            try await store.delete(mila.id)

            let written = try FileManager.default.contentsOfDirectory(
                atPath: directory.appending(path: "Profiles").path(percentEncoded: false),
            )

            #expect(written == ["profiles.json"])
        }
    }

    @Test("a file that is not JSON is reported, not swallowed and not overwritten")
    func reportsCorruptFile() async throws {
        try await withTemporaryDirectory { directory in
            let broken = Data("{ \"schemaVersion\": 1, \"profiles\": [ ".utf8)
            try seedProfileFile(broken, in: directory)
            let store = ProfileStore(directory: directory)

            let error = await #expect(throws: ProfileStoreError.self) {
                try await store.profiles()
            }

            guard case .corruptFile? = error else {
                Issue.record("expected a corruptFile error, got \(String(describing: error))")
                return
            }
            #expect(try Data(contentsOf: profileFileURL(in: directory)) == broken)
        }
    }

    @Test("a file that will not read is not written over either")
    func refusesToWriteOverCorruptFile() async throws {
        try await withTemporaryDirectory { directory in
            let broken = Data("{ \"schemaVersion\": 1, \"profiles\": [ ".utf8)
            try seedProfileFile(broken, in: directory)
            let store = ProfileStore(directory: directory)

            await #expect(throws: ProfileStoreError.self) {
                try await store.add(name: "Mila", avatar: "feather")
            }

            #expect(try Data(contentsOf: profileFileURL(in: directory)) == broken)
        }
    }

    // MARK: - Schema version

    @Test("a version 1 file decodes with everything it holds")
    func decodesVersionOneFixture() async throws {
        try await withTemporaryDirectory { directory in
            try seedProfileFile(profileFixture("v1"), in: directory)
            let store = ProfileStore(directory: directory)

            let profiles = try await store.profiles()

            #expect(profiles.map(\.name) == ["Mila", "Jonte"])
            let mila = try #require(profiles.first)
            #expect(mila.id == UUID(uuidString: "0F3B6C6E-2E0B-4C7B-9C1E-2A4F7D8E9B01"))
            #expect(mila.avatar == "feather")
            #expect(mila.totalStars == 63)
            #expect(mila.roundsPlayed == 24)
            // The fixture was written before #177, so its `collectedSpecies`
            // is ignored and nothing has been recognised yet.
            #expect(mila.recognitions.isEmpty)
            #expect(mila.playtime == ["2026-09-07": 420, "2026-09-08": 185.5])
            #expect(profiles.last?.playtime.isEmpty == true)
        }
    }

    @Test("a file from a newer build is refused rather than read half-way")
    func refusesNewerSchemaVersion() async throws {
        try await withTemporaryDirectory { directory in
            let newer = Data("{ \"schemaVersion\" : 2, \"nests\" : [] }".utf8)
            try seedProfileFile(newer, in: directory)
            let store = ProfileStore(directory: directory)

            await #expect(throws: ProfileStoreError.unsupportedSchemaVersion(2)) {
                try await store.profiles()
            }
        }
    }
}

/// Where `needle` stands in the written file, for the ordering checks.
private func position(of needle: String, in text: String) throws -> String.Index {
    try #require(text.range(of: needle), "'\(needle)' is not in the file").lowerBound
}
