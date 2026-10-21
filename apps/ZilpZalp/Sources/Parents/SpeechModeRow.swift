import SwiftUI
import ZilpZalpData
import ZilpZalpUI

/// „Vorlesen" — when the app speaks, in the grown-ups' area (#306).
///
/// Two choices rather than a switch: there is no silent one any more („ganz
/// stumm ist doof"), and the system switch drew its off state in a grey the
/// card all but swallowed, under the 3:1 WCAG 1.4.11 asks of a control. The
/// playtime row's pattern, so the area asks every question one way. The hint
/// is where a grown-up learns that the voice is an AI voice.
struct SpeechModeRow: View {
    let parental: ParentalSettingsModel

    @State private var choosing = false

    var body: some View {
        SettingRow(
            title: String(localized: "parents.speech.title"),
            hint: [CreditsScreen.voiceDisclosure, String(localized: "parents.speech.hint")]
                .compactMap(\.self).joined(separator: " "),
            icon: .volume2,
            value: label(for: parental.settings.speechMode),
        ) {
            choosing = true
        }
        .confirmationDialog(
            "parents.speech.title",
            isPresented: $choosing,
            titleVisibility: .visible,
        ) {
            ForEach(SpeechMode.allCases, id: \.self) { mode in
                Button(label(for: mode)) {
                    parental.set(\.speechMode, to: mode)
                }
            }
            Button("parents.playtime.cancel", role: .cancel) {}
        } message: {
            Text("parents.speech.message")
        }
    }

    /// One mode, in the row and in the dialog, spelt once like the limits.
    private func label(for mode: SpeechMode) -> String {
        switch mode {
        case .automatic: String(localized: "parents.speech.automatic")
        case .onTap: String(localized: "parents.speech.onTap")
        }
    }
}
