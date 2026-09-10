import SwiftUI
import ZilpZalpData

// The previews of ``RoundEndScreen``, in their own file: the screen itself
// sits on SwiftLint's 400-line ceiling, and a fixture is the part of it that
// no child ever sees.

/// A finished round for the previews. The id is fresh every time, as it is in
/// a real round.
///
/// The recognitions carry the stars as well: every one of them is an answer
/// right at the first attempt, so two birds known five times over is a
/// three-star round.
private func previewResult(
    recognising recognitions: [String: Int],
    celebrating species: String?,
) -> RoundResult {
    RoundResult(
        id: UUID(),
        questionCount: 10,
        celebratedSpecies: species,
        recognitions: recognitions,
        playtime: 214,
    )
}

/// A profile that has just been given the round, so the previews show the
/// screen as a child meets it rather than as it looks before the store
/// answers.
///
/// - Parameter recognised: how often the celebrated bird had been recognised
///   before the round. Four makes this round the fifth and the sticker new;
///   less than that leaves the row of markers part-filled.
private func previewOutcome(of species: String?, recognised: Int) -> RoundOutcome {
    var before = Profile(id: UUID(), name: "Mia", avatar: "star", totalStars: 20)
    var after = before
    if let species {
        before.recognitions[species] = recognised
        after = before
        after.recognitions[species, default: 0] += 1
    }
    after.totalStars += 3
    after.roundsPlayed += 1
    return RoundOutcome(before: before, after: after)
}

#Preview("iPad, three stars and a new sticker", traits: .fixedLayout(width: 1194, height: 834)) {
    NavigationStack {
        RoundEndScreen(
            result: previewResult(
                recognising: ["amsel": 5, "kohlmeise": 5],
                celebrating: "amsel",
            ),
            library: (try? PackLibrary.bundled()) ?? .empty,
            record: { _ in previewOutcome(of: "amsel", recognised: 4) },
            playAgain: {},
            openCollection: {},
            goHome: {},
        )
    }
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("iPhone, one star, two of five", traits: .fixedLayout(width: 390, height: 844)) {
    NavigationStack {
        RoundEndScreen(
            result: previewResult(
                recognising: ["rotkehlchen": 2, "amsel": 1],
                celebrating: "rotkehlchen",
            ),
            library: (try? PackLibrary.bundled()) ?? .empty,
            record: { _ in previewOutcome(of: "rotkehlchen", recognised: 1) },
            playAgain: {},
            openCollection: {},
            goHome: {},
        )
    }
    .environment(\.horizontalSizeClass, .compact)
}

#Preview("Without a pack", traits: .fixedLayout(width: 1194, height: 834)) {
    NavigationStack {
        RoundEndScreen(
            result: previewResult(recognising: ["amsel": 7], celebrating: nil),
            library: .empty,
            record: { _ in nil },
            playAgain: {},
            openCollection: {},
            goHome: {},
        )
    }
    .environment(\.horizontalSizeClass, .regular)
}
