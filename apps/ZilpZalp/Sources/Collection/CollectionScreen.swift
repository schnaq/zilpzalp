import SwiftUI
import ZilpZalpCore
import ZilpZalpData
import ZilpZalpUI

/// "Meine Sammlung" — screen 2d: every bird of the pack as a sticker, the ones
/// already met in colour and the rest still waiting.
///
/// **A species not yet found stays on the page.** Grey, straight, padlocked,
/// and keeping its photo, exactly as `RewardSticker` draws a locked one. An
/// album that hid what is missing would be a full album on the first day and
/// would never say what is still out there; the whole point of a sticker album
/// is the gap.
///
/// Tapping a bird already collected says its name out loud, because the child
/// this album is for cannot read the word under it. A locked one says nothing
/// — its name is the thing still to be found.
struct CollectionScreen: View {
    /// The sticker's disc, and how wide a column may get before another
    /// sticker fits beside it. Four across on an iPad, three on a phone.
    private static let stickerSize: CGFloat = 128
    private static let compactStickerSize: CGFloat = 96
    private static let stickerColumn: CGFloat = 168
    private static let compactStickerColumn: CGFloat = 108

    /// The child whose album this is.
    let profile: Profile
    /// Every species that can be collected — the bundled pack, and later the
    /// downloaded ones. `nil` when no pack opened, which leaves the grid empty
    /// rather than the screen broken.
    let catalog: PackCatalog?
    let photos: SpeciesPhotos
    /// Everybody who plays on this device, for "Unser Schwarm".
    let profiles: [Profile]
    let openLadder: () -> Void
    let goBack: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Says a bird's name when its sticker is tapped. One synthesiser for the
    /// screen, so two quick taps cannot talk over each other.
    @State private var announcer = SpeechAnnouncer()

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private var birds: [Bird] {
        catalog?.pack.birds ?? []
    }

    private var collected: [Bird] {
        birds.filter { profile.collectedSpecies.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBar {
                IconButton(
                    .chevronLeft,
                    label: String(localized: "nav.back.accessibility"),
                    diameter: ZSpacing.touchMinimum,
                    action: goBack,
                )
            } center: {
                Text("collection.title")
            }

            ScrollView {
                VStack(spacing: ZSpacing.step7) {
                    summary
                    album
                    SwarmList(profiles: profiles, activeProfileID: profile.id)
                }
                .frame(maxWidth: ZSpacing.maxContent)
                .padding(.horizontal, isCompact ? ZSpacing.step4 : ZSpacing.gutterScreen)
                .padding(.vertical, ZSpacing.step6)
                .frame(maxWidth: .infinity)
            }
        }
        .background(ZColor.surfacePage)
        .toolbar(.hidden, for: .navigationBar)
        .navigationBarBackButtonHidden()
        .onDisappear { announcer.stop() }
    }

    /// What the album adds up to, and the door to the ladder.
    ///
    /// Two counts and a rank — never a percentage and never a "3 von 10",
    /// which is the same sentence with the missing ones put first.
    private var summary: some View {
        VStack(spacing: ZSpacing.step4) {
            HStack(spacing: ZSpacing.step3) {
                Badge(
                    String(format: String(localized: "collection.birds"), collected.count),
                    tone: .leaf,
                    icon: .album,
                )
                Badge(
                    String(format: String(localized: "collection.stars"), profile.totalStars),
                    tone: .sun,
                    icon: .star,
                )
            }

            ZButton(
                String(localized: "rank.ladder.title"),
                tone: .quiet,
                size: .medium,
                trailingIcon: .chevronRight,
                action: openLadder,
            )
        }
    }

    private var album: some View {
        ZCard {
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(
                            minimum: isCompact ? Self.compactStickerColumn : Self.stickerColumn,
                        ),
                        spacing: ZSpacing.gapTiles,
                        alignment: .top,
                    ),
                ],
                spacing: ZSpacing.gapTiles,
            ) {
                ForEach(birds, id: \.id) { bird in
                    sticker(bird)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// One sticker. Collected ones are buttons that say their own name; the
    /// rest are pictures, so a child that taps a padlock is not answered with
    /// silence it might read as a broken screen — it is answered with a
    /// picture that plainly is not one of the bright ones.
    @ViewBuilder
    private func sticker(_ bird: Bird) -> some View {
        let isCollected = profile.collectedSpecies.contains(bird.id)
        let size = isCompact ? Self.compactStickerSize : Self.stickerSize

        if isCollected {
            Button {
                announcer.announce(bird.pronunciation ?? bird.name)
            } label: {
                RewardSticker(image: photos[bird.id], label: bird.name, size: size)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(bird.name)
        } else {
            RewardSticker(
                image: photos[bird.id],
                label: String(localized: "collection.locked"),
                locked: true,
                size: size,
            )
        }
    }
}

// MARK: - Previews

private func albumProfile() -> Profile {
    Profile(
        id: UUID(),
        name: "Mia",
        avatar: "star",
        totalStars: 57,
        roundsPlayed: 21,
        collectedSpecies: ["amsel", "kohlmeise", "rotkehlchen", "zilpzalp"],
    )
}

#Preview("iPad, four found", traits: .fixedLayout(width: 1194, height: 834)) {
    NavigationStack {
        CollectionScreen(
            profile: albumProfile(),
            catalog: try? .bundled(),
            photos: SpeciesPhotos(try? .bundled()),
            profiles: [albumProfile()],
            openLadder: {},
            goBack: {},
        )
    }
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("iPhone, nothing found yet", traits: .fixedLayout(width: 390, height: 844)) {
    NavigationStack {
        CollectionScreen(
            profile: Profile(id: UUID(), name: "Jonas", avatar: "bird"),
            catalog: try? .bundled(),
            photos: SpeciesPhotos(try? .bundled()),
            profiles: [],
            openLadder: {},
            goBack: {},
        )
    }
    .environment(\.horizontalSizeClass, .compact)
}
