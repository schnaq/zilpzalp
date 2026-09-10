import Foundation
import Testing

// @testable for the internal pack initialiser, as the library tests beside
// this one need it: a collection is built from packs that lie neither in
// `Bundle.module` nor below `Packs/`.
@testable import ZilpZalpData

/// What a child chooses between on the home screen (#187): every bird on the
/// device, or the birds of one pack. Not the sticker album.
@Suite("Pack collections")
struct PackCollectionTests {
    /// Four species, so the pack clears ``PackCollections/minimumSpecies``.
    private static func fourSpecies(_ prefix: String, calls: Int = 0) -> [Species] {
        (0 ..< 4).map { Species(id: "\(prefix)\($0)", call: $0 < calls) }
    }

    @Test("a collection holds one pack's birds, with the media that pack has")
    func narrowsToOnePack() throws {
        try withPacks { home in
            let bundled = try PackFolder.write(
                pack: "basis",
                species: Self.fourSpecies("basis"),
                to: home,
            )
            let installed = try PackFolder.write(
                pack: "afrika",
                species: Self.fourSpecies("afrika", calls: 1),
                to: home,
            )
            let library = PackLibrary([bundled, installed])

            let afrika = try #require(library.narrowed(toPack: "afrika"))

            #expect(afrika.birds.map(\.id) == ["afrika0", "afrika1", "afrika2", "afrika3"])
            #expect(afrika.packs.map(\.id) == ["afrika"])
            // Narrowed, not rebuilt: the media still come from the pack that
            // declared the bird.
            let bird = try #require(afrika.birds.first)
            let photo = try #require(afrika.photoURL(for: bird))
            #expect(try Data(contentsOf: photo) == PackFolder.bytes("afrika", "afrika0", "photo"))
            #expect(afrika.callURL(for: bird) != nil)
        }
    }

    /// The merge keeps a species that two manifests declare in the first pack
    /// that declared it. A collection of the second pack still lists the
    /// species — it is one of that pack's birds — and answers for it with the
    /// media the whole library answers with, which is what keeps the album and
    /// a round from showing two different photos of one bird.
    @Test("a species two packs declare keeps the pack that owns it")
    func keepsTheOwningPacksMedia() throws {
        try withPacks { home in
            let bundled = try PackFolder.write(
                pack: "basis",
                species: Self.fourSpecies("basis") + [Species(id: "amsel", call: true)],
                to: home,
            )
            let installed = try PackFolder.write(
                pack: "deutschland",
                species: Self.fourSpecies("de") + [Species(id: "amsel")],
                to: home,
            )
            let library = PackLibrary([bundled, installed])

            let deutschland = try #require(library.narrowed(toPack: "deutschland"))

            #expect(deutschland.birds.map(\.id).contains("amsel"))
            let amsel = try #require(deutschland.birds.first { $0.id == "amsel" })
            let photo = try #require(deutschland.photoURL(for: amsel))
            #expect(try Data(contentsOf: photo) == PackFolder.bytes("basis", "amsel", "photo"))
        }
    }

    @Test("a pack that is not installed narrows to nothing")
    func narrowsToNothingWithoutThePack() throws {
        try withPacks { home in
            let bundled = try PackFolder.write(
                pack: "basis",
                species: Self.fourSpecies("basis"),
                to: home,
            )

            #expect(PackLibrary([bundled]).narrowed(toPack: "australien") == nil)
        }
    }

    @Test("the entries are every bird first, then one per pack")
    func offersEveryPack() throws {
        try withPacks { home in
            let bundled = try PackFolder.write(
                pack: "basis",
                species: Self.fourSpecies("basis"),
                to: home,
            )
            let welt = try PackFolder.write(
                pack: "welt",
                species: Self.fourSpecies("welt"),
                to: home,
            )
            let collections = PackCollections(PackLibrary([bundled, welt]))

            #expect(collections.isChoice)
            #expect(collections.entries.map(\.id) == [nil, "basis", "welt"])
            // The titles are the manifests'; „Alle Vögel" is product copy and
            // belongs to the app, so this module leaves it blank.
            #expect(collections.entries.map(\.title) == [nil, "Paket basis", "Paket welt"])
            #expect(collections.everything.library.birds.count == 8)
            #expect(collections.entries.last?.library.birds.count == 4)
            // The picture that stands for a collection is the first bird of
            // its manifest — and every bird at once stands for none of them,
            // or it would wear the bundled pack's first bird twice.
            #expect(collections.entries.map(\.cover?.id) == [nil, "basis0", "welt0"])
        }
    }

    @Test("one pack alone is nothing to choose between")
    func offersNoChoiceForOnePack() throws {
        try withPacks { home in
            let bundled = try PackFolder.write(
                pack: "basis",
                species: Self.fourSpecies("basis"),
                to: home,
            )
            let collections = PackCollections(PackLibrary([bundled]))

            #expect(!collections.isChoice)
            #expect(collections.entries.map(\.id) == [nil])
        }
    }

