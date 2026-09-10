import Foundation
import Testing

// @testable for the internal pack initialiser `PackFolder.write` uses.
@testable import ZilpZalpData

/// The one sentence key three sides of the project have to agree on: the app
/// that asks for it, the manifests that declare it, and the tool that renders
/// the clips.
@Suite("The key a bird's name is recorded under")
struct SpeechKeyTests {
    /// The rule itself: a pack that declares a clip under
    /// ``SpeechKey/speciesName`` is what the app finds when it asks for a
    /// bird's name. Written through ``PackFolder`` rather than asserted
    /// against a literal, so the key travels from the manifest to the lookup
    /// exactly as it does in a real pack.
    @Test("a pack's name clip is what the lookup finds")
    func findsTheNameClip() throws {
        try withPacks { home in
            let pack = try PackFolder.write(
                pack: "basis",
                species: [Species(id: "amsel", sentence: SpeechKey.speciesName)],
                to: home,
            )
            let amsel = try #require(pack.pack.birds.first { $0.id == "amsel" })
            let clips = SpeechClips(library: PackLibrary([pack]), fixed: nil)

            let url = try #require(clips.url(for: SpeechKey.speciesName, about: amsel))
            #expect(try Data(contentsOf: url) == PackFolder.bytes("basis", "amsel", "speech"))
        }
    }

    /// The name belongs to a species and is recorded per pack, so the fixed
    /// set must never answer for it — a single "Amsel" shipped inside the app
    /// would be said for every bird.
    @Test("the name is never a fixed sentence")
    func staysOutOfTheFixedSet() throws {
        let clips = try SpeechClips(library: .empty, fixed: SpeechFixtures.fixedSet())

        #expect(clips.url(for: SpeechKey.speciesName, about: nil) == nil)
    }

    /// The clips are already rendered under this string —
    /// `speech/collection.name/<species>.m4a` in every manifest and in
    /// `tools/fetch_media/speech` (#221). Changing the constant without
    /// re-rendering them would leave every bird silent, so the literal is
    /// pinned here rather than left to a rename to carry.
    @Test("the key is the one the render tool writes")
    func pinsTheRenderedKey() {
        #expect(SpeechKey.speciesName == "collection.name")
    }
}
