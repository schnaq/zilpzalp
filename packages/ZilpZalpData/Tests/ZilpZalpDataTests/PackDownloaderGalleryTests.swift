import Foundation
import Testing
@testable import ZilpZalpData

/// What the pack gallery asks of the downloader (#262). An extension of the
/// serialized suite rather than a suite of its own: the stand-in bucket is
/// static, and two suites running at once would share it.
extension PackDownloaderTests {
    @Test("a preview comes from the one bucket, and a path out of it is refused")
    func fetchesAPreview() async throws {
        let key = "packs/\(StubPack.id)/previews/amsel.jpg"
        var routes = StubPack.routes()
        routes[key] = StubBucket.Route(body: Data("jpeg".utf8))

        try await withDownloader(routes: routes) { downloader, _ in
            let preview = try await downloader.preview(key)
            #expect(preview == Data("jpeg".utf8))
            await #expect(throws: PackDownloadError.invalidPath(packID: "", path: "../evil.jpg")) {
                try await downloader.preview("../evil.jpg")
            }
            #expect(StubBucket.requests.allSatisfy { $0.host() == "bucket.invalid" })
        }
    }

    @Test("an installed pack carries its manifest's digest, and knows a newer one")
    func comparesTheManifestDigest() async throws {
        let manifest = StubPack.manifest()
        try await withDownloader(routes: StubPack.routes(manifest: manifest)) { downloader, _ in
            try await downloader.download(StubPack.entry(manifest: manifest))
            let installed = try #require(await downloader.installations().installed.first)

            var same = StubPack.entry(manifest: manifest)
            same.manifestSha256 = StubPack.sha256(of: manifest)
            var newer = same
            newer.manifestSha256 = String(repeating: "0", count: 64)

            #expect(installed.manifestSha256 == StubPack.sha256(of: manifest))
            #expect(!installed.isOutdated(by: same))
            #expect(installed.isOutdated(by: newer))
            // An index from before #262 names no digest and offers no update.
            #expect(!installed.isOutdated(by: StubPack.entry(manifest: manifest)))
        }
    }

    @Test("a full device is told apart from every other disk failure")
    func recognisesAFullDevice() {
        let file = URL(filePath: "/tmp/x")
        #expect(PackDownloader.diskError(CocoaError(.fileWriteOutOfSpace), writing: file)
            == .outOfSpace(path: "/tmp/x"))
        #expect(PackDownloader.diskError(POSIXError(.ENOSPC), writing: file)
            == .outOfSpace(path: "/tmp/x"))
        #expect(PackDownloader.diskError(CocoaError(.fileWriteNoPermission), writing: file)
            != .outOfSpace(path: "/tmp/x"))
    }
}
