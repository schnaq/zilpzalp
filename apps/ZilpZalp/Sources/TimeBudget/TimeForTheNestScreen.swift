import SwiftUI
import ZilpZalpUI

/// "Zeit fürs Nest" — screen 1k, where the day ends when the grown-ups set a
/// limit and the child has played it.
///
/// **A close, not a stop.** No countdown, no clock, no minutes, nothing that
/// says what was taken away. What the screen shows is what the day brought:
/// the bird, the sentence, the stars collected since this morning. A child
/// who cannot read hears all of it, because a screen that only writes its
/// news would be a wall to the audience this app is for.
///
/// The round that was under way is always over by the time anybody gets
/// here — the budget is asked between rounds and nowhere else, and
/// `TimeBudget` in `ZilpZalpCore` has no notion of a round to interrupt.
///
/// One way on, and it goes home. No back button and no swipe back: behind
/// this screen is either a finished round's celebration or the home screen
/// that sent the child here, and neither is somewhere to return to.
struct TimeForTheNestScreen: View {
    /// The bird at the top, the 110 pt of screen 1k.
    private static let bird: CGFloat = 110
    private static let compactBird: CGFloat = 72

    /// Stars collected today, across every round and every launch of the app.
    let stars: Int

    /// Home. Not a pop: the round end may be underneath, and going back into
    /// a finished round is not a way out of the day.
    let goHome: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    /// Narrow or short. The same reasoning as on the round end: the two
    /// biggest iPhones report a regular width in landscape and a phone's
    /// height, and the iPad's sizes do not fit into either.
    private var isTight: Bool {
        isCompact || verticalSizeClass == .compact
    }

    var body: some View {
        ScrollView {
            VStack(spacing: isTight ? ZSpacing.step4 : ZSpacing.step6) {
                Icon(.bird, size: .custom(isTight ? Self.compactBird : Self.bird))
                    .foregroundStyle(ZColor.sun300)
                    .accessibilityHidden(true)

                Text("timeBudget.title")
                    .typeStyle(isTight ? .display2 : .hero, .display, weight: .extraBold)
                    .foregroundStyle(ZColor.white)

                Text("timeBudget.farewell")
                    .typeStyle(isTight ? .bodyLarge : .headline, .display, weight: .bold)
                    .foregroundStyle(ZColor.olive100)

                // The day's take as the design draws it: a pill, not a
                // sentence. The sentence is what the screen says out loud.
                Badge(starsToday, tone: .sun, icon: .star)
                    .accessibilityHidden(true)

                // For the grown-up looking over the shoulder, in the one
                // place a child will not read: where the limit came from and
                // therefore where it can be changed.
                Text("timeBudget.setInParents")
                    .typeStyle(.caption, .body, weight: .semibold)
                    .foregroundStyle(ZColor.olive300)

                ZButton(
                    String(localized: "timeBudget.home"),
                    leadingIcon: .house,
                    action: goHome,
                )
                .padding(.top, ZSpacing.step2)
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: ZSpacing.maxContent)
            .padding(.horizontal, isTight ? ZSpacing.step5 : ZSpacing.gutterScreen)
            .padding(.vertical, ZSpacing.step6)
            .frame(maxWidth: .infinity)
        }
        // A stack that does not fit truncates its text rather than offering a
        // way down — the lesson #35 learned on an iPhone in landscape — and
        // the bounce is off where everything already fits.
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ZColor.surfaceForest)
        .overlay(alignment: .bottom) { signature }
        // No `TopBar`: 1k has none, and there is nothing here to go back to.
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .readAloudOnce(spoken)
    }

    /// The wordmark of screen 1k, on the screens with room for it. A phone
    /// gives its height to the bird and the stars instead.
    @ViewBuilder
    private var signature: some View {
        if !isTight {
            Wordmark(size: Wordmark.minimumSize, tone: .monoLight)
                .padding(.bottom, ZSpacing.step5)
        }
    }

    /// "3 Sterne heute" — through the catalog's plural rules, never assembled
    /// here from a number and a noun.
    private var starsToday: String {
        String(format: String(localized: "timeBudget.starsToday"), stars)
    }

    /// What the screen says out loud, once: the headline and the day's take,
    /// in that order. The child this app is for cannot read either of them.
    private var spoken: String {
        String(localized: "timeBudget.title")
            + " "
            + String(format: String(localized: "timeBudget.starsToday.spoken"), stars)
    }
}

// MARK: - Previews

#Preview("iPad", traits: .fixedLayout(width: 1194, height: 834)) {
    NavigationStack {
        TimeForTheNestScreen(stars: 7, goHome: {})
    }
}

#Preview("iPhone", traits: .fixedLayout(width: 390, height: 844)) {
    NavigationStack {
        TimeForTheNestScreen(stars: 1, goHome: {})
    }
}
