import SwiftUI
import ZilpZalpUI

/// A speaker beside a screen's headline: it reads the line out the first time
/// the screen arrives, and again whenever it is tapped.
///
/// A child who cannot read cannot be asked a question in writing, nor told
/// news in writing, so a screen that does either has to say it. Since #306 a
/// grown-up may ask the app not to speak on its own — „Nur auf Knopfdruck" —
/// and then this button is how the child hears the headline at all, so it is
/// on the screen in both modes: one layout whatever the setting, and a way to
/// hear the line again in either.
///
/// `onAppear` can fire more than once for the same arrival, so the flag is
/// what makes "once" true. The announcer cuts off whatever it was still
/// saying before it starts, and stops when the screen goes — so a headline
/// can neither repeat itself nor talk over the screen that replaces it.
///
/// The announcer is optional and built on first use: a `@State` default is
/// evaluated again every time the view struct is rebuilt, and would allocate
/// an `AVSpeechSynthesizer` per rebuild only to throw it away.
struct ReadAloudButton: View {
    let line: SpokenLine

    /// No pack: a headline a screen reads out belongs to no species, so
    /// this announcer only ever looks in the fixed set.
    @State private var announcer: SpeechAnnouncer?
    @State private var hasSpoken = false

    var body: some View {
        IconButton(
            .volume2,
            label: String(format: String(localized: "speech.readAloud.accessibility"), line.text),
            tone: .accent,
            // The touch floor rather than the 96 pt mid-game size: beside a
            // headline the speaker must not outweigh the words.
            diameter: ZSpacing.touchMinimum,
        ) {
            say(unprompted: false)
        }
        .onAppear {
            guard !hasSpoken else { return }
            hasSpoken = true
            say(unprompted: true)
        }
        .onDisappear { announcer?.stop() }
    }

    private func say(unprompted: Bool) {
        let voice = announcer ?? SpeechAnnouncer()
        announcer = voice
        voice.announce(line, unprompted: unprompted)
    }
}
