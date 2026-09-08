import SwiftUI
import ZilpZalpData
import ZilpZalpUI

/// "Wer spielt heute?" — screen 1f, one card per child and one for a new one.
///
/// The card is the whole target, not the disc inside it: a two-year-old aims
/// at a picture, not at a button, and the picture is the middle of a card that
/// is 200 pt across on an iPad and never below the 64 pt floor anywhere.
///
/// A child who cannot read finds their own card by the avatar and its colour —
/// see ``AvatarStyle`` for why no two of them share one. The name underneath is
/// for the grown-up and for the older sibling, and nothing depends on it.
///
/// The screen holds no state beyond having spoken. Which child was picked is
/// ``AppModel``'s business.
struct ProfilePickerScreen: View {
    /// The card's minimum width, from screen 1f's 230 pt. The grid is
    /// adaptive, so this is what decides how many cards fit in a row: four on
    /// an iPad in landscape, two on an iPhone.
    private static let cardWidth: CGFloat = 200

    /// Narrower in a compact width, so an iPhone still gets two cards side by
    /// side rather than one enormous one per row.
    ///
    /// 120 rather than 140 because of the shortest screen the app supports: an
    /// iPhone SE is 375 pt wide, which leaves 279 pt inside the screen gutter,
    /// and two 140 pt cards with the gap between them want 304. The picker
    /// fell to a single column there — and a child who has to scroll to find
    /// their own face is being asked to read the order instead of seeing it.
    private static let compactCardWidth: CGFloat = 120

    /// The avatar inside the card. 1f draws 120 pt.
    private static let discDiameter: CGFloat = 120
    private static let compactDiscDiameter: CGFloat = 88

    /// The wordmark in the top bar, from 1f.
    private static let wordmarkSize: CGFloat = 52

    let profiles: [Profile]
    let choose: (Profile.ID) -> Void
    let createNew: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(center: {
                Wordmark(size: isCompact ? Wordmark.minimumSize : Self.wordmarkSize)
            })

            // Scrolls because a family may have more children than fit: four
            // cards and a nest fill an iPad row, a sixth starts a second one.
            ScrollView {
                VStack(spacing: ZSpacing.step7) {
                    Text("profile.picker.title")
                        .typeStyle(
                            isCompact ? .headline : .display1,
                            .display,
                            weight: .extraBold,
                        )
                        .foregroundStyle(ZColor.textStrong)
                        .multilineTextAlignment(.center)

                    cards
                }
                .frame(maxWidth: ZSpacing.maxContent)
                .padding(.horizontal, ZSpacing.gutterScreen)
                .padding(.vertical, ZSpacing.step6)
                .frame(maxWidth: .infinity)
            }
        }
        .background(ZColor.surfacePage)
        .readAloudOnce(String(localized: "profile.picker.title"))
    }

    private var cards: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(minimum: isCompact ? Self.compactCardWidth : Self.cardWidth),
                    spacing: ZSpacing.gapTiles,
                ),
            ],
            spacing: ZSpacing.gapTiles,
        ) {
            ForEach(profiles) { profile in
                card(
                    style: .avatar(profile.avatar),
                    title: Text(verbatim: profile.name),
                    ink: ZColor.textStrong,
                ) {
                    choose(profile.id)
                }
            }

            card(
                style: .newNest,
                title: Text("profile.picker.new"),
                tone: .sand,
                ink: ZColor.textBody,
                action: createNew,
            )
        }
    }

    /// One card: a disc, a word, and the whole thing pressable.
    private func card(
        style: AvatarStyle,
        title: Text,
        tone: ZCardTone = .paper,
        ink: Color,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            // Less air inside the card in a compact width: at two columns on a
            // 375 pt screen the column is 127 pt, and the design's own padding
            // would leave the 88 pt disc less room than it needs and push the
            // card back out over its column.
            ZCard(tone: tone, padding: isCompact ? ZSpacing.step4 : ZSpacing.step5) {
                VStack(spacing: ZSpacing.step3) {
                    AvatarDisc(
                        style: style,
                        diameter: isCompact ? Self.compactDiscDiameter : Self.discDiameter,
                    )

                    title
                        .typeStyle(
                            isCompact ? .label : .title,
                            .display,
                            weight: .bold,
                            singleLine: true,
                        )
                        .foregroundStyle(ink)
                        // A name longer than the card shrinks rather than
                        // turning into "Maximilia…" — a child looking for
                        // their own name needs its end as much as its start.
                        .minimumScaleFactor(0.6)
                }
                // The card is far bigger than this everywhere; the floor is
                // here so that no future layout can quietly go under it.
                .frame(maxWidth: .infinity, minHeight: ZSpacing.touchMinimum)
            }
        }
        // The card is already a picture with an outline; a button style would
        // draw a second one over it. Its label is the name inside it.
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

private func previewProfiles() -> [Profile] {
    [
        Profile(id: UUID(), name: "Mila", avatar: "feather"),
        Profile(id: UUID(), name: "Jonas", avatar: "star"),
        Profile(id: UUID(), name: "Frieda", avatar: "sparkles"),
    ]
}

#Preview("iPad landscape", traits: .fixedLayout(width: 1194, height: 834)) {
    ProfilePickerScreen(profiles: previewProfiles(), choose: { _ in }, createNew: {})
        .environment(\.horizontalSizeClass, .regular)
}

#Preview("iPhone portrait", traits: .fixedLayout(width: 390, height: 844)) {
    ProfilePickerScreen(profiles: previewProfiles(), choose: { _ in }, createNew: {})
        .environment(\.horizontalSizeClass, .compact)
}
