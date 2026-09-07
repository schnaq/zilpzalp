import SwiftUI

/// Replaced by #25 — the real quiz screen for iPhone and iPad.
///
/// The route exists so that the shell can be walked from the home screen into
/// a game and back while the game itself is being built. It deliberately holds
/// no round, no scoring and no photos: whatever it did today, #25 would throw
/// away tomorrow.
struct QuizScreen: View {
    let game: Game

    var body: some View {
        PlaceholderScreen(title: game.title, icon: .bird)
    }
}

#Preview {
    NavigationStack {
        QuizScreen(game: .names)
    }
}
