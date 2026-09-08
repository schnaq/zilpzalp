import Foundation

/// The licences a medium may carry.
///
/// The raw values are exactly the strings `tools/license_gate.py` permits.
/// Anything else — every NonCommercial and NoDerivatives variant above all —
/// is a decoding error rather than an asset that quietly reaches a build.
public enum License: String, Codable, Sendable {
    case cc0 = "CC0-1.0"
    case ccBy = "CC-BY-4.0"
    case ccBySa = "CC-BY-SA-4.0"
}

public extension License {
    /// How a licence is named in a credit line: the short public name, not the
    /// SPDX identifier the manifest carries. "CC BY" is what the licence deed
    /// itself asks to be called; "CC-BY-4.0" is a filing code.
    ///
    /// Not product copy and therefore not in a String Catalog: these three
    /// names are the same in every language, which is also why they may live
    /// in a package at all.
    ///
    /// Two screens read it — the photo credit in the corner of game 1 and the
    /// credits screen — so it sits beside the enum rather than in a copy per
    /// caller (#105).
    var shortName: String {
        switch self {
        case .cc0: "CC0"
        case .ccBy: "CC BY"
        case .ccBySa: "CC BY-SA"
        }
    }
}

/// One medium — a photo or a call — with everything the licence gate checks
/// and the credits screen is generated from.
public struct MediaAsset: Codable, Sendable, Hashable {
    /// Path relative to the manifest's directory, for instance `photos/amsel.png`.
    public let file: String
    /// Lowercase hexadecimal SHA-256 of the file. Mandatory even while the
    /// medium only lives in the bucket: it is what the download is verified against.
    public let sha256: String
    public let license: License
    /// Photographer or recordist. Never empty — CC BY and CC BY-SA demand the name.
    public let attribution: String
    /// Where the medium came from. Proof of origin only; at runtime the app
    /// reads media from our own bucket, never from the source.
    public let sourceURL: URL
    /// The day the medium was fetched, `YYYY-MM-DD` in the manifest.
    /// Contributors may change their licence later, so the date is evidence.
    public let retrieved: Date
}

/// One species in a pack.
public struct Bird: Codable, Sendable, Hashable, Identifiable {
    /// Stable, lowercase identifier such as `amsel`. Unique within the pack.
    public let id: String
    public let name: String
    public let scientificName: String
    /// iNaturalist taxon identifier, looked up at curation time. Never guessed.
    public let taxonID: Int
    /// German definite article, needed for "Wo ist **die** Amsel?".
    /// Not derivable from the name, so it is maintained per species.
    public let article: String
    /// Phonetic spelling for `AVSpeechSynthesizer`, `nil` when the written
    /// name is spoken correctly.
    public let pronunciation: String?
    public let photo: MediaAsset
    /// `nil` as long as no freely licensed recording exists — the species
    /// stays usable in the photo games.
    public let call: MediaAsset?
}

/// A pack of species, the unit that is bundled or downloaded.
public struct Pack: Codable, Sendable, Hashable, Identifiable {
    /// Stable, lowercase identifier such as `basis`, and the name of the
    /// pack's directory.
    public let id: String
    /// Product text shown to parents when they pick a pack.
    public let title: String
    public let birds: [Bird]
}
