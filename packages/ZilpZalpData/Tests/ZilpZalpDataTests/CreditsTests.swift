import Foundation
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
            // One credit line per photo, and two photos from the same
            // observation collapse into the single line they would repeat —
            // which is why this counts the distinct lines the species declares
            // rather than its photos.
            let photos = entries.filter { $0.birdID == bird.id && $0.kind == .photo }
            let declared = bird.photos
                .map { [$0.attribution, $0.license.rawValue, "\($0.sourceURL)"] }
            #expect(
                photos.count == Set(declared).count,
                "'\(bird.id)' has \(photos.count) photo credits for \(bird.photos.count) photos",
            )
            for photo in bird.photos {
                #expect(
                    photos.contains {
                        $0.attribution == photo.attribution
                            && $0.license == photo.license
                            && $0.sourceURL == photo.sourceURL
                    },
                    "\(photo.file) is not credited",
                )
            }
            // The screen shows the name and must not have to open the pack for
            // it, so the copy in the credits has to be the pack's own.
            #expect(photos.first?.birdName == bird.name)

            // A call is credited exactly when there is one. Both directions
            // matter: a missing credit is a violation, an invented one is a
            // name in the app that belongs to nobody.
            let calls = entries.filter { $0.birdID == bird.id && $0.kind == .call }
            #expect(
                calls.count == (bird.call == nil ? 0 : 1),
                "'\(bird.id)' has \(calls.count) call credits",
            )
            #expect(calls.first?.attribution == bird.call?.attribution)
            #expect(calls.first?.birdName == (bird.call == nil ? nil : bird.name))
        }

        #expect(entries.count == pack.birds.count + pack.birds.count(where: { $0.call != nil }))
    }

    /// The voices section, decoded from the shape `tools/generate_credits.py`
    /// writes. Nothing in the repository has a voice yet, so without this a
    /// renamed key would only be found once the first recording ships — and
    /// then as a credits screen that decodes to nothing.
    @Test("a voice decodes the way the generator writes it")
    func decodesAVoice() throws {
        let document = """
        {
          "media": [],
          "voices": [
            {
              "attribution": "Stimme: Johanna",
              "license": "CC-BY-4.0",
              "sourceURL": "https://example.org/docs/sprachaufnahmen.md",
              "usedIn": "Ansagen"
            }
          ],
          "fonts": [],
          "icons": []
        }
        """

        let credits = try JSONDecoder().decode(Credits.self, from: Data(document.utf8))

        #expect(credits.voices.map(\.attribution) == ["Stimme: Johanna"])
        #expect(credits.voices.first?.license == .ccBy)
        #expect(credits.voices.first?.usedIn == "Ansagen")
    }

    /// The fonts and Lucide are in no manifest — they come from the static
    /// lists in the generator. An empty section means that wiring broke.
    ///
    /// Deliberately not the exact roster: which families ship is the
    /// generator's list to state, and `tools/tests/test_generate_credits.py`
    /// already checks that all of it reaches the JSON. Repeating the names
    /// here would only give them a third place to go stale.
    @Test("the fonts and icon sets are credited")
    func creditsFontsAndIcons() throws {
        let credits = try Credits.bundled()

        #expect(!credits.fonts.isEmpty)
        #expect(!credits.icons.isEmpty)

        for entry in credits.fonts + credits.icons {
            #expect(!entry.name.isEmpty)
            #expect(!entry.authors.isEmpty, "'\(entry.name)' credits nobody")
            #expect(!entry.license.isEmpty, "'\(entry.name)' names no licence")
        }
    }
}
