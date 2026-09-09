import Foundation

/// What can go wrong while opening the credits.
public enum CreditsError: Error, Sendable {
    /// `credits.json` is not in `Bundle.module`. Either the resource
    /// declaration in `Package.swift` is gone, or the file was never
    /// generated — `mise run check` catches the second case through
    /// `tools/generate_credits.py`.
    case bundledFileMissing
}

/// Everything the credits screen names, generated rather than written.
///
/// `tools/generate_credits.py` derives this document from the pack manifests
/// under `data/packs/` and from the licence files vendored in the repository,
/// and `mise run check` fails when it had drifted. A photo that is exchanged
/// therefore changes its credit line with it — the alternative, attribution
/// typed into a view, drifts away from the assets the moment anybody forgets.
public struct Credits: Codable, Sendable, Hashable {
    /// Which of a bird's two media a credit names.
    public enum Kind: String, Codable, Sendable {
        case photo
        case call
    }

    /// One photo or one recording, credited.
    public struct Media: Codable, Sendable, Hashable {
        public let packID: String
        /// The pack's own title, as its manifest spells it. The screen heads
        /// each group of credits with it, and `basis` is a directory name.
        public let packTitle: String
        public let birdID: String
        /// The bird's name as the manifest spells it — the screen shows it and
        /// must not have to open the pack for it.
        public let birdName: String
        public let kind: Kind
        /// Photographer or recordist. Never empty — CC BY and CC BY-SA demand the name.
        public let attribution: String
        public let license: License
        /// Where the medium came from, for proof of origin.
        public let sourceURL: URL
    }

    /// One voice and everything it spoke, credited.
    ///
    /// Not a ``Kind`` beside `photo` and `call`: a voice licenses every clip
    /// of a manifest at once, so it is named once per pack and once for the
    /// fixed sentences. Per-clip rows would be two hundred lines of one name.
    public struct Voice: Codable, Sendable, Hashable {
        /// Who spoke — "Stimme: Johanna". Never empty; CC BY and CC BY-SA
        /// demand the name.
        public let attribution: String
        public let license: License
        /// Where the recordings came from, for proof of origin.
        public let sourceURL: URL
        /// The pack's own title, or the fixed set's — what a parent reads,
        /// never a directory name.
        public let usedIn: String
    }

    /// A vendored font family or icon set and the licence it ships under.
    ///
    /// One type for both: they carry the same four fields, and the difference
    /// between a font and an icon set is which list of `Credits` it stands in.
    public struct Vendored: Codable, Sendable, Hashable {
        public let name: String
        public let authors: [String]
        /// SPDX identifier — `OFL-1.1` for both font families, `ISC` for
        /// Lucide, `MIT` for the icons Lucide took from Feather.
        public let license: String
        /// The licence itself. External, so the screen only opens it behind
        /// the parental gate the Kids Category demands.
        public let licenseURL: URL
    }

    /// Packs sorted by id, birds in manifest order, photo before call.
    public let media: [Media]
    /// Packs sorted by id, the fixed sentences last. Empty until something has
    /// been recorded.
    public let voices: [Voice]
    public let fonts: [Vendored]
    public let icons: [Vendored]

    /// Reads the credits that ship inside the app.
    ///
    /// - Returns: the generated credits.
    /// - Throws: `CreditsError.bundledFileMissing` when `credits.json` is not
    ///   in the bundle, or a `DecodingError` when it does not match this shape.
    public static func bundled() throws -> Credits {
        guard let file = Bundle.module.url(forResource: "credits", withExtension: "json") else {
            throw CreditsError.bundledFileMissing
        }

        // A plain decoder: unlike a manifest, this document holds no dates, so
        // there is nothing to configure and nothing that could be configured
        // differently from `PackManifest`.
        return try JSONDecoder().decode(Credits.self, from: Data(contentsOf: file))
    }
}
