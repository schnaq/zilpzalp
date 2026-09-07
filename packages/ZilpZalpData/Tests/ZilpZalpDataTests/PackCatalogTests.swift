import CryptoKit
import Foundation
import Testing
import ZilpZalpData

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
            let digest = try SHA256.hash(data: Data(contentsOf: url))
            let hex = digest.map { String(format: "%02x", $0) }.joined()

            #expect(hex == bird.photo.sha256, "photo of '\(bird.id)' does not match its sha256")
        }
    }

    @Test("no bird carries a call yet")
    func hasNoCalls() throws {
        let catalog = try PackCatalog.bundled()

        #expect(catalog.pack.birds.allSatisfy { $0.call == nil })
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
}
