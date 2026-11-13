import SwiftUI
import ZilpZalpCore
import ZilpZalpData

// The previews of ``QuizScreen``, in their own file, exactly as
// ``RoundEndScreen``'s are: the screen itself sits on SwiftLint's 400-line
// ceiling, and three fixed layouts of the same fixture are the part of it that
// no child ever sees.

@MainActor
@ViewBuilder
private func quizPreview(
    _ sizeClass: UserInterfaceSizeClass,
    difficulty: Difficulty = .standard,
) -> some View {
    if let library = try? PackLibrary.bundled() {
        NavigationStack {
            QuizScreen(
                game: .names,
                difficulty: difficulty,
                library: library,
                askedFor: 0,
                player: { nil },
                onFinished: { _ in },
            )
        }
        .environment(\.horizontalSizeClass, sizeClass)
    } else {
        Text(verbatim: "The bundled pack did not open.")
    }
}

#Preview("iPad landscape", traits: .fixedLayout(width: 1194, height: 834)) {
    quizPreview(.regular)
}

#Preview("iPad portrait", traits: .fixedLayout(width: 834, height: 1194)) {
    quizPreview(.regular)
}

#Preview("iPhone portrait", traits: .fixedLayout(width: 390, height: 844)) {
    quizPreview(.compact)
}

// Which question of a hard round is tricky is the deal's to say and a preview
// cannot pick it: five of the ten are, so the binoculars show up on about every
// other refresh of this one.
#Preview("iPad landscape, hard", traits: .fixedLayout(width: 1194, height: 834)) {
    quizPreview(.regular, difficulty: .hard)
}
