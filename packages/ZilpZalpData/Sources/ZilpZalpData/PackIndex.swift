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

        /// The SHA-256 of the manifest the bucket holds — what tells an
        /// installed pack from a newer one (#262). `nil` in an index written
        /// before it, and then no update is ever offered.
        public var manifestSha256: String?

        /// The species ids whose previews stand for the pack on its card,
        /// three of them, in the order the card draws them.
        public var covers: [String] = []

        /// Every bird of the pack as the gallery shows it before a download.
        /// Empty in an index written before #262, or while the bucket holds
        /// no previews for the pack.
        public var species: [Species] = []
    }

    /// One bird of a pack that is not on the device yet.
    public struct Species: Codable, Sendable, Hashable, Identifiable {
        /// The species id — the same in every pack that carries the bird, and
        /// what its sticker belongs to.
        public let id: String
        public let name: String
        /// Bucket key of a small square JPEG, resolved like ``Entry/manifest``.
        public let preview: String
        /// Who took the photo the preview was cut from, and under which
        /// licence — printed beside the previews, because the pack's credits
        /// are not on the device before it is downloaded.
        public let attribution: String
        public let license: String
    }

    /// A pack dissolved into others (#262): the device that has it installed
    /// is offered the successors, and lets it go once all of them are there.
    public struct Retired: Codable, Sendable, Hashable {
        public let id: String
        public let successors: [String]
    }

    /// One retired pack on this device, and what is still to be loaded for it.
    public struct Migration: Sendable, Hashable, Identifiable {
        public let retired: String
        /// The successors the index offers that are not installed yet. Empty
        /// once the retired pack can go.
        public let remaining: [Entry]

        public var id: String {
            retired
        }
    }

    /// Every downloadable pack, sorted by `id`.
    public let packs: [Entry]

    /// Packs that are no longer offered, with their successors. Empty in an
    /// index written before #262.
    public var retired: [Retired] = []

    /// The retired packs among `installed` that something can be done about:
    /// successors to load, or none left to load and the old pack to delete.
    ///
    /// A retired pack is left alone until the index lists **every** one of
    /// its successors: deleting it while one is still to be published would
    /// take that one's birds away until it is.
    ///
    /// - Parameter installed: the ids of the downloaded packs.
    public func migrations(installed: Set<String>) -> [Migration] {
        retired.compactMap { pack in
            guard installed.contains(pack.id) else { return nil }
            let offered = packs.filter { pack.successors.contains($0.id) }
            guard !offered.isEmpty, offered.count == Set(pack.successors).count else { return nil }
            return Migration(
                retired: pack.id,
                remaining: offered.filter { !installed.contains($0.id) },
            )
        }
    }
}

/// The decoders live in extensions so the memberwise initialisers survive. Every
/// field #262 added is optional: today's bucket has none of them, and the 1.0.0
/// build reads the same index without knowing them.
public extension PackIndex {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        packs = try container.decode([Entry].self, forKey: .packs)
        retired = try container.decodeIfPresent([Retired].self, forKey: .retired) ?? []
    }
}

public extension PackIndex.Entry {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        speciesCount = try container.decode(Int.self, forKey: .speciesCount)
        downloadSize = try container.decode(Int.self, forKey: .downloadSize)
        manifest = try container.decode(String.self, forKey: .manifest)
        manifestSha256 = try container.decodeIfPresent(String.self, forKey: .manifestSha256)
        covers = try container.decodeIfPresent([String].self, forKey: .covers) ?? []
        species = try container.decodeIfPresent([PackIndex.Species].self, forKey: .species) ?? []
    }
}
