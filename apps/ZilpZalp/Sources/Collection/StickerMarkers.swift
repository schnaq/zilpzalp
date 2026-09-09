import SwiftUI
import ZilpZalpCore
import ZilpZalpUI

/// The row of markers under a bird that says how far it has come towards its
/// sticker (#177).
///
/// The app's own view over ``StickerProgress``, because three things have to
/// meet and each of them lives somewhere else: how many recognitions a sticker
/// takes is `Scoring` in `ZilpZalpCore`, the sentence VoiceOver reads is in the
/// String Catalog, and the drawing is a component that carries neither. Here
/// rather than twice over, so the album and the round end cannot end up
/// showing different rows.
struct StickerMarkers: View {
    /// How often the bird has been recognised, as the profile counts it. Past
    /// five is a full row and a sentence that still says five — the one place
    /// on this side of the design system where that is decided, so no screen
    /// has to clamp before it asks.
    let count: Int

    /// Diameter of one marker, chosen by the screen from the sticker it sits
    /// under.
    var markerSize: CGFloat = StickerProgress.defaultMarkerSize

    var body: some View {
        StickerProgress(
            count: count,
            of: Scoring.recognitionsForSticker,
            label: String(
                format: String(localized: "sticker.progress"),
                min(count, Scoring.recognitionsForSticker),
                Scoring.recognitionsForSticker,
            ),
            markerSize: markerSize,
        )
    }
}

#Preview("Nothing, part of the way, and done") {
    VStack(spacing: ZSpacing.step5) {
        StickerMarkers(count: 0)
        StickerMarkers(count: 3)
        StickerMarkers(count: 5)
        StickerMarkers(count: 2, markerSize: 12)
    }
    .padding(ZSpacing.step6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}
