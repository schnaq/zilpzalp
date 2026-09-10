import Foundation
import Testing
@testable import ZilpZalpData

/// The TestFlight device the decision behind #192 was made on: it downloaded
/// „Vögel Deutschlands" while the pack was downloadable, and the app now
/// carries that very pack inside it. The downloaded copy must not become a
/// second pack of the same title — one more entry in the collection picker,
/// one more deletable row in the grown-ups' area — and its files are of no
/// use to anybody.
///
/// Its own suite, and one that touches nothing but the file system: reading
/// `Packs/` needs no bucket, so this runs beside the download tests instead of
/// inside their serialized suite.
@Suite("A downloaded copy of the bundled pack")
struct InstalledBundledPackTests {
    @Test("is ignored on load, and its files are removed")
    func isIgnoredAndItsFilesRemoved() async throws {
        let home = FileManager.default.temporaryDirectory
            .appending(path: "zilpzalp-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: home) }

        func seed(_ document: Data, at path: String) throws {
            let url = home.appending(path: path)
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true,
            )
            try document.write(to: url)
        }

        let bundled = "Packs/\(PackCatalog.bundledPackID)"
        try seed(
            StubPack.manifest(packID: PackCatalog.bundledPackID),
            at: "\(bundled)/manifest.json",
        )
        try seed(StubPack.media[0].bytes, at: "\(bundled)/\(StubPack.media[0].file)")
        // A download of the same pack that never finished, from the same device.
        try seed(Data(), at: bundled + ".partial/photos/half.png")
        // And a pack that really is a download and has to survive this.
        try seed(StubPack.manifest(), at: "Packs/\(StubPack.id)/manifest.json")

        let downloader = PackDownloader(baseURL: stubBaseURL, directory: home)
        let opened = await downloader.installations()

        #expect(opened.installed.map(\.id) == [StubPack.id])
        #expect(opened.failures.isEmpty)
        #expect(!exists(home, bundled))
        #expect(!exists(home, bundled + ".partial"))
        #expect(exists(home, "Packs/\(StubPack.id)/manifest.json"))
    }
}
