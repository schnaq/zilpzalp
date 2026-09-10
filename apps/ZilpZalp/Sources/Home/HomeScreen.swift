import SwiftUI
import ZilpZalpUI

/// Where every session starts: the headline, and one tile per game.
///
/// Deliberately not the tree from `design/ui_kits/ipad_app/HomeScreen.jsx`.
/// Christian dropped it on 2026-09-07 — the metaphor did not come across —
/// together with the locked nests for games 3 and 4. Those two games are out
/// of v1 for want of freely licensed material (spec §1), and nobody can say
/// what a child would be waiting for, so they are absent rather than teased.
/// The same rule now covers game 2 wherever its calls cannot be played (#31):
/// one tile per playable game on the plain page ground, and nothing else.
///
/// The screen holds no state. It reports which game was tapped and which of
/// the doors around them was opened — the grown-ups' room, the album, the
/// screen about the app, the question who is playing; where those lead is
/// ``RootView``'s business.
struct HomeScreen: View {
    /// The wordmark's size in the top bar, from `HomeScreen.jsx`. In a compact
    /// width it drops to the wordmark's own floor.
    private static let wordmarkSize: CGFloat = 44

    /// The playing child's avatar, drawn in the top bar as the way back to
    /// "Wer spielt heute?". A raw `Profile.avatar` string — ``AvatarStyle``
    /// decides what it looks like, including when it names something this
    /// build has never heard of.
    let avatar: String

    /// The games to draw a tile for, in the order they are drawn. Which games
    /// those are is ``AppModel/games``; this screen lays out what it is handed
    /// and lays out one tile as readily as two.
    let games: [Game]

    let openGame: (Game) -> Void
    let openParents: () -> Void

    /// „Über ZilpZalp" (#199), the one door on this screen that leads to
    /// words rather than to a game. Where its button sits, and why not in the
    /// top bar beside the lock, is ``album``.
    let openAbout: () -> Void

    let openProfiles: () -> Void

    /// What there is to choose between, „Alle Vögel" first — empty while one
    /// pack alone is installed, and then the screen looks exactly as it did
    /// before #187.
    let collections: [CollectionEntry]

    /// The collection being played with, resolved. See ``CollectionChip``.
    let chosenCollection: String?

    let chooseCollection: (String?) -> Void

    /// The sticker album. Its own door at the foot of the screen, where every
    /// variant of the design puts it (`design/ui_kits/ipad_app/HomeScreen.jsx`
    /// and screens 1a and 1b): a child who wants to look at its birds should
    /// not have to play a round to get to them.
    let openCollection: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// What the headline and the collection pill turned out to need, so the
    /// tiles can be sized against the rest. It depends on the width and the
    /// font and never on the tiles, so there is no loop here — one extra
    /// layout pass and it settles.
    @State private var introHeight: CGFloat = 0

    /// Whether the collections are up. See ``CollectionPicker``.
    @State private var isPicking = false

