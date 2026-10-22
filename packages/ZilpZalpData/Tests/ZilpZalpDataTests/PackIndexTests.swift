import Foundation
import Testing
@testable import ZilpZalpData

/// `packs/index.json` as `tools/fetch_media/index.py` writes it, before and
/// after #262.
@Suite("Pack index")
struct PackIndexTests {
    private static func decode(_ json: String) throws -> PackIndex {
        try JSONDecoder().decode(PackIndex.self, from: Data(json.utf8))
    }

    private static func entry(_ id: String) -> PackIndex.Entry {
        PackIndex.Entry(
            id: id,
            title: id,
            speciesCount: 10,
            downloadSize: 1,
            manifest: "packs/\(id)/manifest.json",
        )
    }

    @Test("an index from before the gallery still decodes, with nothing extra")
    func decodesTheOldIndex() throws {
        let index = try Self.decode("""
        {"packs": [{"id": "afrika", "title": "Vögel Afrikas", "speciesCount": 30,
                    "downloadSize": 17500000, "manifest": "packs/afrika/manifest.json"}]}
        """)

        let afrika = try #require(index.packs.first)
        #expect(afrika.manifestSha256 == nil)
        #expect(afrika.covers.isEmpty)
        #expect(afrika.species.isEmpty)
        #expect(index.retired.isEmpty)
    }

    @Test("covers, previews, the digest and the retired packs decode")
    func decodesTheGalleryIndex() throws {
        let index = try Self.decode("""
        {"packs": [{"id": "afrika", "title": "Vögel Afrikas", "speciesCount": 1,
                    "downloadSize": 1, "manifest": "packs/afrika/manifest.json",
                    "manifestSha256": "abc", "covers": ["strauss"],
                    "species": [{"id": "strauss", "name": "Strauß",
                                 "preview": "packs/afrika/previews/strauss.jpg",
                                 "attribution": "Jane", "license": "CC-BY-4.0"}],
                    "somethingLater": true}],
         "retired": [{"id": "welt", "successors": ["afrika"]}]}
        """)

        let afrika = try #require(index.packs.first)
        #expect(afrika.manifestSha256 == "abc")
        #expect(afrika.covers == ["strauss"])
        #expect(afrika.species.first?.preview == "packs/afrika/previews/strauss.jpg")
        #expect(afrika.species.first?.license == "CC-BY-4.0")
        #expect(index.retired == [PackIndex.Retired(id: "welt", successors: ["afrika"])])
    }

    @Test("an installed retired pack is offered the successors not yet there")
    func offersTheMissingSuccessors() {
        let index = PackIndex(
            packs: [Self.entry("amerika"), Self.entry("asien"), Self.entry("afrika")],
            retired: [PackIndex.Retired(id: "welt", successors: ["amerika", "asien"])],
        )

        let migrations = index.migrations(installed: ["welt", "asien"])

        #expect(migrations.map(\.retired) == ["welt"])
        #expect(migrations.first?.remaining.map(\.id) == ["amerika"])
    }

    @Test("with every successor installed, nothing is left to load")
    func isDoneOnceEverySuccessorIsThere() {
        let index = PackIndex(
            packs: [Self.entry("amerika")],
            retired: [PackIndex.Retired(id: "welt", successors: ["amerika"])],
        )

        #expect(index.migrations(installed: ["welt", "amerika"]).first?.remaining == [])
    }

    @Test("a retired pack whose successors are not all published yet is left alone")
    func waitsForEverySuccessor() {
        let index = PackIndex(
            packs: [Self.entry("amerika")],
            retired: [PackIndex.Retired(id: "welt", successors: ["amerika", "asien"])],
        )

        // With amerika installed, nothing would remain — and welt would go
        // while asien's birds are nowhere yet.
        #expect(index.migrations(installed: ["welt", "amerika"]).isEmpty)
    }

    @Test("a retired pack that is not installed, or has no successor yet, is left alone")
    func leavesTheRestAlone() {
        let index = PackIndex(
            packs: [Self.entry("amerika")],
            retired: [
                PackIndex.Retired(id: "welt", successors: ["amerika"]),
                PackIndex.Retired(id: "alt", successors: ["nirgends"]),
            ],
        )

        #expect(index.migrations(installed: ["amerika"]).isEmpty)
        #expect(index.migrations(installed: ["alt"]).isEmpty)
    }

    // MARK: - The grown-ups' dot (#334)

    /// A downloaded pack whose manifest has the digest `sha256`.
    private static func installed(_ id: String, sha256: String) throws -> PackInstallation {
        let pack = try JSONDecoder().decode(
            Pack.self,
            from: Data(#"{"id": "\#(id)", "title": "\#(id)", "birds": []}"#.utf8),
        )
        return PackInstallation(
            catalog: PackCatalog(pack: pack, directory: URL(filePath: "/nowhere")),
            bytes: 0,
            manifestSha256: sha256,
        )
    }

    private static func entry(_ id: String, sha256: String) -> PackIndex.Entry {
        var entry = entry(id)
        entry.manifestSha256 = sha256
        return entry
    }

    @Test("a pack not seen yet wears the dot until the gallery has shown it")
    func flagsANewPack() {
        let index = PackIndex(packs: [Self.entry("afrika"), Self.entry("asien")])

        #expect(index.hasNews(installed: [], seen: ["afrika"]))
        #expect(!index.hasNews(installed: [], seen: ["afrika", "asien"]))
    }

    @Test("an outdated pack wears the dot until it is updated, seen or not")
    func flagsAnOutdatedPack() throws {
        let index = PackIndex(packs: [Self.entry("afrika", sha256: "neu")])

        #expect(try index.hasNews(
            installed: [Self.installed("afrika", sha256: "alt")],
            seen: ["afrika"],
        ))
        #expect(try !index.hasNews(installed: [Self.installed("afrika", sha256: "neu")], seen: []))
    }

    @Test("nothing new and nothing outdated is no dot")
    func staysQuiet() throws {
        // An index from before #262 names no digest, so nothing is outdated;
        // and an installed pack counts as seen.
        let index = PackIndex(packs: [Self.entry("afrika")])

        #expect(try !index.hasNews(installed: [Self.installed("afrika", sha256: "alt")], seen: []))
        #expect(!PackIndex(packs: []).hasNews(installed: [], seen: []))
    }
}
