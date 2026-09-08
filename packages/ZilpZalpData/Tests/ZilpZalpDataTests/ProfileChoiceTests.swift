import Foundation
import Testing
@testable import ZilpZalpData

@Suite("Which child a launch opens on")
struct ProfileChoiceTests {
    private static func profile(_ name: String) -> Profile {
        Profile(id: UUID(), name: name, avatar: "bird")
    }

    @Test("Nothing saved yet: the app has to ask")
    func noProfiles() {
        #expect(ProfileChoice.atLaunch(among: [], remembered: nil) == nil)
    }

    @Test("A single child is opened without asking a question with one answer")
    func oneProfile() {
        let only = Self.profile("Mila")

        #expect(ProfileChoice.atLaunch(among: [only], remembered: nil) == only.id)
    }

    @Test("Several children and nobody remembered: the picker")
    func severalProfiles() {
        let profiles = [Self.profile("Mila"), Self.profile("Jonas")]

        #expect(ProfileChoice.atLaunch(among: profiles, remembered: nil) == nil)
    }

    @Test("The remembered child wins over the count, so a restart lands there")
    func rememberedWins() {
        let profiles = [Self.profile("Mila"), Self.profile("Jonas"), Self.profile("Frieda")]
        let jonas = profiles[1].id

        #expect(ProfileChoice.atLaunch(among: profiles, remembered: jonas) == jonas)
    }

    @Test("A remembered child who has been deleted does not select a missing id")
    func rememberedGone() {
        let profiles = [Self.profile("Mila"), Self.profile("Jonas")]

        #expect(ProfileChoice.atLaunch(among: profiles, remembered: UUID()) == nil)
    }

    @Test("A stale id falls back to the count, not to nothing")
    func staleIdFallsBackToTheOnlyChild() {
        let only = Self.profile("Mila")

        #expect(ProfileChoice.atLaunch(among: [only], remembered: UUID()) == only.id)
    }

    @Test("A remembered id cannot conjure a child out of an empty file")
    func rememberedWithNoProfiles() {
        #expect(ProfileChoice.atLaunch(among: [], remembered: UUID()) == nil)
    }
}
