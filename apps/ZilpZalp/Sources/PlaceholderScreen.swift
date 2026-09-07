import SwiftUI
import ZilpZalpUI

/// A screen the shell can already reach and nobody has built yet: its title,
/// its glyph and the way back.
///
/// Scaffolding, on purpose. It carries no state and no logic, so that the
/// navigation can be walked end to end in M3 without anything here having to
/// be unpicked later. ``QuizScreen`` (#25) and ``ParentsScreen`` (#35) each
/// drop their use of it when the real screen lands; with the second of them
/// this file goes too.
struct PlaceholderScreen: View {
    let title: String
    let icon: ZIcon

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            TopBar {
                IconButton(
                    .chevronLeft,
                    label: String(localized: "nav.back.accessibility"),
                    diameter: ZSpacing.touchMinimum,
                ) { dismiss() }
            } center: {
                Text(verbatim: title)
            }

            Icon(icon, size: .custom(ZSpacing.touchHero))
                .foregroundStyle(ZColor.sand400)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(ZColor.surfacePage)
    }
}

#Preview {
    NavigationStack {
        PlaceholderScreen(title: "Wer ist das?", icon: .bird)
    }
}
