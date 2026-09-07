import Testing
import ZilpZalpData

/// The Swift-side twin of `tools/generate_credits.py`: the tool derives the
/// credits from `data/packs`, this suite checks that what ships in the bundle
/// still names every asset that ships with it. An asset nobody credits is a
/// licence violation, so it fails here rather than in the App Store review.
@Suite("Bundled credits")
struct CreditsTests {
    @Test("the bundled credits decode")
    func decodesBundledCredits() throws {
        let credits = try Credits.bundled()

        #expect(!credits.media.isEmpty)
    }

    /// The test the credits generator exists for.
    @Test("every medium of the bundled pack is credited exactly once")
    func creditsEveryBundledAsset() throws {
        let credits = try Credits.bundled()
        let pack = try PackCatalog.bundled().pack
        let entries = credits.media.filter { $0.packID == pack.id }

        for bird in pack.birds {
            let photos = entries.filter { $0.birdID == bird.id && $0.kind == .photo }
            #expect(photos.count == 1, "'\(bird.id)' has \(photos.count) photo credits")
            #expect(photos.first?.attribution == bird.photo.attribution)
            #expect(photos.first?.license == bird.photo.license)
            #expect(photos.first?.sourceURL == bird.photo.sourceURL)

            // A call is credited exactly when there is one. Both directions
            // matter: a missing credit is a violation, an invented one is a
            // name in the app that belongs to nobody.
            let calls = entries.filter { $0.birdID == bird.id && $0.kind == .call }
            #expect(
                calls.count == (bird.call == nil ? 0 : 1),
                "'\(bird.id)' has \(calls.count) call credits",
            )
            #expect(calls.first?.attribution == bird.call?.attribution)
        }

        #expect(entries.count == pack.birds.count + pack.birds.count(where: { $0.call != nil }))
    }

    @Test("every credited bird name is the one the pack spells")
    func namesBirdsAsThePackDoes() throws {
        let credits = try Credits.bundled()
        let pack = try PackCatalog.bundled().pack
        let names = Dictionary(uniqueKeysWithValues: pack.birds.map { ($0.id, $0.name) })

        for entry in credits.media where entry.packID == pack.id {
            #expect(entry.birdName == names[entry.birdID])
        }
    }

    /// The fonts and Lucide are in no manifest — they come from the static
    /// lists in the generator. An empty section means that wiring broke.
    @Test("the fonts and icon sets are credited")
    func creditsFontsAndIcons() throws {
        let credits = try Credits.bundled()

        #expect(credits.fonts.map(\.name) == ["Baloo 2", "Nunito"])
        #expect(credits.icons.map(\.name) == ["Lucide", "Feather"])
        #expect(credits.fonts.allSatisfy { !$0.authors.isEmpty })
        #expect(credits.icons.allSatisfy { !$0.authors.isEmpty })
    }
}
