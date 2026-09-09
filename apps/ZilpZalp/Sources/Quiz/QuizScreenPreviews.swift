import SwiftUI
import ZilpZalpData

// The previews of ``QuizScreen``, in their own file, exactly as
// ``RoundEndScreen``'s are: the screen itself sits on SwiftLint's 400-line
// ceiling, and three fixed layouts of the same fixture are the part of it that
// no child ever sees.

@MainActor
@ViewBuilder
private func quizPreview(_ sizeClass: UserInterfaceSizeClass) -> some View {
    if let catalog = try? PackCatalog.bundled() {
        NavigationStack {
            QuizScreen(
                game: .names,
                catalog: catalog,
                askedFor: 0,
                recognitions: { [:] },
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
