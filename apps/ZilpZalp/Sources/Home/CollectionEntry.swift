import SwiftUI
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
    /// The pack, `nil` for every bird — the value ``Profile/collection``
    /// stores.
    let id: String?

    /// The word under the picture: the pack's manifest title, or „Alle Vögel".
    let title: String

    /// The photo of the collection's first bird. `nil` leaves the sticker its
    /// glyph, which is what a pack whose photos are still downloading looks
    /// like.
    let cover: Image?

    /// What the app says when this entry is tapped.
    ///
    /// A pack's title comes from its manifest, which records no clip of its own
    /// name, so it is spoken by the synthesiser — ``SpokenLine/assembled(_:)``.
    /// „Alle Vögel" is a String Catalog entry and takes its key, so a
    /// recording of it would be found the day one is made.
    var spoken: SpokenLine {
        id == nil ? .fixed("home.collection.all") : .assembled(title)
    }
}

extension AppModel {
    /// The collection the playing child's rounds ask about.
    ///
    /// Resolved on every read rather than stored: a grown-up can delete the
    /// pack a child chose while the app runs, and ``PackCollections/chosen(_:)``
    /// answers with every bird for a pack that is no longer there — silently,
    /// and without touching the profile.
    var collection: PackCollection {
        packs.collections.chosen(activeProfile?.collection)
    }

    /// What the picker offers, or nothing at all.
    ///
    /// Empty while there is only one pack on the device: „Alle Vögel" and that
    /// pack are then the same birds, and a picker that offers the same thing
    /// twice would cost the home screen a row for nothing.
    var collectionEntries: [CollectionEntry] {
        guard packs.collections.isChoice else { return [] }

        return packs.collections.entries.map { collection in
            CollectionEntry(
                id: collection.id,
                title: collection.title ?? String(localized: "home.collection.all"),
                cover: collection.cover.flatMap { packs.photos[$0.id] },
            )
        }
    }
}
