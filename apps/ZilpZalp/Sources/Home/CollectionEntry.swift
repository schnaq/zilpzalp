import SwiftUI
import ZilpZalpCore
import ZilpZalpData

/// One collection as the home screen draws it: which pack it is, what it is
/// called, the picture that stands for it and what the app says when a child
/// taps it (#187).
///
/// Not the sticker album — that is `CollectionScreen` and the `collection.*`
/// keys. This is which birds a round asks about.
///
/// The view's half of ``PackCollection``: the German „Alle Vögel" and the
/// photo files are the app's business, and `ZilpZalpData` carries neither.
struct CollectionEntry {
    /// The pack, `nil` for every bird — one of the values
    /// ``Profile/collections`` stores.
    let id: String?

    /// The word under the picture: the pack's manifest title, or „Alle Vögel".
    let title: String

    /// The photo of the collection's first bird. `nil` leaves the sticker its
    /// glyph, which is what a pack whose photos are still downloading looks
    /// like.
    let cover: Image?

    /// What the app says when this entry is tapped: the pack's own recording
    /// of its title where it has one (#306), the fixed set's „Alle Vögel" for
    /// every bird — each read out by the synthesiser where nothing is
    /// recorded.
    let spoken: SpokenLine

    /// Whether this entry is part of `selection` — see
    /// ``AppModel/collectionSelection``. „Alle Vögel" is chosen exactly when
    /// no pack is.
    func isChosen(in selection: Set<String>) -> Bool {
        id.map(selection.contains) ?? selection.isEmpty
    }
}

extension CollectionEntry {
    /// A photoless entry that says its own title — for the previews.
    static func preview(_ id: String?, _ title: String) -> CollectionEntry {
        CollectionEntry(id: id, title: title, cover: nil, spoken: .assembled(title))
    }
}

extension AppModel {
    /// The collection the playing child's rounds ask about — every bird, one
    /// pack, or several together (#306).
    ///
    /// Resolved on every read rather than stored: a grown-up can delete a
    /// pack a child chose while the app runs, and ``PackCollections/chosen(_:)``
    /// leaves out a pack that is no longer there — silently, and without
    /// touching the profile.
    var collection: PackCollection {
        packs.collections.chosen(activeProfile?.collections ?? [])
    }

    /// The packs the picker shows as chosen, resolved the same way; empty for
    /// „Alle Vögel".
    var collectionSelection: Set<String> {
        packs.collections.selection(activeProfile?.collections ?? [])
    }

    /// Whether the playing child holds most of the stickers there are on the
    /// device — and the last index seen had something left to load (#262).
    /// Read off disk only: the home screen never asks the network.
    var newBirdsDue: Bool {
        guard let profile = activeProfile, !packs.nothingLeft else { return false }
        let birds = packs.library.birds
        let held = Set(profile.stickers)
        return NewBirdsHint.isDue(
            collected: birds.count { held.contains($0.id) },
            of: birds.count,
        )
    }

    /// What the picker offers — never nothing, because its "+" is how a child
    /// asks for more birds (#262).
    ///
    /// With one pack on the device „Alle Vögel" and that pack are the same
    /// birds, so the one entry is the pack itself, standing for every bird:
    /// offering both would be the same thing twice.
    var collectionEntries: [CollectionEntry] {
        guard packs.collections.isChoice else {
            let pack = packs.library.packs.first
            return [CollectionEntry(
                id: nil,
                title: pack?.title ?? String(localized: "home.collection.all"),
                cover: pack?.birds.first.flatMap { packs.photos[$0.id] },
                spoken: pack.map { .packTitle($0.id, title: $0.title) }
                    ?? .fixed("home.collection.all"),
            )]
        }

        return packs.collections.entries.map { collection in
            let title = collection.title ?? String(localized: "home.collection.all")
            return CollectionEntry(
                id: collection.id,
                title: title,
                cover: collection.cover.flatMap { packs.photos[$0.id] },
                spoken: collection.id.map { .packTitle($0, title: title) }
                    ?? .fixed("home.collection.all"),
            )
        }
    }
}
