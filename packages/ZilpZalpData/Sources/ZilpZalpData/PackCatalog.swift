import Foundation

/// What can go wrong while opening a pack.
public enum PackCatalogError: Error, Sendable {
    /// The bundled pack's manifest is not in `Bundle.module`. Either the
    /// resource declaration in `Package.swift` is gone, or the bundled copy
    /// under `Resources/Packs` was never synced — `mise run check` catches
    /// the second case through `tools/sync_bundled_packs.py`.
    case bundledManifestMissing(packID: String)
}

/// A pack that has been opened, together with the directory its media sit in.
///
/// The bundled base pack is a resource of this package rather than an asset
/// catalog in the app target, so it loads through `Bundle.module` and
/// `swift test` can exercise it without a simulator.
public struct PackCatalog: Sendable {
    /// The identifier — and directory name — of the pack that ships with the app.
    ///
    /// Read by ``PackDownloader/installations()`` too: the pack was
    /// downloadable before it began shipping inside the app (#192), so a
    /// device may still hold an installation under this id.
    static let bundledPackID = "deutschland"

    public let pack: Pack

    /// Where the pack's manifest lives. Media paths are relative to it, which
    /// is the same rule `tools/license_gate.py` applies.
    private let directory: URL

    /// Opens a pack that lies in `directory`, next to its own manifest.
    ///
    /// Internal on purpose, and spelled out rather than left to the memberwise
    /// initialiser, which `directory` being private makes unusable: the two
    /// places a pack can lie are the bundle and `Packs/` in Application
    /// Support, and `PackCatalog.bundled()` and
    /// `PackDownloader.installations()` own those. Nobody else assembles a
    /// pack's path.
    init(pack: Pack, directory: URL) {
        self.pack = pack
        self.directory = directory
    }

    /// Opens the pack that ships inside the app.
    ///
    /// - Returns: the bundled catalog.
    /// - Throws: `PackCatalogError.bundledManifestMissing` when the manifest
    ///   is not in the bundle, or a `DecodingError` from `PackManifest`.
    public static func bundled() throws -> PackCatalog {
        guard
            let manifest = Bundle.module.url(
                forResource: "manifest",
                withExtension: "json",
                subdirectory: "Packs/\(bundledPackID)",
            )
        else {
            throw PackCatalogError.bundledManifestMissing(packID: bundledPackID)
        }

        return try PackCatalog(
            pack: PackManifest.decode(Data(contentsOf: manifest)),
            directory: manifest.deletingLastPathComponent(),
        )
    }

    /// One photo file of `bird` on disk, `nil` when it is not there.
    ///
    /// The only way to a pack's photos. Callers never assemble the path
    /// themselves, so a pack that moves — into the caches directory for a
    /// downloaded pack, later — changes nothing in the views.
    ///
    /// - Parameter index: which of ``Bird/photos``. The default is the curated
    ///   portrait, which is what the sticker, the round end's reward and the
    ///   collection cover show; only a quiz tile asks for another one (#194).
    public func photoURL(for bird: Bird, at index: Int = 0) -> URL? {
        guard bird.photos.indices.contains(index) else { return nil }
        return directory.mediaFile(bird.photos[index].file)
    }

    /// The recording of `bird`'s call on disk, `nil` when the species carries
    /// none or the file is not there. The call player (#30) plays nothing in
    /// either case.
    ///
    /// The twin of ``photoURL(for:)`` and for the same reason: a species may
    /// stay callless — the schema makes ``Bird/call`` optional — and where a
    /// pack lies is this type's secret, not the player's.
    public func callURL(for bird: Bird) -> URL? {
        bird.call.map(\.file).flatMap(directory.mediaFile)
    }

    /// The recorded clip for `sentence` about `bird`, `nil` when the pack
    /// declares none or the file is not there.
    ///
    /// The twin of ``callURL(for:)`` once more, and for the same reason: a
    /// pack may carry the question for one species and not for the next, and
    /// the app then speaks the sentence with `AVSpeechSynthesizer` (#151)
    /// rather than saying nothing. `sentence` is a String Catalog key.
    public func speechURL(for bird: Bird, sentence: String) -> URL? {
        bird.speech?[sentence].map(\.file).flatMap(directory.mediaFile)
    }
}
