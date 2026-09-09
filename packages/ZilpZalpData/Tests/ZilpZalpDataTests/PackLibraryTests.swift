import Foundation
import Testing

// @testable for the internal pack initialiser: a library is assembled from
// packs that lie neither in `Bundle.module` nor below `Packs/`, which are the
// two places the public entry points know.
@testable import ZilpZalpData

/// What the app plays from once a grown-up has downloaded something: the
/// bundled pack and the installed ones, answering as one.
@Suite("Pack library")
struct PackLibraryTests {
    @Test("the bundled pack alone is the library every launch starts with")
    func opensTheBundledPack() throws {
        let library = try PackLibrary.bundled()
        let catalog = try PackCatalog.bundled()

        #expect(!library.isEmpty)
        #expect(library.packs.map(\.id) == ["basis"])
        #expect(library.birds.map(\.id) == catalog.pack.birds.map(\.id))

        let amsel = try #require(library.birds.first { $0.id == "amsel" })
        #expect(library.photoURL(for: amsel) == catalog.photoURL(for: amsel))
        #expect(library.callURL(for: amsel) == catalog.callURL(for: amsel))
    }

    @Test("a downloaded pack's species stand beside the bundled ones")
    func mergesAnInstalledPack() throws {
        try withPacks { home in
            let bundled = try PackFolder.write(
                pack: "basis",
                species: [Species(id: "amsel", call: true), Species(id: "star")],
                to: home,
            )
            let installed = try PackFolder.write(
                pack: "welt",
                species: [Species(id: "kolibri", sentence: "quiz.prompt.whereIs")],
                to: home,
            )
            let library = PackLibrary([bundled, installed])

            #expect(library.packs.map(\.id) == ["basis", "welt"])
            #expect(library.birds.map(\.id) == ["amsel", "star", "kolibri"])

            // Every kind of medium, resolved through the library rather than
            // through the pack it happens to lie in — which is the whole job.
            let kolibri = try #require(library.birds.first { $0.id == "kolibri" })
            let photo = try #require(library.photoURL(for: kolibri))
            #expect(try Data(contentsOf: photo) == PackFolder.bytes("welt", "kolibri", "photo"))
            let clip = try #require(
                library.speechURL(for: kolibri, sentence: "quiz.prompt.whereIs"),
            )
            #expect(try Data(contentsOf: clip) == PackFolder.bytes("welt", "kolibri", "speech"))

            // And the bundled pack still answers for its own.
            let amsel = try #require(library.birds.first { $0.id == "amsel" })
            #expect(library.callURL(for: amsel) != nil)
        }
    }

    /// The schema leaves ``Bird/call`` optional, and half the curated species
    /// have no freely licensed recording. A library must say so rather than
    /// hand back a URL nothing plays — this is what ``AppModel/games`` counts.
    @Test("a species without a recording has no call, whichever pack it is in")
    func reportsASpeciesWithoutACall() throws {
        try withPacks { home in
            let installed = try PackFolder.write(
                pack: "afrika",
                species: [Species(id: "nashornvogel", call: true), Species(id: "webervogel")],
                to: home,
            )
            let library = PackLibrary([installed])

            let calling = try #require(library.birds.first { $0.id == "nashornvogel" })
            let silent = try #require(library.birds.first { $0.id == "webervogel" })
            #expect(library.callURL(for: calling) != nil)
            #expect(library.callURL(for: silent) == nil)
        }
    }

    /// Species ids are unique across packs by curation rule — but a downloaded
    /// manifest is a document somebody else wrote, and the album and the round
    /// builder key dictionaries by species id, which traps on a duplicate. So
    /// the library drops the second mention, and the pack that ships with the
    /// app keeps its bird.
    @Test("a species declared twice is kept once, by the pack that came first")
    func keepsADuplicateSpeciesOnce() throws {
        try withPacks { home in
            let bundled = try PackFolder.write(
                pack: "basis",
                species: [Species(id: "amsel")],
                to: home,
            )
            let installed = try PackFolder.write(
                pack: "deutschland",
                species: [Species(id: "amsel", call: true), Species(id: "kranich")],
                to: home,
            )
            let library = PackLibrary([bundled, installed])

            #expect(library.birds.map(\.id) == ["amsel", "kranich"])

            let amsel = try #require(library.birds.first { $0.id == "amsel" })
            let photo = try #require(library.photoURL(for: amsel))
            #expect(try Data(contentsOf: photo) == PackFolder.bytes("basis", "amsel", "photo"))
            // The second pack's call does not reach the first pack's bird.
            #expect(library.callURL(for: amsel) == nil)
        }
    }

    /// A build whose bundled pack did not open. The shell draws its calm
    /// sentence for it, and nothing here may trap on the way there.
    @Test("a library without packs is empty and answers nothing")
    func answersNothingWhenEmpty() throws {
        try withPacks { home in
            let orphan = try PackFolder.write(
                pack: "welt",
                species: [Species(id: "kolibri", call: true, sentence: "quiz.prompt.whereIs")],
                to: home,
            )
            let bird = try #require(orphan.pack.birds.first)

            #expect(PackLibrary.empty.isEmpty)
            #expect(PackLibrary.empty.birds.isEmpty)
            #expect(PackLibrary.empty.packs.isEmpty)
            #expect(PackLibrary.empty.photoURL(for: bird) == nil)
            #expect(PackLibrary.empty.callURL(for: bird) == nil)
            #expect(PackLibrary.empty.speechURL(for: bird, sentence: "quiz.prompt.whereIs") == nil)
        }
    }
}

