import Foundation
import Testing
@testable import ZilpZalpData

/// The fixed sentences — the ones that belong to no pack. The bundled set is
/// empty until Task 4 of the recorded-speech plan records it, so the
/// resolution itself is asserted against a fixture: a real, silent `.m4a`
/// nobody has to listen to.
@Suite("Fixed sentences")
struct SpeechCatalogTests {
    @Test("the bundled manifest is in the bundle and decodes")
    func decodesBundled() throws {
        let catalog = try SpeechCatalog.bundled()

        // Nothing is recorded yet, and even once something is, a key nobody
        // declared has to come back nil rather than as a URL that fails later.
        #expect(catalog.url(for: "no.such.sentence") == nil)
    }

    @Test("a declared line resolves to the file beside its manifest")
    func resolvesALine() throws {
        let catalog = try Self.fixture()

        let url = try #require(catalog.url(for: "roundEnd.title"))
        #expect(try sha256(of: url) == Self.silenceSHA256)
    }

    /// The branch the bundled set cannot reach on its own: a line the manifest
    /// declares whose file was never copied in. `nil`, so the caller falls back
    /// to the synthesiser instead of trying to play a file that is not there.
    @Test("a line whose file is missing comes back as nil")
    func returnsNilForAMissingFile() throws {
        let catalog = try Self.fixture()

        #expect(catalog.url(for: "gate.spoken") == nil)
    }

    @Test("the voice is decoded with the lines it licenses")
    func decodesTheVoice() throws {
        let data = try Data(contentsOf: Self.fixtureManifest())
        let manifest = try PackManifest.decode(SpeechManifest.self, from: data)

        #expect(manifest.voice?.license == .ccBy)
        #expect(manifest.voice?.attribution == "Stimme: Niemand")
        #expect(manifest.lines["roundEnd.title"]?.text == "Super gemacht!")
    }

    /// The Swift-side twin of the rule `tools/license_gate.py` enforces: a
    /// recording nobody is credited for must not ship. Vacuous while the set is
    /// empty, which is exactly the state it has to survive.
    @Test("the bundled set names a voice as soon as it has lines")
    func bundledSetCreditsItsVoice() throws {
        let manifest = try SpeechCatalog.bundled().manifest

        #expect(manifest.lines.isEmpty || manifest.voice != nil)
    }

    private static let silenceSHA256 = "ea4ca100e771dd55182921eac8665571baeb22644fd18dab1f4a7612b7acaff3"

    private static func fixtureManifest() throws -> URL {
        try #require(
            Bundle.module.url(
                forResource: "manifest",
                withExtension: "json",
                subdirectory: "Fixtures/speech",
            ),
            "no Fixtures/speech/manifest.json in the test bundle",
        )
    }

    private static func fixture() throws -> SpeechCatalog {
        let url = try fixtureManifest()
        return try SpeechCatalog(
            manifest: PackManifest.decode(SpeechManifest.self, from: Data(contentsOf: url)),
            directory: url.deletingLastPathComponent(),
        )
    }
}
