import Foundation

/// The catalogue of downloadable packs — `packs/index.json` in the media bucket.
///
/// `tools/fetch_media/index.py` generates it from the manifests under
/// `data/packs/` and uploads it as the last object of a run, so it never names
/// an object that is still missing. The bundled base pack is not in it: it
/// ships inside the app and is not downloadable.
public struct PackIndex: Codable, Sendable, Hashable {
    /// One downloadable pack — as much of it as a list of packs needs, so the
    /// list can be shown without fetching a single manifest.
    public struct Entry: Codable, Sendable, Hashable, Identifiable {
        /// Pack id, identical to the pack's directory in the bucket.
        public let id: String
        /// Display name, product content in German, taken from the manifest.
        public let title: String
        /// Number of birds in the manifest — for "24 Arten" in the pack list.
        public let speciesCount: Int
        /// Every object of the pack in bytes, the manifest included, so it is
        /// what the download really costs and the progress needs no correction.
        public let downloadSize: Int
        /// Bucket **key**, not a URL: `packs/<id>/manifest.json`.
        ///
        /// It is resolved against the same base the index came from, and the
        /// manifest's own media paths are resolved against the manifest. That
        /// is what lets the tests point at a local server instead of rewriting
        /// URLs, and what lets a CDN sit in front of the bucket without the
        /// index being regenerated.
        public let manifest: String
    }

    /// Every downloadable pack, sorted by `id`.
    public let packs: [Entry]
}
