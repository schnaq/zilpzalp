import Foundation
import Testing
@testable import ZilpZalpData

/// iCloud key-value storage as a dictionary: what two stores sharing one of
/// these see is what two devices on one Apple ID see, minus the waiting.
final class FakeCloud: CloudKeyValueStore, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func data(forKey key: String) -> Data? {
        lock.withLock { values[key] }
    }

    func set(_ data: Data?, forKey key: String) {
        lock.withLock { values[key] = data }
    }

    func removeObject(forKey key: String) {
        set(nil, forKey: key)
    }

    var dictionaryRepresentation: [String: Any] {
        lock.withLock { values }
    }
}

/// Two directories and one cloud: two devices of one family.
private func withTwoDevices(
    _ body: (_ first: URL, _ second: URL, _ cloud: FakeCloud) async throws -> Void,
) async throws {
    try await withTemporaryDirectory { first in
        try await withTemporaryDirectory { second in
            try await body(first, second, FakeCloud())
        }
    }
}

private let mila = UUID(uuidString: "0F3B6C6E-2E0B-4C7B-9C1E-2A4F7D8E9B01")!

@Suite("Profile merge")
struct ProfileMergeTests {
    @Test("counters take the larger side, the album the union of both")
    func mergesGrowingFields() {
        let here = Profile(
            id: mila, name: "Mila", avatar: "amsel",
            totalStars: 10, roundsPlayed: 4,
            recognitions: ["amsel": 5, "star": 1],
            playtime: ["2026-10-21": 60], dailyStars: ["2026-10-21": 3],
        )
        let there = Profile(
            id: mila, name: "Mila", avatar: "amsel",
            totalStars: 7, roundsPlayed: 6,
            recognitions: ["amsel": 2, "star": 4, "kohlmeise": 5],
            playtime: ["2026-10-21": 30, "2026-10-22": 90], dailyStars: ["2026-10-22": 2],
        )

        let merged = here.merged(with: there)

        #expect(merged.totalStars == 10)
        #expect(merged.roundsPlayed == 6)
        #expect(merged.recognitions == ["amsel": 5, "star": 4, "kohlmeise": 5])
        #expect(merged.playtime == ["2026-10-21": 60, "2026-10-22": 90])
        #expect(merged.dailyStars == ["2026-10-21": 3, "2026-10-22": 2])
        #expect(merged.stickers == ["amsel", "kohlmeise"])
    }

    @Test("a sticker earned at a lower threshold survives a merge with a higher one")
    func keepsEveryStickerEver() {
        let three = Profile(
            id: mila, name: "Mila", avatar: "amsel",
            recognitions: ["amsel": 3], stickerThreshold: 3,
            modifiedAt: Date(timeIntervalSince1970: 1),
        )
        let five = Profile(
            id: mila, name: "Mila", avatar: "amsel",
            recognitions: ["amsel": 3], stickerThreshold: 5,
            modifiedAt: Date(timeIntervalSince1970: 2),
        )

        let merged = three.merged(with: five)

        #expect(merged.stickerThreshold == 5)
        #expect(merged.stickers == ["amsel"])
    }

    @Test("what was chosen comes from the copy changed last, either way round")
    func choicesFromTheNewerCopy() {
        let older = Profile(
            id: mila, name: "Mila", avatar: "amsel", collections: ["afrika"],
            createdAt: Date(timeIntervalSince1970: 5), modifiedAt: Date(timeIntervalSince1970: 10),
        )
        let newer = Profile(
            id: mila, name: "Milla", avatar: "star", collections: [],
            createdAt: Date(timeIntervalSince1970: 7), modifiedAt: Date(timeIntervalSince1970: 20),
        )

        for merged in [older.merged(with: newer), newer.merged(with: older)] {
            #expect(merged.name == "Milla")
            #expect(merged.avatar == "star")
            #expect(merged.collections == [])
            #expect(merged.modifiedAt == Date(timeIntervalSince1970: 20))
            #expect(merged.createdAt == Date(timeIntervalSince1970: 5))
        }
    }

    @Test("a deleted profile stays deleted, until its id is ninety days old")
    func tombstones() {
        let now = Date(timeIntervalSince1970: 100 * 86400)
        let profile = Profile(id: mila, name: "Mila", avatar: "amsel")
        let deleted = ProfileStore
            .Contents(deleted: [mila.uuidString: now.addingTimeInterval(-86400)])

        let fresh = ProfileStore.merged(
            deleted,
            ProfileStore.Contents(profiles: [profile]),
            now: now,
        )
        #expect(fresh.profiles.isEmpty)
        #expect(fresh.deleted.keys.contains(mila.uuidString))

        let later = now.addingTimeInterval(91 * 86400)
        let stale = ProfileStore.merged(deleted, ProfileStore.Contents(), now: later)
        #expect(stale.deleted.isEmpty)
    }

    @Test("profiles stand in creation order, ties in the local order first")
    func order() {
        let old1 = Profile(id: UUID(), name: "A", avatar: "amsel")
        let old2 = Profile(id: UUID(), name: "B", avatar: "amsel")
        let early = Profile(
            id: UUID(),
            name: "C",
            avatar: "amsel",
            createdAt: Date(timeIntervalSince1970: 1),
        )
        let late = Profile(
            id: UUID(),
            name: "D",
            avatar: "amsel",
            createdAt: Date(timeIntervalSince1970: 2),
        )

        let merged = ProfileStore.merged(
            ProfileStore.Contents(profiles: [late, old1]),
            ProfileStore.Contents(profiles: [early, old2]),
            now: Date(timeIntervalSince1970: 3),
        )

        #expect(merged.profiles.map(\.name) == ["A", "B", "C", "D"])
    }
}

