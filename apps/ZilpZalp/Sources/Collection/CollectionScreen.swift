import SwiftUI
import ZilpZalpCore
import ZilpZalpData
import ZilpZalpUI

/// "Johannas Sammlung" — screen 2d: every bird of the pack as a sticker, the
/// ones already met in colour and the rest still waiting.
///
/// **The album belongs to one child, and says so.** Its headline is that
/// child's name and their avatar, not "Meine Sammlung" (#204): a device is
/// passed around a family, and whoever holds it should see at a glance whose
/// birds these are. The door to the album keeps the words a child taps —
/// "Sammlung" on the home screen and at the round end.
///
/// **What has been found stands at the top.** Inside the two groups the
/// manifest's order survives, so a bird a child looked for yesterday is where
/// they left it (#204).
///
/// **A species not yet found stays on the page.** Grey, straight, padlocked,
/// and keeping its photo, exactly as `RewardSticker` draws a locked one. An
/// album that hid what is missing would be a full album on the first day and
/// would never say what is still out there; the whole point of a sticker album
/// is the gap.
///
/// **A bird on its way shows how far it has come.** Under a locked sticker
/// stand as many markers as the child's sticker takes — three or five (#260)
/// — filled as often as the child has recognised that bird (#177), so the
/// album says "nearly" as well as "not yet", which is the difference between
/// a gap and a goal.
///
/// Tapping a bird already collected says its name out loud, because the child
/// this album is for cannot read the word under it. A locked one says „Noch
/// geheim" — its name is the thing still to be found.
///
/// **A collected bird has a lightbulb on its corner that says one fact about
/// it** — „Bei der Amsel ist der Papa ganz schwarz und hat einen gelben
/// Schnabel." Its own button rather than a second sentence after the name
/// (Christian, 2026-11-14): a tap on the sticker still says the name and
/// nothing else. Only where the pack has written a fact for the bird.
struct CollectionScreen: View {
    /// The progress markers under a locked sticker, sized so that five of them
    /// and their gaps stay inside the disc above: 104 pt under a 128 pt
    /// sticker, 76 under an 80 pt one.
    private static let markerSize: CGFloat = 16
    private static let compactMarkerSize: CGFloat = 12

    /// The lightbulb on a collected sticker: a small sticker of its own, so it
    /// covers the rim of the photo and not the bird framed in its middle. A
    /// quarter of the disc on the phone, a third of it on the iPad. The target
    /// around it is ``ZSpacing/touchMinimum`` either way.
    private static let factBadge: CGFloat = 44
    private static let compactFactBadge: CGFloat = 32

    /// The avatar leading the headline, a little taller than the line of type
    /// beside it: 64 pt against the iPad's 48 pt display-2, 44 pt against the
    /// phone's 28 pt headline. Big enough to be the child's own picture from
    /// across the table, small enough to stay part of the line rather than a
    /// second thing above it. `SwarmList` draws its rows at 72/56, where the
    /// avatar is the row's subject and not its ornament.
    private static let titleAvatar: CGFloat = 64
    private static let compactTitleAvatar: CGFloat = 44

    /// The child whose album this is.
    let profile: Profile
    /// Every species that can be collected — the bundled pack and every
    /// downloaded one. Empty when no pack opened, which leaves the grid empty
    /// rather than the screen broken.
    let library: PackLibrary
    let photos: SpeciesPhotos
    /// Everybody who plays on this device, for "Unser Schwarm".
    let profiles: [Profile]
    let goBack: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Says a bird's name when its sticker is tapped. One announcer for the
    /// screen, so two quick taps cannot talk over each other.
    ///
    /// Built on the first tap rather than with the screen, because it needs
    /// the packs the recorded names lie in: handing `@State` an initial value
    /// that reads ``library`` would mean writing this screen's six-parameter
    /// initialiser out by hand, and the previews below use the synthesised
    /// one. ``RoundEndScreen`` builds its announcer the same way.
    @State private var announcer: SpeechAnnouncer?

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private var birds: [Bird] {
        library.birds
    }

    /// Whether this child has earned `bird`'s sticker. The screen's one
    /// question, asked by the count, by the order and by the sticker itself,
    /// so the three of them cannot answer it differently.
    private func isCollected(_ bird: Bird) -> Bool {
        profile.hasSticker(for: bird.id)
    }

    private var collected: [Bird] {
        birds.filter(isCollected)
    }

