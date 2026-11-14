import SwiftUI
import ZilpZalpUI

/// How hard this child's rounds are, on the home screen, and the way to change
/// it: ``DifficultyPicker``. Built exactly like ``CollectionChip``, so the two
/// pills read as one kind of thing.
///
/// The picture is the level's quartet as a bare mosaic, so a child who cannot
/// read finds on the pill the very birds it tapped in the picker. No
/// binoculars on it: at 48 pt a sticker would cover the look-alike it is
/// meant to count.
struct DifficultyChip: View {
    /// The size of ``CollectionChip``'s disc, so the two pills stand level.
    private static let mosaicSize: CGFloat = 48

    /// The level being played right now.
    let level: DifficultyLevel

    /// Whether the level's name stands beside the picture. The home screen
    /// drops it on a phone — see ``HomeScreen``.
    let showsTitle: Bool

    let openPicker: () -> Void

    var body: some View {
        Button(action: openPicker) {
            HStack(spacing: ZSpacing.step3) {
                PhotoQuartet(photos: level.photos, size: Self.mosaicSize, style: .mosaic)

                if showsTitle {
                    Text(verbatim: level.title)
                        .typeStyle(.label, .display, weight: .bold, singleLine: true)
                        .foregroundStyle(ZColor.textStrong)
                }

                Icon(.chevronRight, size: .small)
                    .foregroundStyle(ZColor.textMuted)
            }
            // `CollectionChip`'s paddings: 48 pt of picture and 8 pt above and
            // below it make the 64 pt floor exactly.
            .padding(.vertical, ZSpacing.step2)
            .padding(.horizontal, ZSpacing.step3)
            .background(Capsule().fill(ZColor.surfaceCard))
            .overlay(Capsule().strokeBorder(ZColor.borderCard, lineWidth: ZBorder.width))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            String(
                format: String(localized: "home.difficulty.change.accessibility"),
                level.title,
            ),
        )
    }
}

#Preview("With and without the name") {
    VStack(spacing: ZSpacing.step5) {
        ForEach(DifficultyLevel.previews) { level in
            HStack(spacing: ZSpacing.step3) {
                DifficultyChip(level: level, showsTitle: true, openPicker: {})
                DifficultyChip(level: level, showsTitle: false, openPicker: {})
            }
        }
    }
    .padding(ZSpacing.step6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}
