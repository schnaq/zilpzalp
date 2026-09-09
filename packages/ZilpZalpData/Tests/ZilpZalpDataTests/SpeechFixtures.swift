import Foundation
import Testing

// @testable for the internal initialisers: a fixture lies neither in
// `Bundle.module` nor in Application Support, which are the two places the
// public entry points know.
@testable import ZilpZalpData

/// The two speaking manifests under `Fixtures/speech`, opened the way the app
/// opens the real ones — a pack beside its clips, and the fixed set beside its
/// own.
///
/// Shared rather than private to one suite because three ask for them: the
/// pack catalog, the fixed sentences, and the choice between them.
enum SpeechFixtures {
    /// A pack that speaks: `amsel` carries one clip that resolves and one that
    /// is declared but not on disk, `stumm` carries none at all.
    static func speakingPack() throws -> PackCatalog {
        let url = try document("pack")
        return try PackCatalog(
            pack: PackManifest.decode(Data(contentsOf: url)),
            directory: url.deletingLastPathComponent(),
        )
    }

    /// The fixed set with one line that resolves and three that cannot.
    static func fixedSet() throws -> SpeechCatalog {
        let url = try fixedManifest()
        return try SpeechCatalog(
            manifest: PackManifest.decode(SpeechManifest.self, from: Data(contentsOf: url)),
            directory: url.deletingLastPathComponent(),
        )
    }

    /// Where ``fixedSet()`` is read from, for the suites that decode the
    /// document itself rather than ask it for a file.
    static func fixedManifest() throws -> URL {
        try document("manifest")
    }

    /// One of the two documents, beside the clips they name.
    private static func document(_ name: String) throws -> URL {
        try #require(
            Bundle.module.url(
                forResource: name,
                withExtension: "json",
                subdirectory: "Fixtures/speech",
            ),
            "no Fixtures/speech/\(name).json in the test bundle",
        )
    }
}
