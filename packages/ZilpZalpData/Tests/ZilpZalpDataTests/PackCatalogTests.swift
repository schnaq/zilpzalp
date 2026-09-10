import Foundation
import Testing

// @testable for `PackManifest.decode`: the manifest spelled out below never
// travels through `PackCatalog.bundled()`. The speaking fixture the speech
// tests share reaches the internal initialiser the same way.
@testable import ZilpZalpData

/// The Swift-side twin of `tools/license_gate.py`: the gate checks the pack in
/// `data/packs`, this suite checks the copy that actually ships in the bundle.
/// A pack that drifts between the two fails here rather than on a device.
@Suite("Bundled pack catalog")
struct PackCatalogTests {
    /// The order the manifest lists them in: the ten species the app first
    /// shipped with, then the sixty „Vögel Deutschlands" brought (#192).
    /// Pinned because the round builder (#22) takes the pack's order as its
    /// input and a silently reordered manifest would change every seeded
    /// round.
    private static let expectedIDs = [
        "amsel",
        "blaumeise",
        "buntspecht",
        "eisvogel",
        "hausrotschwanz",
        "kohlmeise",
        "rotkehlchen",
        "star",
        "wiedehopf",
        "zilpzalp",
        "haussperling",
        "gruenfink",
        "buchfink",
        "stieglitz",
        "gimpel",
        "kernbeisser",
        "bluthaenfling",
        "goldammer",
        "elster",
        "eichelhaeher",
        "rabenkraehe",
        "dohle",
        "kolkrabe",
        "ringeltaube",
        "tuerkentaube",
        "mauersegler",
        "rauchschwalbe",
        "bachstelze",
        "zaunkoenig",
        "singdrossel",
        "nachtigall",
        "moenchsgrasmuecke",
        "kleiber",
        "gartenbaumlaeufer",
        "schwanzmeise",
        "haubenmeise",
        "wintergoldhaehnchen",
        "gartenrotschwanz",
        "feldlerche",
        "neuntoeter",
        "pirol",
        "seidenschwanz",
        "wasseramsel",
        "kuckuck",
        "gruenspecht",
        "schwarzspecht",
        "bienenfresser",
        "waldkauz",
        "uhu",
        "schleiereule",
        "steinkauz",
        "maeusebussard",
        "turmfalke",
        "rotmilan",
        "seeadler",
        "wanderfalke",
        "weissstorch",
        "graureiher",
        "kranich",
        "stockente",
        "mandarinente",
        "hoeckerschwan",
        "graugans",
        "blaesshuhn",
        "haubentaucher",
        "kormoran",
        "lachmoewe",
        "austernfischer",
        "kiebitz",
        "fasan",
    ]

    @Test("the bundled pack holds the seventy German species in manifest order")
    func decodesBundledPack() throws {
        let catalog = try PackCatalog.bundled()

        #expect(catalog.pack.id == PackCatalog.bundledPackID)
        #expect(catalog.pack.birds.map(\.id) == Self.expectedIDs)
    }

