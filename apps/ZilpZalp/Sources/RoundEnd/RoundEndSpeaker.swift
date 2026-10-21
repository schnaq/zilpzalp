import SwiftUI
import ZilpZalpUI

/// The praise again, in the round end's top-right corner — the house's
/// opposite number (#306).
///
/// The only way to hear the praise at all where the grown-ups chose „Nur auf
/// Knopfdruck", and a way to hear it again everywhere else. A corner for the
/// reason the house has one: the headline is already 1.2 pt short of a 390 pt
/// phone (#137), and a speaker beside it would shrink it further. Same size,
/// same gutters as ``RoundEndHomeDoor``, so the two corners mirror each other.
struct RoundEndSpeaker: View {
    let say: () -> Void

    var body: some View {
        SpeakerButton(line: .fixed("roundEnd.title"), action: say)
            .roundEndCorner()
    }
}
