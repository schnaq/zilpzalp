import Foundation
import Testing
import ZilpZalpData

/// The valid manifests are fixture files, the invalid ones are literals in
/// this file: a broken manifest on disk would be a licence gate finding, and
/// the gate is right to reject it. `mise run check` gates `data/packs` only,
/// so the fixtures are held against the gate by hand before a change lands:
/// `python tools/license_gate.py <this directory>/valid`.
///
/// The fixture's photo credits are the real ones from
/// `design/assets/photos/CREDITS.md`; its SHA-256 values are placeholders,
/// because no media file sits next to a fixture. It is a fixture, not a pack.
@Suite("Pack manifest")
struct PackManifestTests {
    // MARK: - Valid manifests

    @Test("a manifest decodes into a pack, its birds and their media")
    func decodesFullManifest() throws {
        let pack = try PackManifest.decode(Self.fixture("basis"))

        #expect(pack.id == "basis")
        #expect(pack.title == "Unsere ersten Vögel")
        #expect(pack.birds.map(\.id) == ["amsel", "zilpzalp"])

        let zilpzalp = try Self.bird("zilpzalp", in: pack)
        #expect(zilpzalp.name == "Zilpzalp")
        #expect(zilpzalp.scientificName == "Phylloscopus collybita")
        #expect(zilpzalp.taxonID == 117_016)
        #expect(zilpzalp.article == "der")
        #expect(zilpzalp.pronunciation == "Tsilp-Tsalp")
        #expect(zilpzalp.photo.license == .ccBy)
        #expect(zilpzalp.photo.file == "photos/zilpzalp.png")
        #expect(zilpzalp.photo.attribution == "Tomas Broucek")
        #expect(
            zilpzalp.photo.sourceURL
                == URL(string: "https://www.inaturalist.org/observations/353438691"),
        )
        #expect(zilpzalp.call?.license == .ccBySa)
    }

    @Test("a bird without a call and without a pronunciation decodes")
    func decodesBirdWithoutOptionalFields() throws {
        let pack = try PackManifest.decode(Self.fixture("basis"))
        let amsel = try Self.bird("amsel", in: pack)

        #expect(amsel.call == nil)
        #expect(amsel.pronunciation == nil)
    }

    @Test("a manifest survives decoding, encoding and decoding again")
    func roundTripsThroughJSON() throws {
        let pack = try PackManifest.decode(Self.fixture("basis"))

        let reencoded = try Self.encoder.encode(pack)
        let decodedAgain = try PackManifest.decode(reencoded)

        #expect(decodedAgain == pack)
    }

    @Test("retrieved is read as the calendar day the manifest names")
    func decodesRetrievedDate() throws {
        let pack = try PackManifest.decode(Self.fixture("basis"))
        let amsel = try Self.bird("amsel", in: pack)

        // The manifest's day, not the runner's: with the local time zone,
        // midnight UTC is the day before west of Greenwich.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: "UTC"))
        let day = calendar.dateComponents([.year, .month, .day], from: amsel.photo.retrieved)

        #expect(day.year == 2026)
        #expect(day.month == 8)
        #expect(day.day == 1)
    }

    /// `CC-BY-4.0` and `CC-BY-SA-4.0` come out of the fixture above; `CC0-1.0`
    /// is the third value the licence gate permits and has no medium yet.
    @Test("the third permitted licence decodes as well")
    func decodesCC0() throws {
        let manifest = try Self.manifest(replacing: #""CC-BY-4.0""#, with: #""CC0-1.0""#)

        let pack = try PackManifest.decode(manifest)
        let testvogel = try Self.bird("testvogel", in: pack)

        #expect(testvogel.photo.license == .cc0)
    }

    // MARK: - Invalid manifests

    @Test("a missing required field fails and names the field")
    func failsOnMissingField() throws {
        let manifest = try Self.manifest(replacing: #""article": "die","#, with: "")

        let error = try #require(throws: DecodingError.self) {
            try PackManifest.decode(manifest)
        }
        guard case let .keyNotFound(key, _) = error else {
            Issue.record("expected a keyNotFound error, got \(error)")
            return
        }
        #expect(key.stringValue == "article")
    }

    @Test("a licence outside the permitted set fails")
    func failsOnUnknownLicence() throws {
        let manifest = try Self.manifest(replacing: #""CC-BY-4.0""#, with: #""CC-BY-NC-4.0""#)

        let error = try #require(throws: DecodingError.self) {
            try PackManifest.decode(manifest)
        }
        guard case let .dataCorrupted(context) = error else {
            Issue.record("expected a dataCorrupted error, got \(error)")
            return
        }
        #expect(context.codingPath.last?.stringValue == "license")
    }

    @Test("a retrieved value that is not a YYYY-MM-DD date fails")
    func failsOnMalformedDate() throws {
        let manifest = try Self.manifest(replacing: #""2026-08-01""#, with: #""01.08.2026""#)

        let error = try #require(throws: DecodingError.self) {
            try PackManifest.decode(manifest)
        }
        guard case let .dataCorrupted(context) = error else {
            Issue.record("expected a dataCorrupted error, got \(error)")
            return
        }
        #expect(context.codingPath.last?.stringValue == "retrieved")
    }
}

// MARK: - Fixtures and helpers

extension PackManifestTests {
    /// Encodes the way `PackManifest` decodes. Deliberately configured here
    /// rather than exposed from the library: nothing in the app writes
    /// manifests — `tools/fetch-media` does, in Python. If the two date
    /// formats ever drift apart, the round trip fails, which is the point.
    private static let encoder: JSONEncoder = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .formatted(formatter)
        return encoder
    }()

    private static func fixture(_ name: String) throws -> Data {
        let url = try #require(
            Bundle.module.url(
                forResource: name,
                withExtension: "json",
                subdirectory: "Fixtures/valid",
            ),
            "no fixture \(name).json in the test bundle",
        )
        return try Data(contentsOf: url)
    }

    private static func bird(_ id: String, in pack: Pack) throws -> Bird {
        try #require(pack.birds.first { $0.id == id }, "the pack holds no bird '\(id)'")
    }

    /// A copy of `validManifest` with one substring replaced — the invalid
    /// cases differ from a valid manifest in exactly one place.
    private static func manifest(
        replacing original: String,
        with replacement: String,
    ) throws -> Data {
        try #require(
            validManifest.contains(original),
            "the template no longer contains \(original)",
        )
        return Data(validManifest.replacingOccurrences(of: original, with: replacement).utf8)
    }

    /// Made up on purpose and independent of the fixtures: it only has to be
    /// a manifest the schema accepts, so that a test may break exactly one
    /// thing in it. Nothing here needs to stay in step with a real pack.
    private static let validManifest = """
    {
      "id": "test",
      "title": "Test",
      "birds": [
        {
          "id": "testvogel",
          "name": "Testvogel",
          "scientificName": "Testus testus",
          "taxonID": 1,
          "article": "die",
          "pronunciation": null,
          "photo": {
            "file": "photos/testvogel.png",
            "sha256": "0000000000000000000000000000000000000000000000000000000000000000",
            "license": "CC-BY-4.0",
            "attribution": "Test Photographer",
            "sourceURL": "https://example.org/observations/1",
            "retrieved": "2026-08-01"
          },
          "call": null
        }
      ]
    }
    """
}
