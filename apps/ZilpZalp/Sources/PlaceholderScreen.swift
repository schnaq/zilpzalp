import SwiftUI
import ZilpZalpUI

/// A screen the shell can already reach and nobody has built yet: its name,
/// its glyph and the way back.
///
/// Scaffolding, on purpose. It carries no state and no logic, so that the
/// navigation can be walked end to end in M3 without anything here having to
/// be unpicked later. ``QuizScreen`` (#25) dropped its use of it with the real
/// quiz; the last one left is the credits inside the grown-ups' area, which
/// #37 fills — and this file goes with it.
struct PlaceholderScreen: View {
    let title: String
    let icon: ZIcon

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // The name sits in the page rather than in the bar's centre slot:
            // with nothing in the trailing slot the bar has nothing to
            // balance against, and a title drifting to the right edge would
            // be the placeholder's bug, not the bar's.
            TopBar {
                IconButton(
                    .chevronLeft,
                    label: String(localized: "nav.back.accessibility"),
                    diameter: ZSpacing.touchMinimum,
                ) { dismiss() }
            }

            VStack(spacing: ZSpacing.step6) {
                Icon(icon, size: .custom(ZSpacing.touchHero))
                Text(verbatim: title)
                    .typeStyle(.title, .display, weight: .bold)
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(ZColor.textMuted)
            .padding(ZSpacing.gutterScreen)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(ZColor.surfacePage)
        // Every screen brings its own `TopBar`; the system bar would stack a
        // second, smaller back button above it.
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    NavigationStack {
        PlaceholderScreen(title: "Wer ist das?", icon: .bird)
    }
}
