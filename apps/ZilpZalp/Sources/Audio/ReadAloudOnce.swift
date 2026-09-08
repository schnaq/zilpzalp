import SwiftUI

/// Reads a screen's headline out loud the first time the screen arrives.
///
/// A child who cannot read cannot be asked a question in writing, nor told
/// news in writing, so a screen that does either has to say it: both profile
/// screens ask a question, and the rank ascent (#29) announces a promotion.
///
/// `onAppear` can fire more than once for the same arrival, so the flag is
/// what makes "once" true. The announcer cuts off whatever it was still
/// saying before it starts, and stops when the screen goes — so a headline
/// can neither repeat itself nor talk over the screen that replaces it.
///
/// It used to live beside its first two callers under `Profiles/` and said
/// it would move here the day a screen outside that folder wanted it. #29 is
/// that day, so it did.
struct ReadAloudOnce: ViewModifier {
    let text: String

    @State private var announcer = SpeechAnnouncer()
    @State private var hasSpoken = false

    func body(content: Content) -> some View {
        content
            .onAppear {
                guard !hasSpoken else { return }
                hasSpoken = true
                announcer.announce(text)
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
