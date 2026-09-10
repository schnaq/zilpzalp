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
    /// Every photo of the species, at least one, **the curated portrait
    /// first**. A child that meets the same picture in every round learns the
    /// picture and not the bird (#194), so a quiz tile shows one of them at a
    /// time — while the sticker, the round end's reward and the collection
    /// cover always show the first, which is the one that was framed to be
    /// looked at on its own.
    ///
    /// Each photo carries its own licence, attribution and source: they come
    /// from different observations and often from different photographers.
    public let photos: [MediaAsset]
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

public extension Bird {
    /// The manifest's keys, spelled out rather than synthesised: ``photo``
    /// below has to stay out of them, so that what this type writes carries
    /// only the shape the manifests have now.
    private enum CodingKeys: String, CodingKey {
        case id, name, scientificName, taxonID, article, pronunciation
        case photos, call, speech
    }

    /// The key a manifest wrote a single photo under before #194.
    ///
    /// Read only by ``init(from:)``, and never written.
    private enum LegacyKeys: String, CodingKey {
        case photo
    }

    /// Decodes a species, from a manifest in either shape.
    ///
    /// **A manifest that carries `photo` instead of `photos` still decodes**,
    /// as the single photo of a species. Not a courtesy to old files in the
    /// repository — the migration rewrote those in one step — but to the packs
    /// that are *installed on devices*: `welt` and `afrika` were downloaded in
    /// the old shape, and a required `photos` would turn each of them into a
    /// pack the grown-ups' area names as broken until somebody deletes and
    /// fetches it again. Two lines here are cheaper than that, and cheaper than
    /// a schema version the pack manifests have never carried.
    ///
    /// Everything else is what the compiler would have synthesised.
    ///
    /// - Throws: `DecodingError.dataCorrupted` when a species declares no photo
    ///   at all — under either key, or as an empty list. Every screen that
    ///   shows a bird shows a photo of it, so a species without one is a broken
    ///   manifest rather than a bird that quietly never appears.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        scientificName = try container.decode(String.self, forKey: .scientificName)
        taxonID = try container.decode(Int.self, forKey: .taxonID)
        article = try container.decode(String.self, forKey: .article)
        pronunciation = try container.decodeIfPresent(String.self, forKey: .pronunciation)
        call = try container.decodeIfPresent(MediaAsset.self, forKey: .call)
        speech = try container.decodeIfPresent([String: MediaClip].self, forKey: .speech)

        if let photos = try container.decodeIfPresent([MediaAsset].self, forKey: .photos) {
            self.photos = photos
        } else {
            let legacy = try decoder.container(keyedBy: LegacyKeys.self)
            photos = try legacy.decodeIfPresent(MediaAsset.self, forKey: .photo).map { [$0] } ?? []
        }
        guard !photos.isEmpty else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: container.codingPath + [CodingKeys.photos],
                    debugDescription: "a species has to declare at least one photo",
                ),
            )
        }
    }
}

extension Bird {
    /// The files this species declares: its photos in manifest order, its
    /// call, then every sentence recorded about it in sentence-key order, each
    /// with the digest it has to hash to.
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
        (photos + [call].compactMap(\.self)).map { (file: $0.file, sha256: $0.sha256) }
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