    /// Whether the screen is in a compact width — a phone in portrait, or an
    /// iPad sharing its screen. It settles the two type sizes only; where the
    /// tiles go is measured rather than categorised, see ``tiles(in:)``.
    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBar {
                Wordmark(size: isCompact ? Wordmark.minimumSize : Self.wordmarkSize)
            } trailing: {
                // Both doors that lead away from the games share this corner:
                // handing the iPad to the next child, and the grown-ups' room.
                HStack(spacing: ZSpacing.step3) {
                    Button(action: openProfiles) {
                        AvatarDisc(style: .avatar(avatar), diameter: ZSpacing.touchMinimum)
                    }
                    // The disc draws its own outline; a button style would put
                    // a second shape around it.
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(localized: "profile.switch.accessibility"))

                    IconButton(
                        .userRoundCog,
                        label: String(localized: "parents.title"),
                        tone: .clay,
                        diameter: ZSpacing.touchMinimum,
                        action: openParents,
                    )
                }
            }

            // Headline, collection pill and tiles are one group, centred in
            // what the top bar leaves. The reader measures that space so the
            // tiles are sized against it rather than against an estimate —
            // which is what keeps both games on screen at once from a 375 pt
            // iPhone up, with no scroll view — and the intro reports its own
            // height so the group can sit in the middle instead of the tiles
            // drifting away from the words that introduce them.
            GeometryReader { area in
                VStack(spacing: ZSpacing.step7) {
                    intro
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                            introHeight = $0
                        }

                    tiles(in: CGSize(
                        width: area.size.width,
                        height: max(0, area.size.height - introHeight - ZSpacing.step7),
                    ))
                }
                .frame(width: area.size.width, height: area.size.height)
            }
            .frame(maxWidth: ZSpacing.maxContent)
            .padding(.horizontal, ZSpacing.gutterScreen)
            .padding(.vertical, ZSpacing.step6)
            .frame(maxWidth: .infinity)

            album
        }
        .background(ZColor.surfacePage)
        .overlay {
            if isPicking {
                CollectionPicker(
                    entries: collections,
                    chosen: chosenCollection,
                    choose: chooseCollection,
                    close: { isPicking = false },
                )
            }
        }
        // Nothing at all where the system asks for less motion, as the quit
        // question does it.
        .animation(
            reduceMotion ? nil : ZMotion.easeOut.animation(duration: ZMotion.fast),
            value: isPicking,
        )
    }

    /// The headline and, once there is more than one pack on the device, the
    /// collection this child plays with.
    ///
    /// Measured as one so the tiles below know what is left; the pill costs a
    /// 390 pt phone 40 pt of tile and an iPad nothing at all.
    private var intro: some View {
        VStack(spacing: ZSpacing.step4) {
            headline

            if let chosen = collections.first(where: { $0.id == chosenCollection }) {
                CollectionChip(entry: chosen) { isPicking = true }
            }
        }
    }

    /// The album's door, centred at the foot as the design draws it, with the
    /// way to „Über ZilpZalp" in the corner beside it.
    ///
    /// Outside the reader above rather than inside it, so the tiles are
    /// measured against what is left over and keep sizing themselves. The
    /// design's row has two more buttons; "Wer spielt?" is the avatar in the
    /// top bar here, and "Unser Schwarm" lives inside the album, where a list
    /// of siblings is a page in a book rather than a door on the home screen.
    ///
    /// An overlay rather than a third element in a row, so the album keeps the
    /// screen's midline: it is the one button here a child aims at, and it may
    /// not move because a grown-up's door appeared beside it.
    private var album: some View {
        IconButton(
            .album,
            label: String(localized: "collection.title"),
            tone: .primary,
            diameter: isCompact ? ZSpacing.touchMinimum : ZSpacing.touchComfortable,
            action: openCollection,
        )
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) { about }
        .padding(.bottom, ZSpacing.step5)
    }

    /// „Über ZilpZalp" (#199): the quiet "i" in the bottom corner.
    ///
    /// Not in the top bar beside the lock, where #199 expected it, and the
    /// reason is arithmetic. ``TopBarRow`` reserves `max(leading, trailing)`
    /// on *both* sides of the bar, so a third 64 pt button in the trailing
    /// slot pushes that slot's left edge under the wordmark: with the wordmark
    /// measured at 144 pt and the compact gutter, the gap between the two is
    /// 59 pt with two buttons and −17 pt on a 375 pt phone and −2 pt on a
    /// 390 pt one with three. The overlap would have shown on neither of the
    /// two devices the screenshots were taken on. So the button goes where
    /// there is room for it on every supported screen — and the corner is the
    /// quieter place anyway: it is beside the album rather than among the
    /// tiles, and it competes with nothing a child is looking for.
    ///
    /// The default `quiet` tone, against the album's `primary`: of the two
    /// doors down here only one is for the child.
    private var about: some View {
        IconButton(
            .info,
            label: String(localized: "about.title"),
            diameter: ZSpacing.touchMinimum,
            action: openAbout,
        )
        // The screen gutter the rest of this screen keeps, so the glyph sits
        // in from the edge rather than on it.
        .padding(.trailing, isCompact ? ZSpacing.step4 : ZSpacing.gutterScreen)
    }

    /// The one line of text on the screen, and it is for the grown-up looking
    /// over the shoulder: a child who cannot read navigates by the pictures.
    private var headline: some View {
        Text("home.title")
            .typeStyle(titleStep, .display, weight: .extraBold)
            .foregroundStyle(ZColor.textStrong)
            .multilineTextAlignment(.center)
            // The group around it has a fixed height and would otherwise
            // offer the text one line's worth and let it truncate. It takes
            // the height its own wrapping needs; the tiles get the rest.
            .fixedSize(horizontal: false, vertical: true)
    }

    /// The games, side by side or stacked — whichever arrangement the space
    /// makes the tiles bigger in.
    ///
    /// One rule, no cases: an iPad ends up in a row in either orientation, an
    /// iPhone stacks in portrait and rows in landscape, an iPad in Slide Over
    /// stacks. A single game is that same rule with nothing to share the space
    /// with, and its tile comes out as big as the room allows. Bigger tiles are
    /// the whole goal — they are what a four-year-old aims at.
    private func tiles(in area: CGSize) -> some View {
        let inARow = tileSize(in: area, sideBySide: true)
        let stacked = tileSize(in: area, sideBySide: false)
        let sideBySide = inARow >= stacked
        let size = sideBySide ? inARow : stacked
        let arrangement = sideBySide
            ? AnyLayout(HStackLayout(spacing: ZSpacing.gapTiles))
            : AnyLayout(VStackLayout(spacing: ZSpacing.gapTiles))

        // No stars: nothing is stored in M3 — earned stars arrive with the
        // progress persistence (#27) — and a filled slot the app cannot
        // remember would be a lie told to a four-year-old.
        return arrangement {
            ForEach(games, id: \.self) { game in
                tile(game, size: size)
            }
        }
        // Full width so the tiles sit on the screen's midline; the height is
        // their own, so the group above can centre as one.
        .frame(maxWidth: .infinity)
    }

    /// One game's tile. Glyph and rubric tint belong to the game and never
    /// move between games: a child who cannot read finds its game by them.
    private func tile(_ game: Game, size: CGFloat) -> some View {
        let (icon, tone): (ZIcon, HomeTile.Tone) = switch game {
        case .names: (.bird, .hoopoe)
        case .calls: (.volume2, .leaf)
        }

        return HomeTile(
            title: game.title,
            icon: icon,
            tone: tone,
            size: size,
            action: { openGame(game) },
        )
    }

    /// A screen title is `display-2` in the design. In a compact width it
    /// steps down to `headline`: every point the title gives back goes into
    /// the tiles, and on the shortest supported screen that is what keeps both
    /// games visible at a size their labels still fit.
    private var titleStep: ZType.Step {
        isCompact ? .headline : .display2
    }

    /// One tile's edge length: the design's grid cell, and smaller only where
    /// the space cannot hold it — a phone in landscape, an iPad in Slide Over.
    ///
    /// Never below the 64 pt touch floor, even where that means overflowing the
    /// space: a tile a four-year-old cannot hit breaks a rule the design calls
    /// non-negotiable, and a few points of overhang does not. No supported
    /// device gets anywhere near it — the floor is here so that none ever can.
    private func tileSize(in area: CGSize, sideBySide: Bool) -> CGFloat {
        let tiles = CGFloat(games.count)
        let gaps = ZSpacing.gapTiles * (tiles - 1)
        let across = sideBySide ? (area.width - gaps) / tiles : area.width
        let down = sideBySide ? area.height : (area.height - gaps) / tiles
        let fitting = min(HomeTile.defaultSize, across, down).rounded(.down)
        return max(ZSpacing.touchMinimum, fitting)
    }
}

