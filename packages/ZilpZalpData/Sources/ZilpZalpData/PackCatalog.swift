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
    private static let bundledPackID = "basis"

    public let pack: Pack

    /// Where the pack's manifest lives. Media paths are relative to it, which
    /// is the same rule `tools/license_gate.py` applies.
    private let directory: URL

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

    /// The photo file of `bird` on disk, `nil` when it is not there.
    ///
    /// The only way to a pack's photos. Callers never assemble the path
    /// themselves, so a pack that moves — into the caches directory for a
    /// downloaded pack, later — changes nothing in the views.
    public func photoURL(for bird: Bird) -> URL? {
        let photo = directory.appending(path: bird.photo.file)
        guard FileManager.default.fileExists(atPath: photo.path(percentEncoded: false)) else {
            return nil
        }
        return photo
    }
}
