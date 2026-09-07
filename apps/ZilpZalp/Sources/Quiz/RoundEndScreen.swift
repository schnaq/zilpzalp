import SwiftUI
import ZilpZalpUI

/// **The seam #26 replaces.** A round is over and this says so, in the plainest
/// way that still closes the loop: how many stars, and a way back into a new
/// round.
///
/// Deliberately not the reward screen. #26 builds that — the earned stars
/// bouncing in one by one, the rank, the "Sammlung" door that stays inert
/// until M4. Everything here is scaffolding for the navigation the quiz screen
/// needs to have somewhere to go, and every line of it is expected to be
/// thrown away rather than extended.
///
/// The star count is written as a numeral on purpose *because* this is a
/// placeholder: the real screen draws stars, and a child who cannot read must
/// never be shown a digit as the reward. Do not carry this `Text` forward.
struct RoundEndScreen: View {
    let result: RoundResult
    /// Pops back to ``QuizScreen``, which starts a fresh round when it
    /// reappears with a finished one behind it.
    let playAgain: () -> Void

    var body: some View {
        VStack(spacing: ZSpacing.step6) {
            Text("roundEnd.title")
                .typeStyle(.display2, .display, weight: .extraBold)
                .foregroundStyle(ZColor.textStrong)

            Text(
                String(
                    format: String(localized: "roundEnd.stars"),
                    result.stars,
                    result.firstTryCorrect,
                    result.questionCount,
                ),
            )
            .typeStyle(.bodyLarge, .body, weight: .regular)
            .foregroundStyle(ZColor.textMuted)

            ZButton(
                String(localized: "roundEnd.playAgain"),
                trailingIcon: .rotateCcw,
                action: playAgain,
            )
        }
        .multilineTextAlignment(.center)
        .padding(ZSpacing.gutterScreen)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ZColor.surfacePage)
        // Every screen brings its own header; #26's will be a `TopBar`. There
        // is nothing to go back to from here but a new round.
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
    }
}

#Preview {
    NavigationStack {
        RoundEndScreen(
            result: RoundResult(firstTryCorrect: 9, questionCount: 10),
            playAgain: {},
        )
    }
}
