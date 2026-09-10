import Foundation
import Testing
@testable import ZilpZalpData

/// The branch behind everything the app says out loud: a recorded clip, or the
/// synthesiser. It is asserted here, without a simulator, because the app
/// target has no tests — the announcer that plays the file is a few lines of
/// AVFoundation on top of these answers.
@Suite("Clip or synthesiser")
struct SpeechClipsTests {
    @Test("a sentence about a species is the pack's")
    func resolvesASpeciesSentence() throws {
        let pack = try SpeechFixtures.speakingPack()
        let clips = try SpeechClips(library: PackLibrary([pack]), fixed: SpeechFixtures.fixedSet())
        let amsel = try #require(pack.pack.birds.first { $0.id == "amsel" })

        let url = try #require(clips.url(for: "quiz.prompt.whereIs", about: amsel))
        #expect(try sha256(of: url) == amsel.speech?["quiz.prompt.whereIs"]?.sha256)
    }

    @Test("a sentence about no species is the fixed set's")
    func resolvesAFixedSentence() throws {
        let clips = try SpeechClips(
            library: PackLibrary([SpeechFixtures.speakingPack()]),
            fixed: SpeechFixtures.fixedSet(),
        )

        let url = try #require(clips.url(for: "roundEnd.title", about: nil))
        #expect(url.lastPathComponent == "silence.m4a")
    }

    /// The two key sets are disjoint, and asking the other catalog could only
    /// find a recording of a different sentence. Both crossings come back nil,
    /// so the caller speaks the words instead.
    @Test("neither catalog answers for the other's sentences")
    func keepsTheTwoSetsApart() throws {
        let pack = try SpeechFixtures.speakingPack()
        let clips = try SpeechClips(library: PackLibrary([pack]), fixed: SpeechFixtures.fixedSet())
        let amsel = try #require(pack.pack.birds.first { $0.id == "amsel" })

        #expect(clips.url(for: "roundEnd.title", about: amsel) == nil)
        #expect(clips.url(for: "quiz.prompt.whereIs", about: nil) == nil)
    }

    /// What every screen that says only fixed sentences carries — the parental
    /// gate, both profile screens, the rank ascent — and what a build whose
    /// bundled pack did not open is left with.
    @Test("the fixed sentences still resolve without a pack")
    func resolvesWithoutAPack() throws {
        let pack = try SpeechFixtures.speakingPack()
        let clips = try SpeechClips(library: .empty, fixed: SpeechFixtures.fixedSet())
        let amsel = try #require(pack.pack.birds.first { $0.id == "amsel" })

        #expect(clips.url(for: "roundEnd.title", about: nil) != nil)
        #expect(clips.url(for: "quiz.prompt.whereIs", about: amsel) == nil)
    }

    /// The state the app ships in today, and the one the plan insists must
    /// stay playable: nothing is recorded, so every sentence falls to the
    /// synthesiser and none of them is silence.
    @Test("nothing resolves while nothing is recorded")
    func resolvesNothingWithoutClips() throws {
        let pack = try SpeechFixtures.speakingPack()
        let clips = SpeechClips(library: .empty, fixed: nil)
        let amsel = try #require(pack.pack.birds.first { $0.id == "amsel" })

        #expect(clips.url(for: "roundEnd.title", about: nil) == nil)
        #expect(clips.url(for: "quiz.prompt.whereIs", about: amsel) == nil)
    }

    /// A clip a manifest declares and no file backs — the pack fixture's
    /// `collection.name` — is the same nil as a sentence nobody declared. Both
    /// catalogs answer that way; this asserts the choice does not hide it.
    @Test("a declared clip that is not on disk is not a clip")
    func resolvesNothingForAMissingFile() throws {
        let pack = try SpeechFixtures.speakingPack()
        let clips = try SpeechClips(library: PackLibrary([pack]), fixed: SpeechFixtures.fixedSet())
        let amsel = try #require(pack.pack.birds.first { $0.id == "amsel" })

        #expect(amsel.speech?["collection.name"] != nil)
        #expect(clips.url(for: "collection.name", about: amsel) == nil)
        #expect(clips.url(for: "gate.spoken", about: nil) == nil)
    }

    // MARK: - The switch (#231)

    /// The one thing the switch has to do: a recording that is right there on
    /// disk is not played either. Off means silence, not "the synthesiser
    /// instead of the recording".
    @Test("the switch silences a sentence that has a recording")
    func silencesARecordedSentence() throws {
        let pack = try SpeechFixtures.speakingPack()
        let clips = try SpeechClips(library: PackLibrary([pack]), fixed: SpeechFixtures.fixedSet())
        let amsel = try #require(pack.pack.birds.first { $0.id == "amsel" })

        #expect(clips.url(for: "quiz.prompt.whereIs", about: amsel) != nil)
        #expect(
            clips.decision(for: "quiz.prompt.whereIs", about: amsel, speechEnabled: false)
                == .silent,
        )
    }

    /// And the sentences that would have gone to the synthesiser — which is
    /// every sentence the app ships with today.
    @Test("the switch silences a sentence nobody recorded")
    func silencesAnUnrecordedSentence() {
        let clips = SpeechClips(library: .empty, fixed: nil)

        #expect(clips.decision(for: "gate.spoken", about: nil, speechEnabled: false) == .silent)
        #expect(clips.decision(for: nil, about: nil, speechEnabled: false) == .silent)
    }

    @Test("switched on, a recorded sentence is its recording")
    func playsTheClipWhileSwitchedOn() throws {
        let pack = try SpeechFixtures.speakingPack()
        let clips = try SpeechClips(library: PackLibrary([pack]), fixed: SpeechFixtures.fixedSet())
        let amsel = try #require(pack.pack.birds.first { $0.id == "amsel" })

        let expected = try #require(clips.url(for: "quiz.prompt.whereIs", about: amsel))
        #expect(
            clips.decision(for: "quiz.prompt.whereIs", about: amsel, speechEnabled: true)
                == .clip(expected),
        )
    }

    /// Both halves of "no recording": a sentence nobody has recorded, and the
    /// assembled line that carries no key at all.
    @Test("switched on, everything else is read out")
    func synthesisesTheRestWhileSwitchedOn() {
        let clips = SpeechClips(library: .empty, fixed: nil)

        #expect(
            clips.decision(for: "gate.spoken", about: nil, speechEnabled: true) == .synthesise,
        )
        #expect(clips.decision(for: nil, about: nil, speechEnabled: true) == .synthesise)
    }
}
