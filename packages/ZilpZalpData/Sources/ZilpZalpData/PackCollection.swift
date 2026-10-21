import Foundation

/// One collection a child can choose between on the home screen: every bird on
/// the device, the birds of one pack (#187), or of several packs together
/// (#306).
///
/// Not the sticker album — that is `CollectionScreen` in the app and
/// ``Profile/recognitions`` in this module. This is Christian's *Kollektion*:
/// which birds a round asks about. „Ich möchte gerne, dass ich die Kollektion
/// auswählen kann. Also entweder möchte ich die Vögel aus Deutschland, oder
/// der Welt, Afrika, Australien, alle auf einmal, …"
public struct PackCollection: Sendable {
    /// The pack this collection is, `nil` for every bird and for several
    /// packs together. One of the values ``Profile/collections`` stores.
    public let id: String?

    /// The pack's own title from its manifest — „Vögel Afrikas".
    ///
    /// `nil` for every bird at once and for a mix of packs, whose name is product copy and therefore
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

    /// Which species carry a recording on disk, asked once when the
    /// collections are built — see ``PackCollection/offersCalls``. Kept so a
    /// mix of packs is counted without a `fileExists` per species per layout
    /// pass.
    private let calling: Set<String>

    /// The packs of a stored choice that are on offer here — empty for every
    /// bird.
    ///
    /// - Parameter stored: what ``Profile/collections`` stored.
    /// - Returns: those of them that are entries here. A pack a grown-up has
    ///   deleted since, or one too small to play, drops out silently: a child
    ///   who has lost a pack is answered with birds, not with a message about
    ///   a pack, and nothing here writes the profile.
    public func selection(_ stored: [String]) -> Set<String> {
        Set(stored).intersection(entries.compactMap(\.id))
    }

    /// The collection a child plays with.
    ///
    /// - Parameter stored: what ``Profile/collections`` stored.
    /// - Returns: every bird when ``selection(_:)`` is empty, the one pack's
    ///   collection when it names one, and the birds of all of them — each
    ///   species once — when it names several.
    public func chosen(_ stored: [String]) -> PackCollection {
        let ids = selection(stored)
        if ids.count == 1, let one = entries.first(where: { $0.id == ids.first }) {
            return one
        }
        guard let library = everything.library.narrowed(toPacks: ids) else { return everything }
        return PackCollection(
            id: nil,
            title: nil,
            library: library,
            cover: nil,
            offersCalls: Self.offersCalls(library.birds, calling: calling),
        )
    }

    /// The choice after a child tapped `id` in the picker (#306).
    ///
    /// A pack toggles: in if it was out, out if it was in. „Alle Vögel" —
    /// `nil` — is every bird, so it clears the packs; and taking the last pack
    /// out leaves nothing chosen, which is every bird too. Works on what was
    /// stored rather than on ``selection(_:)``, so a deleted pack's id stays
    /// standing until „Alle Vögel" is tapped, as ``Profile/collections`` asks.
    ///
    /// - Returns: the new choice, sorted, as ``Profile/collections`` keeps it.
    public static func toggled(_ id: String?, in stored: [String]) -> [String] {
        guard let id else { return [] }
        return Set(stored).symmetricDifference([id]).sorted()
    }

    private static func offersCalls(_ birds: [Bird], calling: Set<String>) -> Bool {
        birds.count { calling.contains($0.id) } >= minimumSpecies
    }

    /// - Parameter library: every pack that opened, merged — ``PackLibrary``.
    public init(_ library: PackLibrary) {
        // Which species have a recording on disk, asked once for the whole
        // library rather than once per collection: the answer costs a file
        // lookup per species, and every species is in „alle" as well as in its
        // own pack — so asking per collection would ask about each of them
        // twice over.
        let calling = Set(library.birds.filter { library.callURL(for: $0) != nil }.map(\.id))
        self.calling = calling
        func offersCalls(_ birds: [Bird]) -> Bool {
            Self.offersCalls(birds, calling: calling)
        }

        everything = PackCollection(
            id: nil,
            title: nil,
            library: library,
            cover: nil,
            offersCalls: offersCalls(library.birds),
        )

        let packs = library.packs.compactMap { pack -> PackCollection? in
            guard let narrowed = library.narrowed(toPacks: [pack.id]),
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
