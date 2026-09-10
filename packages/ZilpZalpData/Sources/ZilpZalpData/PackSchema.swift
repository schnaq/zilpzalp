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

/// One recorded sentence.
///
/// Three fields and no licence of its own: what a recording may be used for is
/// a property of the voice that spoke it, and that sits once on the manifest —
/// ``Pack/voice``. Two hundred clips of one person would otherwise carry two
/// hundred identical attributions. ``MediaAsset`` keeps its six fields.
public struct MediaClip: Codable, Sendable, Hashable {
    /// Path relative to the manifest's directory, for instance
    /// `speech/quiz.prompt.whereIs/amsel.m4a`.
    public let file: String
    /// Lowercase hexadecimal SHA-256 of the file, as for every medium: it is
    /// what a download is verified against.
    public let sha256: String
    /// What was said when the clip was produced. Recorded so that a sentence
    /// reworded in the String Catalog cannot ship with a clip that says
    /// something else than the screen shows.
    public let text: String
}

/// Who spoke a manifest's recorded sentences, and under which licence.
///
/// One block per manifest rather than one per clip, which is also how the
/// credits name it: once per pack, never once per sentence.
public struct Voice: Codable, Sendable, Hashable {
    public let license: License
    /// Who spoke — "Stimme: Johanna". Never empty; CC BY and CC BY-SA demand
    /// the name, and `tools/license_gate.py` insists on it.
    public let attribution: String
    /// Where the recordings came from. Proof of origin, as for every medium.
    public let sourceURL: URL
    /// The day the recordings were made, `YYYY-MM-DD` in the manifest.
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
    /// What the app says about this species, by String Catalog key.
    ///
    /// A dictionary rather than an enum of known keys, so a pack may ship a
    /// sentence an older installed app does not know without failing to
    /// decode. `nil`, or a key that is missing, means the app speaks the
    /// sentence with `AVSpeechSynthesizer` instead (#151) — never silence.
    public let speech: [String: MediaClip]?
}

extension Bird {
    /// The files this species declares: its photo, its call, then every
    /// sentence recorded about it in sentence-key order, each with the digest
    /// it has to hash to.
    ///
    /// It lists the fields it lies beside, which is the whole reason it lies
    /// here: #163 taught the schema `speech` and taught `media_files()` in
    /// `tools/fetch_media/manifest.py` to upload it, while the enumeration a
    /// file away in ``PackDownloader`` kept fetching photos and calls only —
    /// that gap is #166. Beside the fields it is at least hard to miss.
    ///
    /// Sentence-key order rather than the dictionary's own, which is not
    /// stable: a resumed download should walk a pack the way the interrupted
    /// one did. Path and digest and no more, because that is all a download
    /// needs — a clip carries no licence of its own, the voice that spoke it
    /// does, once per manifest.
    var declaredFiles: [(file: String, sha256: String)] {
        [photo, call].compactMap(\.self).map { (file: $0.file, sha256: $0.sha256) }
            + (speech ?? [:]).sorted { $0.key < $1.key }
            .map { (file: $0.value.file, sha256: $0.value.sha256) }
    }
}

/// A pack of species, the unit that is bundled or downloaded.
public struct Pack: Codable, Sendable, Hashable, Identifiable {
    /// Stable, lowercase identifier such as `deutschland`, and the name of the
    /// pack's directory.
    public let id: String
    /// Product text shown to parents when they pick a pack.
    public let title: String
    /// Who spoke the pack's ``Bird/speech`` clips. `nil` while it has none —
    /// there is then nobody to credit.
    public let voice: Voice?
    public let birds: [Bird]
}

extension Pack {
    /// Every file the pack declares, in ``Bird/declaredFiles`` order, each one
    /// once.
    ///
    /// The Swift twin of `media_files()` in `tools/fetch_media/manifest.py`:
    /// that list is what `fetch-media upload` puts in the bucket and what
    /// `packs/index.json` sizes, so a file only one of the two names is either
    /// a download that cannot finish or a progress bar that runs past its
    /// total.
    ///
    /// Each file once because a file may be named twice — two birds sharing a
    /// photo, two sentence keys sharing a recording. The two languages drop
    /// the later mention in orders of their own, so a file named twice has to
    /// carry the same digest both times; `tools/license_gate.py` is what says
    /// so, by checking every mention against the file on disk.
    var declaredFiles: [(file: String, sha256: String)] {
        var seen: Set<String> = []
        return birds.flatMap(\.declaredFiles).filter { seen.insert($0.file).inserted }
    }
}
