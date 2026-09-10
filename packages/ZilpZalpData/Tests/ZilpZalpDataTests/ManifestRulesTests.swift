import Foundation
import Testing
@testable import ZilpZalpData

/// The list a download walks, against the list `media_files()` in
/// `tools/fetch_media/manifest.py` builds for the bucket and for
/// `packs/index.json`. Both sides drop a file mentioned twice, and the Swift
/// side fixes the order a JSON object does not have — neither is visible in a
/// download test, where every stub file is named once.
@Suite("Declared files")
struct DeclaredFilesTests {
    /// A manifest with two sentence keys, one of which points at the other's
    /// file, so both properties are exercised at once.
    private static func pack(sharing: Bool) throws -> Pack {
        let shared = sharing ? "clips/silence.m4a" : "speech/collection.name/amsel.m4a"
        return try PackManifest.decode(Data("""
        {
          "id": "spricht",
          "title": "Ein Paket, das spricht",
          "voice": {
            "license": "CC-BY-4.0",
            "attribution": "Stimme: Niemand",
            "sourceURL": "https://example.org/docs/sprachaufnahmen.md",
            "retrieved": "2026-09-09"
          },
          "birds": [
            {
              "id": "amsel",
              "name": "Amsel",
              "scientificName": "Turdus merula",
              "taxonID": 12716,
              "article": "die",
              "pronunciation": null,
              "photo": {
                "file": "photos/amsel.png",
                "sha256": "\(String(repeating: "0", count: 64))",
                "license": "CC-BY-4.0",
                "attribution": "Nobody",
                "sourceURL": "https://example.org/observations/1",
                "retrieved": "2026-09-09"
              },
              "call": null,
              "speech": {
                "quiz.prompt.whereIs": {
                  "file": "clips/silence.m4a",
                  "sha256": "\(String(repeating: "1", count: 64))",
                  "text": "Wo ist die Amsel?"
                },
                "collection.name": {
                  "file": "\(shared)",
                  "sha256": "\(String(repeating: "1", count: 64))",
                  "text": "Amsel"
                }
              }
            }
          ]
        }
        """.utf8))
    }

    @Test("a species lists its photo, then its clips in sentence-key order")
    func ordersTheClipsBySentenceKey() throws {
        let bird = try #require(Self.pack(sharing: false).birds.first)

        #expect(bird.declaredFiles.map(\.file) == [
            "photos/amsel.png",
            // "collection.name" sorts before "quiz.prompt.whereIs"; the
            // dictionary the manifest decodes into has no order of its own.
            "speech/collection.name/amsel.m4a",
            "clips/silence.m4a",
        ])
    }

    @Test("a recording two sentences share is declared once")
    func dropsAFileMentionedTwice() throws {
        let pack = try Self.pack(sharing: true)

        // The bird still names it under both keys — the pack does not, because
        // the bucket holds it once and the index sizes it once.
        #expect(pack.birds.first?.declaredFiles.count == 3)
        #expect(pack.declaredFiles.map(\.file) == ["photos/amsel.png", "clips/silence.m4a"])
    }
}

/// The rules a manifest has to keep, whichever way it reached the device.
///
/// Reads a manifest and nothing else, so it never touches the stand-in
/// bucket's static state and may run beside the suite that does.
@Suite("Manifest rules")
struct ManifestRulesTests {
    /// A photo and a call carry their licence in their own fields and cannot
    /// decode without one. A clip's licence is the manifest's voice, so a pack
    /// that has recordings and names no voice would install media nobody may
    /// be credited for. `tools/license_gate.py` refuses that at curation time;
    /// this is the same rule where a downloaded manifest is read.
    @Test("a pack with recordings but no voice is refused")
    func refusesRecordingsNobodyMayBeCreditedFor() async throws {
        let home = FileManager.default.temporaryDirectory
            .appending(path: "zilpzalp-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: home) }

        let directory = home.appending(path: "Packs/\(StubPack.id)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try StubPack.manifest(voiced: false).write(to: directory.appending(path: "manifest.json"))

        let downloader = PackDownloader(baseURL: stubBaseURL, directory: home)

        // Reported rather than thrown: one unusable pack must not take the
        // packs beside it — or the app — down with it.
        let installed = await downloader.installations()
        #expect(installed.installed.isEmpty)
        #expect(installed.failures == [PackDownloadError.manifestInvalid(
            packID: StubPack.id,
            reason: "the pack has recorded sentences but names no voice",
        )])
    }
}
