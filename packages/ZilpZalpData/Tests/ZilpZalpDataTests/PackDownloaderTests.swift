import Foundation
import Synchronization
import Testing
@testable import ZilpZalpData

/// The downloader against a stand-in bucket, never against the real one.
///
/// Serialized: `StubBucket` is addressed through the session's protocol
/// classes and therefore keeps its objects and its request log statically.
@Suite("Pack downloader", .serialized)
struct PackDownloaderTests {
    private static let installed = "Packs/\(StubPack.id)"
    private static let partial = "Packs/\(StubPack.id).partial"

    @Test("the index lists what the bucket offers")
    func decodesTheIndex() async throws {
        let manifest = StubPack.manifest()
        try await withDownloader(routes: StubPack.routes(manifest: manifest)) { downloader, _ in
            let entry = try #require(await downloader.availablePacks().first)

            #expect(entry.id == StubPack.id)
            #expect(entry.title == StubPack.title)
            #expect(entry.speciesCount == 2)
            #expect(entry.downloadSize == StubPack.downloadSize(of: manifest))
            #expect(entry.manifest == StubPack.manifestKey)
        }
    }

    @Test("an unreachable index is one error, whatever went wrong")
    func reportsAnUnreachableIndex() async throws {
        try await withDownloader(routes: [:]) { downloader, _ in
            await #expect(throws: PackDownloadError.indexUnreachable(reason: "HTTP 404")) {
                try await downloader.availablePacks()
            }
        }
    }

    /// The state every fresh install is in, and the first one the parents'
    /// area sees: `Packs/` does not exist at all.
    @Test("without a single download there is nothing installed and nothing to delete")
    func startsEmpty() async throws {
        try await withDownloader(routes: [:]) { downloader, _ in
            let installed = try await downloader.installedPacks()
            #expect(installed.isEmpty)

            try await downloader.delete(packID: StubPack.id)
        }
    }

    @Test("a download verifies every file and reports progress up to the total")
    func downloadsAndVerifies() async throws {
        let manifest = StubPack.manifest()
        try await withDownloader(routes: StubPack.routes(manifest: manifest)) { downloader, home in
            let reports = Mutex<[Int]>([])
            let entry = try #require(await downloader.availablePacks().first)

            try await downloader.download(entry) { done, total in
                #expect(total == entry.downloadSize)
                reports.withLock { $0.append(done) }
            }

            #expect(reports.withLock { $0.last } == entry.downloadSize)
            for medium in StubPack.media {
                let file = home.appending(path: "\(Self.installed)/\(medium.file)")
                let written = try Data(contentsOf: file)
                #expect(written == medium.bytes)
            }
            #expect(exists(home, Self.installed + "/manifest.json"))
            #expect(!exists(home, Self.partial))
            // The one host the app is allowed to talk to.
            #expect(StubBucket.requests.allSatisfy { $0.host() == "bucket.invalid" })
        }
    }

    @Test("a file that does not match its digest fails, naming the file")
    func rejectsAFileThatDoesNotMatch() async throws {
        let manifest = StubPack.manifest()
        let wrong = Data("ein anderer Vogel".utf8)
        var routes = StubPack.routes(manifest: manifest)
        routes[StubPack.key(for: StubPack.media[1].file)] = StubBucket.Route(body: wrong)

        try await withDownloader(routes: routes) { downloader, home in
            let expected = PackDownloadError.hashMismatch(
                packID: StubPack.id,
                file: StubPack.media[1].file,
                expected: StubPack.assets[1].sha256,
                actual: StubPack.sha256(of: wrong),
            )

            await #expect(throws: expected) {
                try await downloader.download(StubPack.entry(manifest: manifest))
            }

            let installed = try await downloader.installedPacks()
            #expect(installed.isEmpty)
            #expect(!exists(home, Self.installed))
            #expect(exists(home, Self.partial))
        }
    }

    @Test("a resumed download does not fetch what is already verified")
    func resumesWithoutFetchingAgain() async throws {
        let manifest = StubPack.manifest()
        let call = StubPack.key(for: StubPack.media[2].file)
        var routes = StubPack.routes(manifest: manifest)
        routes[call] = StubBucket.Route(body: Data(), status: 500)

        try await withDownloader(routes: routes) { downloader, _ in
            let entry = StubPack.entry(manifest: manifest)
            await #expect(throws: PackDownloadError.self) { try await downloader.download(entry) }

            StubBucket.serve(call, StubBucket.Route(body: StubPack.media[2].bytes))
            try await downloader.download(entry)

            #expect(StubBucket.requestCount(for: StubPack.key(for: StubPack.media[0].file)) == 1)
            #expect(StubBucket.requestCount(for: call) == 2)
            let installed = try await downloader.installedPacks()
            #expect(installed.map(\.id) == [StubPack.id])
        }
    }

    @Test("a cancelled download keeps its partial directory and installs nothing")
    func keepsThePartialDirectoryWhenCancelled() async throws {
        let manifest = StubPack.manifest()
        let photo = StubPack.key(for: StubPack.media[0].file)
        var routes = StubPack.routes(manifest: manifest)
        routes[photo] = StubBucket.Route(body: StubPack.media[0].bytes, delay: 5)

        try await withDownloader(routes: routes) { downloader, home in
            let entry = StubPack.entry(manifest: manifest)
            let download = Task { try await downloader.download(entry) }

            // Cancel once the held request has arrived: earlier the download
            // might not have started, later its answer is still seconds away.
            var waited = 0
            while StubBucket.requestCount(for: photo) == 0, waited < 200 {
                try await Task.sleep(for: .milliseconds(5))
                waited += 1
            }
            download.cancel()

            await #expect(throws: CancellationError.self) { try await download.value }
            #expect(exists(home, Self.partial))
            #expect(!exists(home, Self.installed))
            let installed = try await downloader.installedPacks()
            #expect(installed.isEmpty)
        }
    }

    /// The branch `publish` takes when the pack is already there — a
    /// `replaceItemAt` on a directory rather than a `moveItem` into an empty
    /// spot. Parents who load a pack again after it was re-curated take it.
    @Test("downloading a pack that is already installed replaces it")
    func replacesAnInstalledPack() async throws {
        let manifest = StubPack.manifest()
        try await withDownloader(routes: StubPack.routes(manifest: manifest)) { downloader, home in
            let entry = StubPack.entry(manifest: manifest)
            try await downloader.download(entry)
            try await downloader.download(entry)

            #expect(exists(home, Self.installed + "/manifest.json"))
            #expect(!exists(home, Self.partial))
            let installed = try await downloader.installedPacks()
            #expect(installed.map(\.id) == [StubPack.id])

            let photo = home.appending(path: "\(Self.installed)/\(StubPack.media[0].file)")
            let written = try Data(contentsOf: photo)
            #expect(written == StubPack.media[0].bytes)
        }
    }

    @Test("deleting a pack removes the installed and the half downloaded copy")
    func deletesBothDirectories() async throws {
        let manifest = StubPack.manifest()
        try await withDownloader(routes: StubPack.routes(manifest: manifest)) { downloader, home in
            try await downloader.download(StubPack.entry(manifest: manifest))
            // A later attempt that got as far as creating its directory.
            try FileManager.default.createDirectory(
                at: home.appending(path: Self.partial),
                withIntermediateDirectories: true,
            )

            try await downloader.delete(packID: StubPack.id)

            #expect(!exists(home, Self.installed))
            #expect(!exists(home, Self.partial))
            let installed = try await downloader.installedPacks()
            #expect(installed.isEmpty)
            // Deleting what is no longer there is done, not failed.
            try await downloader.delete(packID: StubPack.id)
        }
    }

    @Test("an installed pack opens and resolves its photos")
    func opensAnInstalledPack() async throws {
        let manifest = StubPack.manifest()
        try await withDownloader(routes: StubPack.routes(manifest: manifest)) { downloader, _ in
            try await downloader.download(StubPack.entry(manifest: manifest))

            let catalog = try await downloader.catalog(for: StubPack.id)
            let bird = try #require(catalog.pack.birds.first)
            let photo = try #require(catalog.photoURL(for: bird))
            let bytes = try Data(contentsOf: photo)

            #expect(catalog.pack.id == StubPack.id)
            #expect(bytes == StubPack.media[0].bytes)
        }
    }

    @Test("Packs is excluded from the iCloud backup")
    func excludesPacksFromTheBackup() async throws {
        let manifest = StubPack.manifest()
        try await withDownloader(routes: StubPack.routes(manifest: manifest)) { downloader, home in
            try await downloader.download(StubPack.entry(manifest: manifest))

            let values = try home
                .appending(path: "Packs")
                .resourceValues(forKeys: [.isExcludedFromBackupKey])

            #expect(values.isExcludedFromBackup == true)
        }
    }

    @Test("a manifest naming a path outside the pack is refused before it is fetched")
    func refusesAPathOutsideThePack() async throws {
        let escape = "../../escaped.png"
        let manifest = StubPack.manifest(
            amselPhoto: StubPack.Asset(file: escape, sha256: StubPack.assets[0].sha256),
        )

        try await withDownloader(routes: StubPack.routes(manifest: manifest)) { downloader, home in
            let expected = PackDownloadError.invalidPath(packID: StubPack.id, path: escape)

            await #expect(throws: expected) {
                try await downloader.download(StubPack.entry(manifest: manifest))
            }

            // The manifest, and nothing after it.
            #expect(StubBucket.requests.count == 1)
            #expect(!exists(home, "escaped.png"))
            #expect(!exists(home, "Packs/escaped.png"))
        }
    }

    /// `URLSession` follows redirects by default, so without a delegate that
    /// refuses them a `302` from the bucket would send the next request to
    /// whatever host it names — and the app is allowed exactly one.
    @Test("a redirect to another host is not followed")
    func doesNotFollowARedirect() async throws {
        let elsewhere = try #require(URL(string: "https://elsewhere.invalid/stolen"))
        var routes = StubPack.routes()
        routes[StubPack.indexKey] = StubBucket.Route(
            body: Data(),
            status: 302,
            redirectTo: elsewhere,
        )

        try await withDownloader(routes: routes) { downloader, _ in
            await #expect(throws: PackDownloadError.indexUnreachable(reason: "HTTP 302")) {
                try await downloader.availablePacks()
            }

            #expect(StubBucket.requests.allSatisfy { $0.host() == "bucket.invalid" })
        }
    }

    @Test("an index entry whose id is a path is refused")
    func refusesAPackIDThatIsAPath() async throws {
        try await withDownloader(routes: StubPack.routes()) { downloader, _ in
            let entry = StubPack.entry(id: "../evil")

            await #expect(throws: PackDownloadError.invalidPath(
                packID: "../evil",
                path: "../evil",
            )) {
                try await downloader.download(entry)
            }

            #expect(StubBucket.requests.isEmpty)
        }
    }

    /// The id is the directory name in the bucket and on disk, so a manifest
    /// that disagrees with the index would install a pack under a name
    /// nothing else uses.
    @Test("a manifest that calls the pack something else is refused")
    func refusesAManifestWithAnotherID() async throws {
        let manifest = StubPack.manifest(packID: "woanders")

        try await withDownloader(routes: StubPack.routes(manifest: manifest)) { downloader, home in
            let expected = PackDownloadError.manifestInvalid(
                packID: StubPack.id,
                reason: "the manifest calls the pack 'woanders'",
            )

            await #expect(throws: expected) {
                try await downloader.download(StubPack.entry(manifest: manifest))
            }

            #expect(!exists(home, Self.installed))
        }
    }

    @Test("a manifest that is not a manifest names the pack it came from")
    func reportsAnInvalidManifest() async throws {
        var routes = StubPack.routes()
        routes[StubPack.manifestKey] = StubBucket.Route(body: Data("nicht mal JSON".utf8))

        try await withDownloader(routes: routes) { downloader, home in
            await #expect(throws: PackDownloadError.self) {
                try await downloader.download(StubPack.entry())
            }

            #expect(!exists(home, Self.installed))
        }
    }
}
