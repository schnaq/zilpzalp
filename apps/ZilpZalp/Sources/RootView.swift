import SwiftUI
import ZilpZalpUI

/// The app's one navigation stack: the home screen at the root, everything
/// else pushed onto it.
///
/// Every screen brings its own ``TopBar``, so the system navigation bar stays
/// hidden throughout — a back chevron a child can hit is 64 pt across and sits
/// where the design puts it, not where UIKit does.
struct RootView: View {
    @State private var model = AppModel()
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            start
                // Hiding the bar is per screen, not per stack: a pushed view
                // brings its own back button back unless it says otherwise.
                // The destinations do so themselves.
                .toolbar(.hidden, for: .navigationBar)
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case let .quiz(game): quiz(game)
                    // Popping is all "Nochmal spielen" needs to do: the quiz
                    // screen is still under this one and deals a fresh round
                    // when it comes back with a finished one behind it.
                    case let .roundEnd(result):
                        RoundEndScreen(result: result) { path.removeLast() }
                    case .parents: ParentsScreen()
                    }
                }
        }
    }

    /// A game needs the pack the round is drawn from. The home screen is only
    /// reachable with one open, so the failure branch is unreachable — and it
    /// is the same sentence rather than a `!`, because an unreachable crash on
    /// a child's iPad is still a crash.
    @ViewBuilder
    private func quiz(_ game: Game) -> some View {
        if let catalog = model.catalog {
            QuizScreen(game: game, catalog: catalog) { path.append(.roundEnd($0)) }
        } else {
            PackFailure()
        }
    }

    @ViewBuilder
    private var start: some View {
        if model.catalog == nil {
            PackFailure()
        } else {
            HomeScreen(
                openGame: { path.append(.quiz($0)) },
                openParents: { path.append(.parents) },
            )
        }
    }
}

/// What the app shows when the bundled pack could not be opened — a state that
/// takes a broken build to reach.
///
/// A sentence on the page rather than an alert with an OK button: whoever ends
/// up here is a grown-up, and there is nothing for a child to acknowledge.
private struct PackFailure: View {
    var body: some View {
        Text("app.pack.failed")
            .typeStyle(.bodyLarge, .body, weight: .regular)
            .foregroundStyle(ZColor.textBody)
            .multilineTextAlignment(.center)
            .padding(ZSpacing.gutterScreen)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ZColor.surfacePage)
    }
}

#Preview("Shell") {
    RootView()
}

#Preview("Pack could not be opened") {
    PackFailure()
}
