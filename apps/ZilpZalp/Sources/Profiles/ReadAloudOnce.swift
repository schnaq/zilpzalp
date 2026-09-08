import SwiftUI

/// Reads a screen's headline out loud the first time the screen arrives.
///
/// A child who cannot read cannot be asked a question in writing, so a screen
/// that asks one has to say it. Both profile screens ask one.
///
/// `onAppear` can fire more than once for the same arrival, so the flag is
/// what makes "once" true. The announcer cuts off whatever it was still
/// saying before it starts, and stops when the screen goes — so a headline
/// can neither repeat itself nor talk over the screen that replaces it.
///
/// Lives beside its two callers. The day a screen outside this folder wants
/// it, it belongs next to ``SpeechAnnouncer`` in `Audio/`.
struct ReadAloudOnce: ViewModifier {
    let text: String

    @State private var announcer = SpeechAnnouncer()
    @State private var hasSpoken = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !hasSpoken else { return }
                hasSpoken = true
                announcer.say(text)
            }
            .onDisappear { announcer.stop() }
    }
}

extension View {
    /// Speaks `text` when this view first appears. See ``ReadAloudOnce``.
    func readAloudOnce(_ text: String) -> some View {
        modifier(ReadAloudOnce(text: text))
    }
}