/// One species of a written pack: what it carries besides its photo.
struct Species {
    var id: String
    var call = false
    /// The one sentence key the species has a clip for, `nil` for none.
    var sentence: String?
}

/// Writes packs on disk the way a download leaves them — a manifest beside its
/// media — and opens them.
///
/// Generated rather than copied from a fixture, because a library test needs
/// several packs whose species ids it chooses, and files whose bytes it can
/// tell apart: `bytes(_:_:_:)` names the pack, so an assertion can say *which*
/// pack answered, not merely that somebody did.
enum PackFolder {
    /// The bytes of one medium. Not a real PNG or a playable recording:
    /// nothing here decodes either, and the library only has to find the file.
    static func bytes(_ pack: String, _ bird: String, _ kind: String) -> Data {
        Data("\(pack)/\(bird)/\(kind)".utf8)
    }

    /// Writes `species` below `home/<pack>` and opens the pack.
    static func write(pack id: String, species: [Species], to home: URL) throws -> PackCatalog {
        let directory = home.appending(path: id)
        var birds: [String] = []

        for bird in species {
            var media = try ["photo": file(id, bird.id, "photo", "photos", "png", in: directory)]
            if bird.call {
                media["call"] = try file(id, bird.id, "call", "calls", "m4a", in: directory)
            }
            if let sentence = bird.sentence {
                media["speech"] = try file(
                    id,
                    bird.id,
                    "speech",
                    "speech/\(sentence)",
                    "m4a",
                    in: directory,
                )
            }
            birds.append(manifest(for: bird, media: media))
        }

        let document = Data("""
        {
          "id": "\(id)",
          "title": "Paket \(id)",
          "voice": {
            "license": "CC-BY-4.0",
            "attribution": "Stimme: Niemand",
            "sourceURL": "https://example.org/stimme",
            "retrieved": "2026-09-10"
          },
          "birds": [\(birds.joined(separator: ","))]
        }
        """.utf8)

        return try PackCatalog(
            pack: PackManifest.decode(document),
            directory: directory,
        )
    }

    /// Writes one medium and hands back the `file`/`sha256` pair naming it.
    private static func file(
        _ pack: String,
        _ bird: String,
        _ kind: String,
        _ folder: String,
        _ extension: String,
        in directory: URL,
    ) throws -> (path: String, sha256: String) {
        let path = "\(folder)/\(bird).\(`extension`)"
        let url = directory.appending(path: path)
        let data = bytes(pack, bird, kind)

        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true,
        )
        try data.write(to: url)

        return (path, StubPack.sha256(of: data))
    }

    private static func manifest(
        for bird: Species,
        media: [String: (path: String, sha256: String)],
    ) -> String {
        let speech = bird.sentence.flatMap { sentence in
            media["speech"].map { clip in
                """
                , "speech": { "\(sentence)": {
                  "file": "\(clip.path)", "sha256": "\(clip.sha256)", "text": "Wo ist er?"
                } }
                """
            }
        }

        return """
        {
          "id": "\(bird.id)",
          "name": "\(bird.id.capitalized)",
          "scientificName": "Genus \(bird.id)",
          "taxonID": 1,
          "article": "der",
          "pronunciation": null,
          "photo": \(asset(media["photo"])),
          "call": \(asset(media["call"]))\(speech ?? "")
        }
        """
    }

    private static func asset(_ medium: (path: String, sha256: String)?) -> String {
        guard let medium else { return "null" }
        return """
        {
          "file": "\(medium.path)",
          "sha256": "\(medium.sha256)",
          "license": "CC0-1.0",
          "attribution": "Niemand",
          "sourceURL": "https://example.org/medium",
          "retrieved": "2026-09-10"
        }
        """
    }
}

/// A temporary directory for the packs a test writes, removed afterwards.
func withPacks(_ body: (URL) throws -> Void) throws {
    let home = FileManager.default.temporaryDirectory
        .appending(path: "zilpzalp-library-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: home) }

    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    try body(home)
}
