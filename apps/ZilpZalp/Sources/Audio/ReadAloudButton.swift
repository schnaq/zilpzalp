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
///
/// Several lines are said one after the other — „Zeit fürs Nest" says its
/// headline, its farewell and the day's stars, each its own recording.
///
/// `speaksOnAppear: false` is a speaker that only answers a tap: on a card or
/// a subheading, where the screen's headline already speaks on arrival and a
/// second line on its own would cut the first one off.
struct ReadAloudButton: View {
    let lines: [SpokenLine]
    var speaksOnAppear = true

    /// No pack: a headline a screen reads out belongs to no species, so
    /// this announcer only ever looks in the fixed set.
    @State private var announcer: SpeechAnnouncer?
    @State private var hasSpoken = false

    var body: some View {
        SpeakerButton(text: lines.map(\.text).joined(separator: " ")) { say(unprompted: false) }
            .onAppear {
                guard speaksOnAppear, !hasSpoken else { return }
                hasSpoken = true
                say(unprompted: true)
            }
            .onDisappear { announcer?.stop() }
    }

    private func say(unprompted: Bool) {
        // Not even an announcer for a line that is not to be said.
        guard SpeechAnnouncer.mode.speaks(unprompted: unprompted) else { return }
        let voice = announcer ?? SpeechAnnouncer()
        announcer = voice
        voice.announce(lines, unprompted: unprompted)
    }
}

extension ReadAloudButton {
    init(line: SpokenLine, speaksOnAppear: Bool = true) {
        self.init(lines: [line], speaksOnAppear: speaksOnAppear)
    }
}

/// The speaker itself, for a screen that speaks through an announcer of its
/// own — the collection picker, the round end — and for ``ReadAloudButton``.
/// One size, one tone and one label for every speaker a child looks for.
struct SpeakerButton: View {
    /// What a tap says, named in the VoiceOver label.
    let text: String
    let action: () -> Void

    var body: some View {
        IconButton(
            .volume2,
            label: String(format: String(localized: "speech.readAloud.accessibility"), text),
            tone: .accent,
            // The touch floor rather than the 96 pt mid-game size: beside a
            // headline the speaker must not outweigh the words.
            diameter: ZSpacing.touchMinimum,
            action: action,
        )
    }
}
