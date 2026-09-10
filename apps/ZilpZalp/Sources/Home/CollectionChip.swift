import SwiftUI
import ZilpZalpUI

/// Which birds this child is playing with, on the home screen, and the way to
/// change it (#187).
///
/// A picture and a word in a pill, 64 pt tall: the photo is what a child who
/// cannot read recognises its collection by, the word is for the grown-up
/// looking over the shoulder, and the chevron says that there is more behind
/// it. It sits between the headline and the game tiles because the collection
/// is what the games below ask about — not among the doors at the foot of the
/// screen, which lead elsewhere.
///
/// **One pill rather than a row of collections.** Five collections need
/// 480 pt at the 96 pt a disc wants; a 390 pt phone leaves 294 pt inside its
/// gutters, so a row would either scroll — hidden content for a child who
/// cannot read — or shrink the discs under the 64 pt touch floor. The pill
/// costs one row and opens ``CollectionPicker``.
struct CollectionChip: View {
    /// The bird whose photo rides in the pill.
    private static let discDiameter: CGFloat = 48

    /// The collection being played with right now — never the stored choice,
    /// always the resolved one, so a deleted pack shows „Alle Vögel" here and
    /// asks for „Alle Vögel" in the round.
    let entry: CollectionEntry

    let openPicker: () -> Void

    var body: some View {
        Button(action: openPicker) {
            HStack(spacing: ZSpacing.step3) {
                disc

                Text(verbatim: entry.title)
                    .typeStyle(.label, .display, weight: .bold, singleLine: true)
                    .foregroundStyle(ZColor.textStrong)
                    // „Unsere ersten Vögel" is the longest title the packs
                    // carry; on the narrowest phone it shrinks rather than
                    // ending in an ellipsis.
                    .minimumScaleFactor(0.6)

                Icon(.chevronRight, size: .small)
                    .foregroundStyle(ZColor.textMuted)
            }
            // 48 pt of photo and 8 pt above and below it: the pill is exactly
            // the 64 pt floor tall, which is what the home screen's height
            // budget was measured against.
            .padding(.vertical, ZSpacing.step2)
            .padding(.horizontal, ZSpacing.step3)
            .background(Capsule().fill(ZColor.surfaceCard))
            .overlay(Capsule().strokeBorder(ZColor.borderCard, lineWidth: ZBorder.width))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            String(
                format: String(localized: "home.collection.change.accessibility"),
                entry.title,
            ),
        )
    }

    /// The collection's bird, or the glyph a sticker falls back to. Drawn here
    /// rather than with `RewardSticker`, which brings a tilt and a shadow that
    /// belong to a sticker in an album and not to a pill.
    private var disc: some View {
        Circle()
            .fill(ZColor.surfaceSunken)
            .overlay {
                if let cover = entry.cover {
                    cover
                        .resizable()
                        .scaledToFill()
                } else {
                    Icon(.bird, size: .standard)
                        .foregroundStyle(ZColor.textMuted)
                }
            }
            .frame(width: Self.discDiameter, height: Self.discDiameter)
            .clipShape(Circle())
            .overlay { Circle().strokeBorder(ZColor.borderCard, lineWidth: ZBorder.width) }
    }
}

#Preview("With a photo and without one") {
    VStack(spacing: ZSpacing.step5) {
        CollectionChip(
            entry: CollectionEntry(id: nil, title: "Alle Vögel", cover: nil),
            openPicker: {},
        )
        CollectionChip(
            entry: CollectionEntry(id: "basis", title: "Unsere ersten Vögel", cover: nil),
            openPicker: {},
        )
    }
    .padding(ZSpacing.step6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}