    @Test("every photo is in the bundle and hashes to what the manifest declares")
    func resolvesEveryPhoto() throws {
        let catalog = try PackCatalog.bundled()

        for bird in catalog.pack.birds {
            #expect(!bird.photos.isEmpty, "'\(bird.id)' declares no photo")
            // Every one of them, not only the portrait: a second photo the
            // bundle does not hold is a tile that draws its placeholder.
            for (index, photo) in bird.photos.enumerated() {
                let url = try #require(
                    catalog.photoURL(for: bird, at: index),
                    "no photo \(index) for '\(bird.id)'",
                )
                let hex = try sha256(of: url)

                #expect(hex == photo.sha256, "\(photo.file) does not match its sha256")
            }
            #expect(catalog.photoURL(for: bird, at: bird.photos.count) == nil)
        }
    }

    /// The twin of ``resolvesEveryPhoto()``, and the reason game 2 appears at
    /// all: the home screen counts the species whose recording is on disk, not
    /// the ones the manifest merely declares. A handful of the seventy carry
    /// no call yet — those are asked about in game 1 alone, which is why the
    /// count is checked instead of demanded per bird.
    @Test("every call the bundled pack declares hashes to what the manifest says")
    func resolvesEveryCall() throws {
        let catalog = try PackCatalog.bundled()
        var found = 0

        for bird in catalog.pack.birds {
            guard let call = bird.call else { continue }
            let url = try #require(catalog.callURL(for: bird), "no call file for '\(bird.id)'")
            let hex = try sha256(of: url)
            found += 1

            #expect(hex == call.sha256, "call of '\(bird.id)' does not match its sha256")
        }

        // Below that the home screen leaves game 2's tile out altogether
        // (#31), so the threshold is read from where the rule lives.
        #expect(found >= PackCollections.minimumSpecies)
    }

    /// The third medium, checked like the other two. Vacuous until the base
    /// pack has been recorded (Task 4 of the recorded-speech plan) — and that
    /// is the state it has to survive: with no clips the app speaks every
    /// sentence through `AVSpeechSynthesizer` and nothing here fails.
    @Test("every speech clip the bundled pack declares is in the bundle")
    func resolvesEverySpeechClip() throws {
        let catalog = try PackCatalog.bundled()

        for bird in catalog.pack.birds {
            for (sentence, clip) in bird.speech ?? [:] {
                let url = try #require(
                    catalog.speechURL(for: bird, sentence: sentence),
                    "no file for '\(bird.id)' / '\(sentence)'",
                )
                let hex = try sha256(of: url)

                #expect(
                    hex == clip.sha256,
                    "'\(bird.id)' / '\(sentence)' does not match its sha256",
                )
            }
        }
    }

    /// What the bundled pack cannot show while it has no clips: a sentence
    /// that resolves, one that is declared but not on disk, and a species that
    /// declares none at all. The clip is a real, silent `.m4a` — the rule that
    /// nothing audible is committed unheard holds for fixtures too.
    @Test("a speech clip resolves against the pack's own directory")
    func resolvesSpeechFromAFixture() throws {
        let catalog = try SpeechFixtures.speakingPack()
        let amsel = try #require(catalog.pack.birds.first { $0.id == "amsel" })
        let silent = try #require(catalog.pack.birds.first { $0.id == "stumm" })

        let url = try #require(catalog.speechURL(for: amsel, sentence: "quiz.prompt.whereIs"))
        #expect(try sha256(of: url) == amsel.speech?["quiz.prompt.whereIs"]?.sha256)
        #expect(catalog.speechURL(for: amsel, sentence: "collection.name") == nil)
        #expect(catalog.speechURL(for: silent, sentence: "quiz.prompt.whereIs") == nil)
        // The licence of all of them, once, where the credits read it.
        #expect(catalog.pack.voice?.license == .ccBy)
        #expect(catalog.pack.voice?.attribution == "Stimme: Niemand")
    }

    /// "Wo ist **die** Amsel?" — the article is spoken and written, and a
    /// typo in it would only show up in the app.
    @Test("every bird carries a German definite article")
    func hasArticles() throws {
        let catalog = try PackCatalog.bundled()

        for bird in catalog.pack.birds {
            #expect(
                ["der", "die", "das"].contains(bird.article),
                "'\(bird.id)' has the article '\(bird.article)'",
            )
        }
    }

    /// The two branches the bundled pack cannot reach on its own: a manifest
    /// entry whose file is not there, and a species that carries no recording
    /// at all. `nil` for both — so a tile can draw its placeholder and the
    /// player can stay silent (#30) — rather than a URL that fails much later.
    ///
    /// Asserted against a manifest and not against the bundle, so that the
    /// callless case still says something once a bundled bird gets a call.
    @Test("media that cannot be resolved come back as nil")
    func returnsNilForUnresolvableMedia() throws {
        let catalog = try PackCatalog.bundled()
        let ghosts = try PackManifest.decode(Data(Self.ghostManifest.utf8)).birds
        let missing = try #require(ghosts.first { $0.id == "gespenst" })
        let callless = try #require(ghosts.first { $0.id == "schemen" })

        #expect(catalog.photoURL(for: missing) == nil)
        #expect(catalog.callURL(for: missing) == nil)
        #expect(catalog.callURL(for: callless) == nil)
    }

    /// Two birds no pack directory holds: one whose declared media were never
    /// copied in, one that carries no call at all. Only `file` and `call`
    /// matter here; the rest is what the schema demands.
    private static let ghostManifest = """
    {
      "id": "gespenster",
      "title": "Vögel, die es nicht gibt",
      "birds": [
        {
          "id": "gespenst",
          "name": "Gespenst",
          "scientificName": "Spectrum spectrum",
          "taxonID": 1,
          "article": "das",
          "pronunciation": null,
          "photo": {
            "file": "photos/gespenst.png",
            "sha256": "0000000000000000000000000000000000000000000000000000000000000000",
            "license": "CC-BY-4.0",
            "attribution": "Nobody",
            "sourceURL": "https://example.org/observations/1",
            "retrieved": "2026-07-31"
          },
          "call": {
            "file": "calls/gespenst.m4a",
            "sha256": "0000000000000000000000000000000000000000000000000000000000000000",
            "license": "CC0-1.0",
            "attribution": "Nobody",
            "sourceURL": "https://example.org/recordings/1",
            "retrieved": "2026-07-31"
          }
        },
        {
          "id": "schemen",
          "name": "Schemen",
          "scientificName": "Spectrum umbra",
          "taxonID": 2,
          "article": "der",
          "pronunciation": null,
          "photo": {
            "file": "photos/schemen.png",
            "sha256": "0000000000000000000000000000000000000000000000000000000000000000",
            "license": "CC-BY-4.0",
            "attribution": "Nobody",
            "sourceURL": "https://example.org/observations/2",
            "retrieved": "2026-07-31"
          },
          "call": null
        }
      ]
    }
    """
}
