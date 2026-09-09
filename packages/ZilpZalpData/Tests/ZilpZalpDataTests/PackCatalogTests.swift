import CryptoKit
import Foundation
import Testing

// @testable for the internal initialiser: a pack lies in the bundle or in
// Application Support, and the speech fixture below is neither.
@testable import ZilpZalpData

/// The Swift-side twin of `tools/license_gate.py`: the gate checks the pack in
/// `data/packs`, this suite checks the copy that actually ships in the bundle.
/// A pack that drifts between the two fails here rather than on a device.
@Suite("Bundled pack catalog")
struct PackCatalogTests {
    /// Alphabetical, and the order the manifest lists them in. Pinned because
    /// the round builder (#22) takes the pack's order as its input and a
    /// silently reordered manifest would change every seeded round.
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
    ]

    @Test("the bundled pack holds the ten base species in manifest order")
    func decodesBundledPack() throws {
        let catalog = try PackCatalog.bundled()

        #expect(catalog.pack.id == "basis")
        #expect(catalog.pack.birds.map(\.id) == Self.expectedIDs)
    }

    @Test("every photo is in the bundle and hashes to what the manifest declares")
    func resolvesEveryPhoto() throws {
        let catalog = try PackCatalog.bundled()

        for bird in catalog.pack.birds {
            let url = try #require(catalog.photoURL(for: bird), "no photo for '\(bird.id)'")
            let hex = try Self.sha256(of: url)

            #expect(hex == bird.photo.sha256, "photo of '\(bird.id)' does not match its sha256")
        }
    }

    /// The twin of ``resolvesEveryPhoto()``, and the reason game 2 appears at
    /// all: the home screen counts the species whose recording is on disk, not
    /// the ones the manifest merely declares.
    @Test("every call is in the bundle and hashes to what the manifest declares")
    func resolvesEveryCall() throws {
        let catalog = try PackCatalog.bundled()

        for bird in catalog.pack.birds {
            let call = try #require(bird.call, "no call declared for '\(bird.id)'")
            let url = try #require(catalog.callURL(for: bird), "no call file for '\(bird.id)'")
            let hex = try Self.sha256(of: url)

            #expect(hex == call.sha256, "call of '\(bird.id)' does not match its sha256")
        }
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
                let hex = try Self.sha256(of: url)

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
        let catalog = try Self.speakingFixture()
        let amsel = try #require(catalog.pack.birds.first { $0.id == "amsel" })
        let silent = try #require(catalog.pack.birds.first { $0.id == "stumm" })

        let url = try #require(catalog.speechURL(for: amsel, sentence: "quiz.prompt.whereIs"))
        #expect(try Self.sha256(of: url) == amsel.speech?["quiz.prompt.whereIs"]?.sha256)
        #expect(catalog.speechURL(for: amsel, sentence: "collection.name") == nil)
        #expect(catalog.speechURL(for: silent, sentence: "quiz.prompt.whereIs") == nil)
        // The licence of all of them, once, where the credits read it.
        #expect(catalog.pack.voice?.license == .ccBy)
        #expect(catalog.pack.voice?.attribution == "Stimme: Niemand")
    }

    /// A pack that speaks, from the test bundle rather than from `data/packs`.
    private static func speakingFixture() throws -> PackCatalog {
        let url = try #require(
            Bundle.module.url(
                forResource: "pack",
                withExtension: "json",
                subdirectory: "Fixtures/speech",
            ),
            "no Fixtures/speech/pack.json in the test bundle",
        )
        return try PackCatalog(
            pack: PackManifest.decode(Data(contentsOf: url)),
            directory: url.deletingLastPathComponent(),
        )
    }

    /// The lowercase hex SHA-256 of a file, spelled the way the manifest
    /// records it — the one comparison every media check above makes.
    private static func sha256(of url: URL) throws -> String {
        let data = try Data(contentsOf: url)
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
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
      "id": "basis",
      "title": "Unsere ersten Vögel",
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
