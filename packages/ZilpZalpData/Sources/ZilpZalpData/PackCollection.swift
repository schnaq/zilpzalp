import Foundation

/// One collection a child can choose between on the home screen: every bird on
/// the device, or the birds of one pack (#187).
///
/// Not the sticker album — that is `CollectionScreen` in the app and
/// ``Profile/recognitions`` in this module. This is Christian's *Kollektion*:
/// which birds a round asks about. „Ich möchte gerne, dass ich die Kollektion
/// auswählen kann. Also entweder möchte ich die Vögel aus Deutschland, oder
/// der Welt, Afrika, Australien, alle auf einmal, …"
public struct PackCollection: Sendable {
    /// The pack this collection is, `nil` for the one that holds every bird.
    /// The value ``Profile/collection`` stores.
    public let id: String?

    /// The pack's own title from its manifest — „Vögel Afrikas".
    ///
    /// `nil` for every bird at once, whose name is product copy and therefore
    /// the app's business: this module carries no German a child reads.
    public let title: String?

    /// What a round drawn from this collection plays with.
    public let library: PackLibrary

    /// The bird whose photo stands for the collection: the first of the
    /// manifest.
    ///
    /// **`nil` for every bird at once**, and not because there is nothing to
    /// show: the first bird of the whole library is the first bird of the
    /// bundled pack, so the two entries came out as the same photo of the same
    /// Amsel and a child could not tell them apart. Every bird is not one
    /// bird, and the picker draws a glyph for it instead.
    ///
    /// The first rather than a `cover` key in the manifest, which #187 allowed
    /// only together with the schema, `tools/fetch_media/manifest.py`,
    /// `license_gate.py` and the sync tool — a second change wearing this
    /// one's clothes. The four curated packs open with the Amsel, the
    /// Haussperling, the Kaiserpinguin and the Strauß, which are as
    /// recognisable as a cover gets.
    public let cover: Bird?

    /// Whether game 2 can be played from here: ``PackCollections/minimumSpecies``
    /// species carrying a recording on disk (#31), counted inside this
    /// collection rather than across every installed pack.
    ///
    /// Counted once, when the collections are built, because the home screen
    /// asks on every layout pass and the answer costs one `fileExists` per
    /// species — 131 of them with the curated packs installed.
    public let offersCalls: Bool
}

/// Everything a child can choose between, and what a stored choice resolves to.
///
/// Built from the merged library once per change — a download, a deletion — and
/// read on every layout pass. See ``PackCollection``.
public struct PackCollections: Sendable {
    /// How many species a collection needs before it is worth offering: the
    /// four choices one question puts on the screen, which is `choiceCount` in
    /// `Round.make` and the same four #31 drew for game 2's recordings. Below
    /// it a round would ask for the same two or three birds over and over.
    ///
    /// Spelled here rather than taken from `ZilpZalpCore`, which this module
    /// does not depend on and should not for one number. Every curated pack
    /// holds at least ten species, so this is a guard and never a screen.
    public static let minimumSpecies = 4

    /// The collection that holds every bird on the device, and what every
    /// choice falls back to.
    public let everything: PackCollection

    /// ``everything`` first, then one collection per playable pack in library
    /// order — or ``everything`` alone when there is nothing to choose between.
    public let entries: [PackCollection]

    /// Whether there is a choice to put on the home screen.
    ///
    /// One installed pack means „Alle Vögel" and that pack are the same set of
    /// birds, and a picker offering the same thing twice is noise on a screen
    /// whose whole job is to be obvious.
    public var isChoice: Bool {
        entries.count > 1
    }

    /// The collection a child plays with.
    ///
    /// - Parameter id: what ``Profile/collection`` stored.
    /// - Returns: the collection of that pack, or every bird — for `nil`, for a
    ///   pack a grown-up has deleted since, and for one too small to play.
    ///   Silently: a child who has lost a pack is answered with birds, not with
    ///   a message about a pack, and nothing here writes the profile.
    public func chosen(_ id: String?) -> PackCollection {
        entries.first { $0.id == id } ?? everything
    }

    /// - Parameter library: every pack that opened, merged — ``PackLibrary``.
    public init(_ library: PackLibrary) {
        // Which species have a recording on disk, asked once for the whole
        // library rather than once per collection: the answer costs a file
        // lookup per species, and every species is in „alle" as well as in its
        // own pack — so asking per collection would ask about each of them
        // twice over.
        let calling = Set(library.birds.filter { library.callURL(for: $0) != nil }.map(\.id))
        func offersCalls(_ birds: [Bird]) -> Bool {
            birds.count { calling.contains($0.id) } >= Self.minimumSpecies
        }

        everything = PackCollection(
            id: nil,
            title: nil,
            library: library,
            cover: nil,
            offersCalls: offersCalls(library.birds),
        )

        let packs = library.packs.compactMap { pack -> PackCollection? in
            guard let narrowed = library.narrowed(toPack: pack.id),
                  narrowed.birds.count >= Self.minimumSpecies
            else {
                return nil
            }
            // The first bird of *this* manifest, as the merged library holds
            // it — not the first of `narrowed.birds`, which is in library
            // order. The two differ exactly when an earlier pack declared the
            // same species: this pack would then wear that pack's cover, and
            // two collections showing one photo is the confusion „alle" gives
            // up its own cover to avoid.
            let opens = pack.birds.first?.id
            return PackCollection(
                id: pack.id,
                title: pack.title,
                library: narrowed,
                cover: narrowed.birds.first { $0.id == opens },
                offersCalls: offersCalls(narrowed.birds),
            )
        }

        // A choice is only a choice where something narrows: with the bundled
        // pack alone, „alle" and that pack are the same birds, and a picker
        // offering the same thing twice is noise on a screen whose whole job
        // is to be obvious. One playable pack beside one too small to play is
        // a choice all the same — „alle" holds the small pack's species too,
        // and a child may want them left out.
        let narrows = packs.contains { $0.library.birds.count < library.birds.count }
        entries = narrows ? [everything] + packs : [everything]
    }
}
