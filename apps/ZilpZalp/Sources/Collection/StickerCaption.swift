import SwiftUI
import ZilpZalpUI

/// A sticker with its name under it, for the album.
///
/// `RewardSticker` draws a caption of its own, and this is deliberately not
/// that one: the component caps its label at the disc's width plus 40 pt and
/// truncates, so "Rotkehlchen" came out as "Rotkehlc…" on a phone. A bird
/// whose name a child cannot read in full is not collected, so here the name
/// shrinks instead.
///
/// The honest fix is a `minimumScaleFactor` inside `RewardSticker`, which is
/// a change to a shared package with callers this pull request does not own —
/// **follow-up for #11**, alongside the caption tone #26 already filed there.
/// Until then this is the one copy of the workaround rather than one per
/// screen.
struct StickerCaption<Sticker: View>: View {
    /// The finished word under the disc: a bird's name, or "Noch geheim" for
    /// one still to be found.
    let caption: String

    /// Whether the thing above the caption has been earned. Muted ink when it
    /// has not, the same greying a locked ``RewardSticker`` wears.
    let earned: Bool

    @ViewBuilder let sticker: Sticker

    var body: some View {
        VStack(spacing: ZSpacing.step2) {
            sticker

            Text(verbatim: caption)
                .typeStyle(.body, .display, weight: .bold, singleLine: true)
                .foregroundStyle(earned ? ZColor.textStrong : ZColor.textMuted)
                .minimumScaleFactor(0.6)
        }
    }
}

#Preview("A name that fits, and one that has to shrink") {
    HStack(spacing: ZSpacing.step6) {
        StickerCaption(caption: "Amsel", earned: true) {
            RewardSticker(icon: .bird, size: 96)
        }
        StickerCaption(caption: "Rotkehlchen", earned: true) {
            RewardSticker(icon: .bird, size: 96)
        }
        StickerCaption(caption: "Noch geheim", earned: false) {
            RewardSticker(icon: .bird, locked: true, size: 96)
        }
    }
    .padding(ZSpacing.step7)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}