    /// The cover is the bird the pack's own manifest opens with. Filtering the
    /// merged library and taking its first bird is not the same thing: a
    /// species an earlier pack declared stands earlier in that order, so this
    /// pack would wear the earlier pack's photo — two collections showing one
    /// bird, which is the confusion „Alle Vögel" gives up its cover to avoid.
    @Test("a pack's cover is the bird its own manifest opens with")
    func coversWithTheManifestsFirstBird() throws {
        try withPacks { home in
            let bundled = try PackFolder.write(
                pack: "basis",
                species: [Species(id: "amsel")] + Self.fourSpecies("basis"),
                to: home,
            )
            // Opens with its own bird, but declares the Amsel as well — which
            // the merge leaves in the bundled pack, ahead of everything here.
            let installed = try PackFolder.write(
                pack: "deutschland",
                species: [Species(id: "haussperling"), Species(id: "amsel")]
                    + Self.fourSpecies("de"),
                to: home,
            )
            let collections = PackCollections(PackLibrary([bundled, installed]))

            #expect(collections.chosen("basis").cover?.id == "amsel")
            #expect(collections.chosen("deutschland").cover?.id == "haussperling")
        }
    }

    @Test("a pack too small to play still leaves the rest a choice")
    func offersAChoiceBesideAnUnplayablePack() throws {
        try withPacks { home in
            let bundled = try PackFolder.write(
                pack: "basis",
                species: Self.fourSpecies("basis"),
                to: home,
            )
            let tiny = try PackFolder.write(
                pack: "australien",
                species: [Species(id: "emu"), Species(id: "kookaburra")],
                to: home,
            )
            let collections = PackCollections(PackLibrary([bundled, tiny]))

            // „Alle Vögel" holds the small pack's species too, so the two
            // entries are not the same birds and a child may want them left
            // out — unlike the bundled pack on its own, which is the whole
            // library and nothing to choose from.
            #expect(collections.isChoice)
            #expect(collections.entries.map(\.id) == [nil, "basis"])
            #expect(collections.everything.library.birds.count == 6)
        }
    }

    @Test("a pack too small for a question is not offered, and falls back")
    func skipsAPackWithTooFewSpecies() throws {
        try withPacks { home in
            let bundled = try PackFolder.write(
                pack: "basis",
                species: Self.fourSpecies("basis"),
                to: home,
            )
            let welt = try PackFolder.write(
                pack: "welt",
                species: Self.fourSpecies("welt"),
                to: home,
            )
            // Three species cannot fill one question's four choices.
            let tiny = try PackFolder.write(
                pack: "australien",
                species: [Species(id: "emu"), Species(id: "kookaburra"), Species(id: "kakadu")],
                to: home,
            )
            let collections = PackCollections(PackLibrary([bundled, welt, tiny]))

            #expect(collections.entries.map(\.id) == [nil, "basis", "welt"])
            // Its species are still in every round drawn from „Alle Vögel" —
            // they are just not a collection of their own.
            #expect(collections.everything.library.birds.count == 11)
            #expect(collections.chosen("australien").id == nil)
        }
    }

    @Test("a choice nothing answers for is every bird, silently")
    func fallsBackToEveryBird() throws {
        try withPacks { home in
            let bundled = try PackFolder.write(
                pack: "basis",
                species: Self.fourSpecies("basis"),
                to: home,
            )
            let welt = try PackFolder.write(
                pack: "welt",
                species: Self.fourSpecies("welt"),
                to: home,
            )
            let collections = PackCollections(PackLibrary([bundled, welt]))

            #expect(collections.chosen(nil).id == nil)
            #expect(collections.chosen("welt").id == "welt")
            // The pack a grown-up deleted while the choice stood.
            #expect(collections.chosen("afrika").id == nil)
            #expect(collections.chosen("afrika").library.birds.count == 8)
        }
    }

    @Test("game 2 is offered where four species of the collection carry a call")
    func countsTheCallsPerCollection() throws {
        try withPacks { home in
            let bundled = try PackFolder.write(
                pack: "basis",
                species: Self.fourSpecies("basis", calls: 4),
                to: home,
            )
            // Three recordings: enough to be a collection, not enough to ask
            // ten questions with (#31).
            let welt = try PackFolder.write(
                pack: "welt",
                species: Self.fourSpecies("welt", calls: 3),
                to: home,
            )
            let collections = PackCollections(PackLibrary([bundled, welt]))

            #expect(collections.chosen("basis").offersCalls)
            #expect(!collections.chosen("welt").offersCalls)
            // Seven across the two packs, so the game is there for „alle" —
            // which is exactly what counting per collection is about.
            #expect(collections.everything.offersCalls)
        }
    }
}