    /// The birds in the order the album shows them: everything found first,
    /// the manifest's order kept inside each group (#204).
    private var albumBirds: [Bird] {
        AlbumOrder.earnedFirst(birds, earned: isCollected)
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

    /// Whose album this is: the child's avatar and their name in the genitive
    /// (#204). ``GermanName`` forms the word, the String Catalog holds the
    /// sentence it goes into.
    ///
    /// In the page rather than in the top bar: a phone gives the bar's centre
    /// a third of a narrow row, and even "Meine Sammlung" broke across three
    /// lines in it — a name in front of it has no chance there. `TopBar`'s own
    /// note says a kid screen keeps its centre wordless, and the design draws
    /// the title as an h1 on the page.
    ///
    /// Two lines and a scale factor, because the name is as long as a grown-up
    /// typed it: 20 characters is what `ProfileCreationScreen` allows, and
    /// "Charlotte-Antoinettes Sammlung" needs both on a 375 pt phone. Three
    /// lines would push the badges under the fold on the smallest screen.
    private var title: some View {
        HStack(spacing: isCompact ? ZSpacing.step3 : ZSpacing.step4) {
            AvatarDisc(
                style: .avatar(profile.avatar),
                diameter: isCompact ? Self.compactTitleAvatar : Self.titleAvatar,
            )

            Text(
                verbatim: String(
                    format: String(localized: "collection.album.title"),
                    GermanName.possessive(of: profile.name),
                ),
            )
            .typeStyle(isCompact ? .headline : .display2, .display, weight: .extraBold)
            .foregroundStyle(ZColor.textStrong)
            .multilineTextAlignment(.leading)
            .lineLimit(2)
            .minimumScaleFactor(0.7)
        }
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
                        .adaptive(minimum: StickerGrid.column(compact: isCompact)),
                        spacing: StickerGrid.spacing(compact: isCompact),
                        alignment: .top,
                    ),
                ],
                spacing: StickerGrid.spacing(compact: isCompact),
            ) {
                ForEach(albumBirds, id: \.id) { bird in
                    sticker(bird)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    /// One sticker, and a button either way. A collected one says its own
    /// name, and its lightbulb its fact; the rest say „Noch geheim", what
    /// their caption reads — so a child that taps a padlock is answered rather
    /// than met with silence it might read as a broken screen, and still not
    /// told the name it has to earn.
    @ViewBuilder
    private func sticker(_ bird: Bird) -> some View {
        let found = isCollected(bird)
        let size = StickerGrid.size(compact: isCompact)

        if found {
            Button {
                say(.name(bird))
            } label: {
                StickerCaption(caption: bird.name, earned: true) {
                    RewardSticker(image: photos[bird.id], size: size)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(bird.name)
            .overlay(alignment: .top) {
                if let fact = SpokenLine.fact(bird) {
                    factButton(fact, about: bird, sticker: size)
                }
            }
        } else {
            Button {
                say(.fixed("collection.locked"))
            } label: {
                VStack(spacing: ZSpacing.step2) {
                    StickerCaption(caption: String(localized: "collection.locked"), earned: false) {
                        RewardSticker(image: photos[bird.id], locked: true, size: size)
                    }

                    StickerMarkers(
                        count: profile.recognitions[bird.id, default: 0],
                        threshold: profile.stickerThreshold,
                        markerSize: isCompact ? Self.compactMarkerSize : Self.markerSize,
                    )
                }
                .accessibilityElement(children: .combine)
            }
            .buttonStyle(.plain)
        }
    }

    /// The lightbulb that says a collected bird's fact, on a tap only.
    ///
    /// The lightbulb because it is a picture: a child who cannot read meets it
    /// on the hint banner of a round already, as "here is something to know".
    /// Not `info`, the ⓘ of the sketch — an „i" is a letter, and on the home
    /// screen it is the grown-ups' door to „Über ZilpZalp". Not a speaker
    /// either: the sticker itself already speaks when tapped.
    ///
    /// A ``GlyphBadge`` rather than an ``IconButton``, which never draws below
    /// 64 pt and would hide most of a phone's 80 pt sticker. The badge stays
    /// small and the button around it keeps the full 64 pt target. A sibling
    /// of the sticker's button rather than inside its label, like the pencil
    /// on a profile card, so the two taps never compete.
    ///
    /// Anchored to the disc, not to the caption, whose width follows the name:
    /// from the disc's top centre out towards its top-right corner, so the
    /// badge sits on the rim of the photo.
    private func factButton(
        _ fact: SpokenLine,
        about bird: Bird,
        sticker size: CGFloat,
    ) -> some View {
        Button {
            say(fact)
        } label: {
            GlyphBadge(
                .lightbulb,
                diameter: isCompact ? Self.compactFactBadge : Self.factBadge,
                rotation: .degrees(8),
            )
            .frame(width: ZSpacing.touchMinimum, height: ZSpacing.touchMinimum)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(
            format: String(localized: "collection.fact.accessibility"),
            bird.name,
        ))
        .offset(x: size * 0.42, y: size * 0.08 - ZSpacing.touchMinimum / 2)
    }

    /// Says one line, building the announcer the first time something is
    /// tapped. Kept afterwards, so the second tap cuts the first one off
    /// instead of talking over it.
    private func say(_ line: SpokenLine) {
        let voice = announcer ?? SpeechAnnouncer(library: library)
        announcer = voice
        voice.announce(line, unprompted: false)
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
            library: (try? .bundled()) ?? .empty,
            photos: SpeciesPhotos((try? .bundled()) ?? .empty),
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
            library: (try? .bundled()) ?? .empty,
            photos: SpeciesPhotos((try? .bundled()) ?? .empty),
            profiles: [],
            goBack: {},
        )
    }
    .environment(\.horizontalSizeClass, .compact)
}
