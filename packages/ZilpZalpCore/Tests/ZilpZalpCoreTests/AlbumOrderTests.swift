import Testing
import ZilpZalpCore

@Test("What has been found comes first, everything else keeps its place")
func earnedFirstMovesOnlyTheGroups() {
    let birds = ["amsel", "blaumeise", "rotkehlchen", "star", "zilpzalp"]
    let earned: Set<String> = ["rotkehlchen", "star"]

    #expect(
        AlbumOrder.earnedFirst(birds) { earned.contains($0) }
            == ["rotkehlchen", "star", "amsel", "blaumeise", "zilpzalp"],
    )
}

@Test("An album with nothing found yet is the manifest, unchanged")
func earnedFirstWithNothingEarned() {
    let birds = ["amsel", "blaumeise", "rotkehlchen"]

    #expect(AlbumOrder.earnedFirst(birds) { _ in false } == birds)
}

@Test("A full album is the manifest, unchanged")
func earnedFirstWithEverythingEarned() {
    let birds = ["amsel", "blaumeise", "rotkehlchen"]

    #expect(AlbumOrder.earnedFirst(birds) { _ in true } == birds)
}

@Test("An empty album has nothing to sort")
func earnedFirstWithNoBirds() {
    #expect(AlbumOrder.earnedFirst([String]()) { _ in true }.isEmpty)
}