// MARK: - Previews

/// Three packs on the device, so there is something to choose between.
private let previewCollections = [
    CollectionEntry(id: nil, title: "Alle Vögel", cover: nil),
    CollectionEntry(id: "deutschland", title: "Vögel Deutschlands", cover: nil),
    CollectionEntry(id: "afrika", title: "Vögel Afrikas", cover: nil),
]

#Preview("iPad landscape", traits: .fixedLayout(width: 1194, height: 834)) {
    HomeScreen(
        avatar: "feather",
        games: [.names, .calls],
        openGame: { _ in },
        openParents: {},
        openAbout: {},
        openProfiles: {},
        collections: previewCollections,
        chosenCollection: "afrika",
        chooseCollection: { _ in },
        openCollection: {},
    )
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("iPhone portrait", traits: .fixedLayout(width: 390, height: 844)) {
    HomeScreen(
        avatar: "feather",
        games: [.names, .calls],
        openGame: { _ in },
        openParents: {},
        openAbout: {},
        openProfiles: {},
        collections: previewCollections,
        chosenCollection: nil,
        chooseCollection: { _ in },
        openCollection: {},
    )
    .environment(\.horizontalSizeClass, .compact)
}

// The bundled pack alone: nothing to choose between, and the screen as it was
// before #187 — headline and tiles, and the tiles get every point of it.
#Preview("One pack, no collections", traits: .fixedLayout(width: 390, height: 844)) {
    HomeScreen(
        avatar: "feather",
        games: [.names, .calls],
        openGame: { _ in },
        openParents: {},
        openAbout: {},
        openProfiles: {},
        collections: [],
        chosenCollection: nil,
        chooseCollection: { _ in },
        openCollection: {},
    )
    .environment(\.horizontalSizeClass, .compact)
}

// What every device shows while no pack carries a call and until #32 curates
// them: game 1 alone, in the whole space the pair had.
#Preview("Without the calls", traits: .fixedLayout(width: 1194, height: 834)) {
    HomeScreen(
        avatar: "feather",
        games: [.names],
        openGame: { _ in },
        openParents: {},
        openAbout: {},
        openProfiles: {},
        collections: [],
        chosenCollection: nil,
        chooseCollection: { _ in },
        openCollection: {},
    )
    .environment(\.horizontalSizeClass, .regular)
}