@Suite("iCloud sync")
struct CloudSyncTests {
    @Test("a round played on one device is on the other after a sync")
    func roundReachesTheOtherDevice() async throws {
        try await withTwoDevices { first, second, cloud in
            let ipad = ProfileStore(directory: first, cloud: cloud)
            let mia = try await ipad.add(name: "Mia", avatar: "amsel")
            let round = PlayedRound(stars: 3, recognitions: ["amsel": 5], playtime: 60)
            try await ipad.record(
                round: round,
                for: mia.id,
                on: noon(2026, 10, 22),
                calendar: testCalendar,
            )

            let iphone = ProfileStore(directory: second, cloud: cloud)
            let synced = try await iphone.sync()

            #expect(synced.map(\.name) == ["Mia"])
            #expect(synced.first?.totalStars == 3)
            #expect(synced.first?.stickers == ["amsel"])
            // Written to the file too, not only handed back.
            #expect(try await iphone.profiles() == synced)
        }
    }

    @Test("a reinstall finds every profile from before iCloud, in the order it had")
    func reinstallKeepsOrder() async throws {
        try await withTwoDevices { first, second, cloud in
            try seedProfileFile(profileFixture("v1"), in: first)
            let before = try await ProfileStore(directory: first, cloud: cloud).sync()
            #expect(before.map(\.name) == ["Mila", "Jonte"])

            let reinstalled = try await ProfileStore(directory: second, cloud: cloud).sync()

            #expect(reinstalled.map(\.name) == ["Mila", "Jonte"])
            #expect(reinstalled.map(\.totalStars) == before.map(\.totalStars))
        }
    }

    @Test("a profile deleted on one device does not come back from the other")
    func deletionWins() async throws {
        try await withTwoDevices { first, second, cloud in
            let ipad = ProfileStore(directory: first, cloud: cloud)
            let iphone = ProfileStore(directory: second, cloud: cloud)
            let mia = try await ipad.add(name: "Mia", avatar: "amsel")
            _ = try await iphone.sync()

            try await ipad.delete(mia.id)
            // The phone writes its stale copy back before it hears of it.
            let stale = try #require(await iphone.profiles().first)
            try await iphone.update(stale)
            _ = try await ipad.sync()

            #expect(try await iphone.profiles().isEmpty)
            #expect(try await ipad.profiles().isEmpty)
            #expect(cloud.data(forKey: "profile.\(mia.id.uuidString)") == nil)
        }
    }

    @Test("a file this build cannot read is never overwritten from the cloud")
    func unreadableFileStays() async throws {
        try await withTwoDevices { first, second, cloud in
            try await ProfileStore(directory: first, cloud: cloud).add(name: "Mia", avatar: "amsel")
            let newer = Data(#"{"schemaVersion": 2, "profiles": []}"#.utf8)
            try seedProfileFile(newer, in: second)

            await #expect(throws: ProfileStoreError.unsupportedSchemaVersion(2)) {
                try await ProfileStore(directory: second, cloud: cloud).sync()
            }
            #expect(try Data(contentsOf: profileFileURL(in: second)) == newer)
        }
    }

    @Test("a value over the quota is not mirrored, and nothing else suffers")
    func quota() {
        let cloud = FakeCloud()
        cloud.mirror(Data(count: 1_000_001), forKey: "big")
        cloud.mirror(Data(count: 10), forKey: "small")

        #expect(cloud.data(forKey: "big") == nil)
        #expect(cloud.data(forKey: "small")?.count == 10)
    }

    @Test("the settings saved last win, on whichever device")
    func settingsLastWriterWins() async throws {
        try await withTwoDevices { first, second, cloud in
            let ipad = ParentalSettingsStore(directory: first, cloud: cloud)
            let iphone = ParentalSettingsStore(directory: second, cloud: cloud)
            try await iphone.save(
                ParentalSettings(dailyLimitMinutes: 15),
                now: Date(timeIntervalSince1970: 1),
            )
            try await ipad.save(
                ParentalSettings(dailyLimitMinutes: 30),
                now: Date(timeIntervalSince1970: 2),
            )

            #expect(try await iphone.sync().dailyLimitMinutes == 30)
            #expect(try await iphone.load().dailyLimitMinutes == 30)
            #expect(try await ipad.sync().dailyLimitMinutes == 30)
        }
    }

    @Test("an older cloud copy does not undo a newer local one")
    func settingsOlderCloudLoses() async throws {
        try await withTwoDevices { first, second, cloud in
            let ipad = ParentalSettingsStore(directory: first, cloud: cloud)
            try await ipad.save(
                ParentalSettings(dailyLimitMinutes: 30),
                now: Date(timeIntervalSince1970: 1),
            )
            // Saved on a phone that was offline, without a cloud of its own.
            try await ParentalSettingsStore(directory: second)
                .save(ParentalSettings(dailyLimitMinutes: 60), now: Date(timeIntervalSince1970: 2))

            let phone = ParentalSettingsStore(directory: second, cloud: cloud)
            #expect(try await phone.sync().dailyLimitMinutes == 60)
            #expect(try await ipad.sync().dailyLimitMinutes == 60)
        }
    }
}
