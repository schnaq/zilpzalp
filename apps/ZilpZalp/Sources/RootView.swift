import SwiftUI
import ZilpZalpUI

/// The app's one navigation stack: whichever screen the launch lands on at the
/// root, everything else pushed onto it.
///
/// Every screen brings its own ``TopBar``, so the system navigation bar stays
/// hidden throughout — a back chevron a child can hit is 64 pt across and sits
/// where the design puts it, not where UIKit does.
struct RootView: View {
    @State private var model = AppModel()
    @State private var path: [Route] = []

    /// Every species photo of the opened pack, read once at launch.
    ///
    /// The album draws a whole page of stickers, and a `View` is rebuilt on
    /// every layout pass. Opening the files here means the screen is handed
    /// pictures rather than a directory.
    @State private var photos = SpeciesPhotos(nil)

    /// How often "Nochmal spielen" has taken a child back into the quiz.
    ///
    /// The pop is not what deals the next round — ``QuizScreen`` does that,
    /// and it used to learn of the pop by being told it had appeared again.
    /// It is not always told: a tap that lands while the round end is still
    /// being pushed reverses that push before it is over, and SwiftUI then
    /// sends the screen underneath neither the disappearance nor the
    /// appearance. Without this number the finished round would stay up with
    /// all ten leaves green, and since nothing about it ever changed again, no
    /// round end would come either (#157). This one changes with the pop
    /// itself, whatever the animation makes of it.
    @State private var roundsAskedFor = 0

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
                    // "Nochmal spielen" pops back to the quiz screen still
                    // under this one. What makes sure a fresh round is dealt
                    // there is `roundsAskedFor` — see there.
                    // The catalog travels with the result: the round end
                    // draws a sticker of one of the round's species, and a
                    // `RoundResult` on a navigation path can carry the id but
                    // not the photo.
                    case let .roundEnd(result):
                        RoundEndScreen(
                            result: result,
                            catalog: model.catalog,
                            record: { await model.record($0) },
                            playAgain: playAnotherRound,
                            openCollection: { path.append(.collection) },
                        )
                    case .parents: ParentsScreen(parental: model.parental)
                    case .collection: collection
                    case .timeForTheNest:
                        // All the way home rather than back one: under this
                        // screen is either the celebration of the round that
                        // used the last minute or the home screen that sent
                        // the child here, and neither is a way out of the day.
                        TimeForTheNestScreen(stars: model.starsToday) { path.removeAll() }
                    }
                }
        }
        .task {
            photos = SpeciesPhotos(model.catalog)
            await model.load()
        }
    }

    /// The album belongs to a child, and every route to it starts on a screen
    /// only a chosen child can reach. The failure branch is unreachable for
    /// the same reason the quiz's is, and is a sentence rather than a `!`.
    @ViewBuilder
    private var collection: some View {
        if let profile = model.activeProfile {
            CollectionScreen(
                profile: profile,
                catalog: model.catalog,
                photos: photos,
                profiles: model.profiles,
                goBack: { path.removeLast() },
            )
        } else {
            CalmFailure(message: "profile.store.failed")
        }
    }

    /// A game needs the pack the round is drawn from. The home screen is only
    /// reachable with one open, so the failure branch is unreachable — and it
    /// is the same sentence rather than a `!`, because an unreachable crash on
    /// a child's iPad is still a crash.
    @ViewBuilder
    private func quiz(_ game: Game) -> some View {
        if let catalog = model.catalog {
            QuizScreen(
                game: game,
                catalog: catalog,
                askedFor: roundsAskedFor,
                onFinished: { path.append(.roundEnd($0)) },
            )
        } else {
            CalmFailure(message: "app.pack.failed")
        }
    }

    /// What the root is, in the order the answers rule each other out: a
    /// broken build first, then a broken profile file, then the moment before
    /// the profiles are known, then the child who is playing — and if there is
    /// none, the question who that should be.
    @ViewBuilder
    private var start: some View {
        if model.catalog == nil {
            CalmFailure(message: "app.pack.failed")
        } else if model.storeFailed {
            CalmFailure(message: "profile.store.failed")
        } else if !model.isLoaded {
            // At most a frame: this is a small file on the local disk. The
            // page's own ground rather than a spinner — there is nothing here
            // to wait for, only something not to flicker.
            ZColor.surfacePage
        } else if let profile = model.activeProfile {
            HomeScreen(
                avatar: profile.avatar,
                games: model.games,
                openGame: openGame(_:),
                openParents: { path.append(.parents) },
                openProfiles: { model.chooseAgain() },
                openCollection: { path.append(.collection) },
            )
        } else {
            ProfileFlow(model: model)
        }
    }

    /// A tapped game tile: the round, or the day's close when the budget is
    /// spent (#36).
    ///
    /// The question is asked here rather than on the home screen, which draws
    /// the tiles it is handed and knows nothing about limits — and asked on the
    /// tap rather than once on appearance, so a day that turns over while the
    /// app is open is noticed by the next tap and by nothing else.
    private func openGame(_ game: Game) {
        path.append(model.timeBudget.isExhausted ? .timeForTheNest : .quiz(game))
    }

    /// "Nochmal spielen": back into the quiz, unless the round that just
    /// ended used the last of the day.
    ///
    /// ``RoundEndScreen`` books the round on arrival, so by the time a hand
    /// has reached this button the seconds it took are counted here. Only in
    /// practice, not by construction: the button is live from the first frame
    /// while the write is still in flight, so a tap inside those few
    /// milliseconds would ask about the day before the round. It would cost
    /// one more round and the next check would see the truth — which is why
    /// the guard is not worth disabling the way on for a frame.
    ///
    /// **This is the only place the budget can end play**, and it does so
    /// between two rounds; nothing asks it while a question is up.
    private func playAnotherRound() {
        // The way on is taken once, however often the button is hit. No
        // device here delivered the second tap of a double tap — the first
        // one's pop swallowed it every time — but that is an observation and
        // not a promise, and a second one arriving would pop the quiz away
        // under the round it had just dealt, or empty the path and trap.
        guard case .roundEnd = path.last else { return }

        if model.timeBudget.isExhausted {
            path.append(.timeForTheNest)
        } else {
            // Counted in this branch alone. A day that is over leads to the
            // nest with the finished round still behind it, and a round dealt
            // and spoken under that screen would be a round nobody asked for.
            roundsAskedFor += 1
            path.removeLast()
        }
    }
}

/// What the app shows when something it cannot work without did not open — a
/// broken bundled pack, or a profile file that will not decode. Both take a
/// broken build or a damaged device to reach.
///
/// A sentence on the page rather than an alert with an OK button: whoever ends
/// up here is a grown-up, and there is nothing for a child to acknowledge.
private struct CalmFailure: View {
    let message: LocalizedStringKey

    var body: some View {
        Text(message)
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
    CalmFailure(message: "app.pack.failed")
}

#Preview("Profiles could not be read") {
    CalmFailure(message: "profile.store.failed")
}
