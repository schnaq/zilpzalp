import SwiftUI
import ZilpZalpData

// The previews of ``RoundEndScreen``, in their own file: the screen itself
// sits on SwiftLint's 400-line ceiling, and a fixture is the part of it that
// no child ever sees.

/// A finished round for the previews. The id is fresh every time, as it is in
/// a real round.
private func previewResult(
    firstTryCorrect: Int,
    celebrating species: String?,
) -> RoundResult {
    RoundResult(
        id: UUID(),
        firstTryCorrect: firstTryCorrect,
        questionCount: 10,
        celebratedSpecies: species,
        species: Set([species].compactMap(\.self)),
        playtime: 214,
    )
}

/// A profile that has just been given the round, so the previews show the
/// screen as a child meets it rather than as it looks before the store
/// answers.
private func previewOutcome(collecting species: String?) -> RoundOutcome {
    let before = Profile(id: UUID(), name: "Mia", avatar: "star", totalStars: 20)
    var after = before
    after.totalStars += 3
    after.roundsPlayed += 1
    after.collectedSpecies.formUnion([species].compactMap(\.self))
    return RoundOutcome(before: before, after: after)
}

#Preview("iPad, three stars and a first find", traits: .fixedLayout(width: 1194, height: 834)) {
    NavigationStack {
        RoundEndScreen(
            result: previewResult(firstTryCorrect: 10, celebrating: "amsel"),
            catalog: try? PackCatalog.bundled(),
            record: { _ in previewOutcome(collecting: "amsel") },
            playAgain: {},
            openCollection: {},
            showAscent: { _ in },
            goHome: {},
        )
    }
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("iPhone, one star, bird already known", traits: .fixedLayout(width: 390, height: 844)) {
    NavigationStack {
        RoundEndScreen(
            result: previewResult(firstTryCorrect: 3, celebrating: "rotkehlchen"),
            catalog: try? PackCatalog.bundled(),
            record: { _ in previewOutcome(collecting: nil) },
            playAgain: {},
            openCollection: {},
            showAscent: { _ in },
            goHome: {},
        )
    }
    .environment(\.horizontalSizeClass, .compact)
}

#Preview("Without a pack", traits: .fixedLayout(width: 1194, height: 834)) {
    NavigationStack {
        RoundEndScreen(
            result: previewResult(firstTryCorrect: 7, celebrating: nil),
            catalog: nil,
            record: { _ in nil },
            playAgain: {},
            openCollection: {},
            showAscent: { _ in },
            goHome: {},
        )
    }
    .environment(\.horizontalSizeClass, .regular)
}
