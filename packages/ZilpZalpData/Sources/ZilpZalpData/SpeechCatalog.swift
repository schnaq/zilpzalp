import Foundation

/// What can go wrong while opening the fixed sentences.
public enum SpeechCatalogError: Error, Sendable {
    /// `Speech/manifest.json` is not in `Bundle.module`. Either the resource
    /// declaration in `Package.swift` is gone, or the bundled copy under
    /// `Resources/Speech` was never synced — `mise run check` catches the
    /// second case through `tools/sync_bundled_packs.py`.
    case bundledManifestMissing
}

/// The manifest of the sentences that belong to no pack.
///
/// A pack's manifest with `lines` where the birds would be. It lives outside
/// `data/packs/` for exactly that reason: the licence gate reads that
/// directory as packs, and a document without birds has to fail there.
struct SpeechManifest: Codable, Sendable, Hashable {
    let id: String
    /// Product text — what the credits call this set in front of a parent.
    let title: String
    /// Who spoke the lines. `nil` while there are none.
    let voice: Voice?
    /// String Catalog key → clip. Empty until the sentences have been recorded.
    let lines: [String: MediaClip]
}

/// The sentences that belong to no species: "Super gemacht!", the rank
/// ascents, the two profile questions, the parental-gate hint.
///
/// They are recorded once and shipped inside the app rather than per pack —
/// a child hears them in every round, whichever pack is installed. The twin of
/// ``PackCatalog`` for everything that has no bird.
public struct SpeechCatalog: Sendable {
    /// The directory inside `Bundle.module` that `tools/sync_bundled_packs.py`
    /// keeps in step with `data/speech/`.
    private static let bundledDirectory = "Speech"

    /// Internal rather than public: nothing outside this package reads a
    /// line's licence — the credits are generated — but the tests check that
    /// what ships names its voice.
    let manifest: SpeechManifest

    /// Where the manifest lies. Clip paths are relative to it, the same rule
    /// a pack follows.
    private let directory: URL

    /// Internal on purpose, as ``PackCatalog``'s is: the fixed sentences lie
    /// in the bundle and nowhere else, so ``bundled()`` is the only way in.
    init(manifest: SpeechManifest, directory: URL) {
        self.manifest = manifest
        self.directory = directory
    }

    /// Opens the fixed sentences that ship inside the app.
    ///
    /// - Returns: the bundled catalog, which declares no line at all until the
    ///   sentences have been recorded.
    /// - Throws: `SpeechCatalogError.bundledManifestMissing` when the manifest
    ///   is not in the bundle, or a `DecodingError`.
    public static func bundled() throws -> SpeechCatalog {
        guard
            let manifest = Bundle.module.url(
                forResource: "manifest",
                withExtension: "json",
                subdirectory: bundledDirectory,
            )
        else {
            throw SpeechCatalogError.bundledManifestMissing
        }

        return try SpeechCatalog(
            manifest: PackManifest.decode(SpeechManifest.self, from: Data(contentsOf: manifest)),
            directory: manifest.deletingLastPathComponent(),
        )
    }

    /// The recording of `sentence` on disk, `nil` when none is declared or the
    /// file is not there. The caller then speaks the sentence with
    /// `AVSpeechSynthesizer` (#151) rather than saying nothing.
    public func url(for sentence: String) -> URL? {
        guard let clip = manifest.lines[sentence] else { return nil }

        let file = directory.appending(path: clip.file)
        guard FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else {
            return nil
        }
        return file
    }
}
