import SwiftUI
import ZilpZalpUI

/// „Welche Vögel?" — the collections, on a card over the dimmed home screen
/// (#187).
///
/// Not the sticker album: this decides which birds the next round asks about,
/// and the album keeps every bird a child has ever collected.
///
/// A card over the screen rather than a screen of its own, for the reason
/// ``QuitConfirmation`` gives: what the choice is *for* stays visible behind
/// it, and a child who did not mean to open this gets out by tapping anywhere.
/// Every entry is a round photo with the collection's name under it — the
/// album's own shapes, at the album's own sizes — and the chosen one carries a
/// ring **and** a check, never colour alone.
///
/// **A tap chooses at once and leaves the card standing.** There is nothing to
/// confirm and therefore no way to cancel: the choice is already made, so a
/// tap beside the card is as safe as the „Los!" pill, and a child can listen
/// to one collection after another before going back to the games.
struct CollectionPicker: View {
    /// Wide enough for three columns of stickers on an iPad, narrow enough
    /// that the card still reads as a card rather than as a screen.
    private static let maximumWidth: CGFloat = 720

    /// How much bigger the chosen sticker sits, on top of the olive rim and
    /// the check `RewardSticker` gives it. Small enough not to jostle the
    /// grid, big enough to see across a table.
    private static let chosenScale: CGFloat = 1.06

    /// What there is to choose between, „Alle Vögel" first.
    let entries: [CollectionEntry]

    /// The collection being played with, resolved — see ``CollectionChip``.
    let chosen: String?

    let choose: (String?) -> Void

    /// Back to the games. The pill and a tap beside the card both do this.
    let close: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One announcer for the question and for every tapped collection, so the
    /// two can never talk over each other — the second tap cuts the first one
    /// off, which is what `CollectionScreen` relies on too.
    ///
    /// That is also why the question is not `readAloudOnce`: that modifier
    /// brings an announcer of its own, and it would still be saying „Welche
    /// Vögel?" while this one says „Vögel Afrikas".
    ///
    /// Optional and filled on first use, as the album's is: a `@State`
    /// default is evaluated again every time the view struct is rebuilt, and
    /// choosing a collection rebuilds this card — so a stored
    /// `SpeechAnnouncer()` would allocate an `AVSpeechSynthesizer` per tap and
    /// throw it away.
    @State private var announcer: SpeechAnnouncer?

    /// `onAppear` can fire more than once for one arrival, so the flag is what
    /// makes "once" true — the same guard `ReadAloudOnce` keeps.
    @State private var hasAsked = false

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        ZStack {
            ZColor.scrim
                .ignoresSafeArea()
                .onTapGesture(perform: close)
                // Not something to find with VoiceOver: the way out a swipe
                // must land on is the pill inside the card.
                .accessibilityHidden(true)
                .transition(.opacity)

            card
        }
        // The home screen behind is dimmed and unreachable, so VoiceOver must
        // not offer it either. On the whole overlay rather than on the card,
        // because the trait hides the *siblings* of the view carrying it.
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear {
            guard !hasAsked else { return }
            hasAsked = true
            say(.fixed("home.collection.title"))
        }
        .onDisappear { announcer?.stop() }
    }

    private var card: some View {
        ZCard(padding: isCompact ? ZSpacing.step5 : ZSpacing.step6) {
            VStack(spacing: isCompact ? ZSpacing.step5 : ZSpacing.step6) {
                Text("home.collection.title")
                    .typeStyle(isCompact ? .headline : .title, .display, weight: .extraBold)
                    .foregroundStyle(ZColor.textStrong)
                    .multilineTextAlignment(.center)

                collections

                // Medium rather than large: with five collections on the
                // shortest supported phone the card needs every point it can
                // give back, and 64 pt is still the touch floor.
                ZButton(
                    String(localized: "home.collection.done"),
                    size: .medium,
                    leadingIcon: .play,
                    action: close,
                )
            }
        }
        .frame(maxWidth: Self.maximumWidth)
        // Never against the screen edge.
        .padding(ZSpacing.step3)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    /// The grid. It does not scroll: five collections fit the shortest phone,
    /// and a card that scrolls hides what is in it from a child who cannot
    /// read. Should the bucket ever offer more than eight packs, this is where
    /// a scroll view has to be thought about.
    ///
    /// The album's grid, at the album's sizes — see ``StickerGrid``.
    private var collections: some View {
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
            ForEach(entries, id: \.id) { entry in
                sticker(entry)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// One collection: its bird, its name, and — while it is the chosen one —
    /// the rim, the check and a little more size than the others.
    private func sticker(_ entry: CollectionEntry) -> some View {
        let isChosen = entry.id == chosen

        return Button {
            choose(entry.id)
            say(entry.spoken)
        } label: {
            StickerCaption(caption: entry.title, earned: true) {
                RewardSticker(
                    image: entry.cover,
                    icon: .bird,
                    chosen: isChosen,
                    size: StickerGrid.size(compact: isCompact),
                )
            }
            .scaleEffect(isChosen ? Self.chosenScale : 1)
            // Nothing at all where the system asks for less motion: the rim
            // and the check are what carry the choice anyway.
            .animation(
                reduceMotion ? nil : ZMotion.easeBounce.animation(duration: ZMotion.fast),
                value: isChosen,
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(entry.title)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    /// Says one line, building the announcer the first time something speaks.
    /// Kept afterwards, so the next line cuts this one off instead of talking
    /// over it — the album's ``CollectionScreen`` does it the same way.
    private func say(_ line: SpokenLine) {
        let voice = announcer ?? SpeechAnnouncer()
        announcer = voice
        voice.announce(line)
    }
}

// MARK: - Previews

private let previewEntries = [
    CollectionEntry(id: nil, title: "Alle Vögel", cover: nil),
    CollectionEntry(id: "deutschland", title: "Vögel Deutschlands", cover: nil),
    CollectionEntry(id: "welt", title: "Vögel der Welt", cover: nil),
    CollectionEntry(id: "afrika", title: "Vögel Afrikas", cover: nil),
]

#Preview("iPhone portrait", traits: .fixedLayout(width: 390, height: 844)) {
    CollectionPicker(
        entries: previewEntries,
        chosen: "afrika",
        choose: { _ in },
        close: {},
    )
    .environment(\.horizontalSizeClass, .compact)
}

#Preview("iPad", traits: .fixedLayout(width: 1194, height: 834)) {
    CollectionPicker(
        entries: previewEntries,
        chosen: nil,
        choose: { _ in },
        close: {},
    )
    .environment(\.horizontalSizeClass, .regular)
}
