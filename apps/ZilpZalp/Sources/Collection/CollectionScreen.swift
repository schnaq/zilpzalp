import SwiftUI
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
/// **A bird on its way shows how far it has come.** Under a locked sticker
/// stand five markers, filled as often as the child has recognised that bird
/// (#177) — so the album says "nearly" as well as "not yet", which is the
/// difference between a gap and a goal.
///
/// Tapping a bird already collected says its name out loud, because the child
/// this album is for cannot read the word under it. A locked one says nothing
/// — its name is the thing still to be found.
struct CollectionScreen: View {
    /// The sticker's disc, and how wide a column may get before another
    /// sticker fits beside it. Four across on an iPad, three on a phone.
    private static let stickerSize: CGFloat = 128
    private static let compactStickerSize: CGFloat = 80
    private static let stickerColumn: CGFloat = 168
    private static let compactStickerColumn: CGFloat = 88

    /// The progress markers under a locked sticker, sized so that five of them
    /// and their gaps stay inside the disc above: 104 pt under a 128 pt
    /// sticker, 76 under an 80 pt one.
    private static let markerSize: CGFloat = 16
    private static let compactMarkerSize: CGFloat = 12

    /// The child whose album this is.
    let profile: Profile
    /// Every species that can be collected — the bundled pack, and later the
    /// downloaded ones. `nil` when no pack opened, which leaves the grid empty
    /// rather than the screen broken.
    let catalog: PackCatalog?
    let photos: SpeciesPhotos
    /// Everybody who plays on this device, for "Unser Schwarm".
    let profiles: [Profile]
    let goBack: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Says a bird's name when its sticker is tapped. One announcer for the
    /// screen, so two quick taps cannot talk over each other.
    ///
    /// Built on the first tap rather than with the screen, because it needs
    /// the pack the recorded names lie in: handing `@State` an initial value
    /// that reads ``catalog`` would mean writing this screen's six-parameter
    /// initialiser out by hand, and the previews below use the synthesised
    /// one. ``RoundEndScreen`` builds its announcer the same way.
    @State private var announcer: SpeechAnnouncer?

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private var birds: [Bird] {
        catalog?.pack.birds ?? []
    }

    private var collected: [Bird] {
        birds.filter { profile.hasSticker(for: $0.id) }
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
            }

            ScrollView {
                VStack(spacing: ZSpacing.step7) {
                    title
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
        // The album has a back chevron, so it has the gesture that goes with
        // one (#150).
        .swipesBack(.pops)
        .onDisappear { announcer?.stop() }
    }

    /// The album's name, in the page rather than in the top bar: a phone
    /// gives the bar's centre a third of a narrow row, and "Meine Sammlung"
    /// broke across three lines in it. `TopBar`'s own note says a kid screen
    /// keeps its centre wordless, and the design draws the title as an h1 on
    /// the page.
    private var title: some View {
        Text("collection.title")
            .typeStyle(isCompact ? .headline : .display2, .display, weight: .extraBold)
            .foregroundStyle(ZColor.textStrong)
            .multilineTextAlignment(.center)
    }

    /// What the album adds up to: the birds found and the stars collected.
    ///
    /// Two counts — never a percentage and never a "3 von 10", which is the
    /// same sentence with the missing ones put first.
    private var summary: some View {
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
    }

    private var album: some View {
        ZCard {
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(
                            minimum: isCompact ? Self.compactStickerColumn : Self.stickerColumn,
                        ),
                        spacing: gridSpacing,
                        alignment: .top,
                    ),
                ],
                spacing: gridSpacing,
            ) {
                ForEach(birds, id: \.id) { bird in
                    sticker(bird)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// Three stickers across on a 375 pt phone rather than two, which is what
    /// the design's grid reads as. The gap gives way before the sticker does.
    private var gridSpacing: CGFloat {
        isCompact ? ZSpacing.step3 : ZSpacing.gapTiles
    }

    /// One sticker. Collected ones are buttons that say their own name; the
    /// rest are pictures, so a child that taps a padlock is not answered with
    /// silence it might read as a broken screen — it is answered with a
    /// picture that plainly is not one of the bright ones.
    @ViewBuilder
    private func sticker(_ bird: Bird) -> some View {
        let isCollected = profile.hasSticker(for: bird.id)
        let size = isCompact ? Self.compactStickerSize : Self.stickerSize

        if isCollected {
            Button {
                say(.name(bird))
            } label: {
                StickerCaption(caption: bird.name, earned: true) {
                    RewardSticker(image: photos[bird.id], size: size)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(bird.name)
        } else {
            VStack(spacing: ZSpacing.step2) {
                StickerCaption(caption: String(localized: "collection.locked"), earned: false) {
                    RewardSticker(image: photos[bird.id], locked: true, size: size)
                }

                StickerMarkers(
                    count: profile.recognitions[bird.id, default: 0],
                    markerSize: isCompact ? Self.compactMarkerSize : Self.markerSize,
                )
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// Says one line, building the announcer the first time something is
    /// tapped. Kept afterwards, so the second tap cuts the first one off
    /// instead of talking over it.
    private func say(_ line: SpokenLine) {
        let voice = announcer ?? SpeechAnnouncer(pack: catalog)
        announcer = voice
        voice.announce(line)
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
        recognitions: ["amsel": 7, "kohlmeise": 5, "rotkehlchen": 5, "zilpzalp": 5],
    )
}

#Preview("iPad, four found", traits: .fixedLayout(width: 1194, height: 834)) {
    NavigationStack {
        CollectionScreen(
            profile: albumProfile(),
            catalog: try? .bundled(),
            photos: SpeciesPhotos(try? .bundled()),
            profiles: [albumProfile()],
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
            goBack: {},
        )
    }
    .environment(\.horizontalSizeClass, .compact)
}
