import SwiftUI
import ZilpZalpData
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
/// album's own shapes, at the album's own sizes — and every chosen one carries
/// a ring **and** a check, never colour alone.
///
/// **Several packs at once** (#306). A tap on a pack puts it in or takes it
/// out, „Alle Vögel" clears the packs, and taking the last pack out leaves
/// „Alle Vögel" chosen — see ``PackCollections/toggled(_:in:)``. A child who
/// cannot read sees the choice as checks: one on every chosen sticker, and as
/// many stacked stickers on the home screen's pill.
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

    /// How wide a column may get on a phone before another fits beside it.
    /// Wider than the album's: a pack title's longest word, „Deutschlands",
    /// is 118 pt at the 20 pt a child reads, and three columns leave 102 pt
    /// — so it shrank below its neighbours (#262). Two columns keep every
    /// title at one size, wrapped onto a second line where it needs one.
    private static let compactColumn: CGFloat = 130

    /// What there is to choose between, „Alle Vögel" first.
    let entries: [CollectionEntry]

    /// The packs being played with, resolved; empty for „Alle Vögel".
    let selection: Set<String>

    /// Where a tapped pack's recorded title is looked up (#306).
    let library: PackLibrary

    /// A tapped entry, which toggles it.
    let choose: (String?) -> Void

    /// Back to the games. The pill and a tap beside the card both do this.
    let close: () -> Void

    /// The "+" at the end: more birds, which only a grown-up can load — so it
    /// opens the grown-ups' area, whose first section is the pack gallery
    /// (#262). The lock stands in front of it as it always does.
    let addBirds: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One announcer for the question and for every tapped collection, so the
    /// two can never talk over each other — the second tap cuts the first one
    /// off, which is what `CollectionScreen` relies on too.
    ///
    /// That is also why the question has no ``ReadAloudButton``: that one
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
    /// makes "once" true — the same guard `ReadAloudButton` keeps.
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
            say(Self.question, unprompted: true)
        }
        .onDisappear { announcer?.stop() }
    }

    private var card: some View {
        ZCard(padding: isCompact ? ZSpacing.step5 : ZSpacing.step6) {
            VStack(spacing: isCompact ? ZSpacing.step5 : ZSpacing.step6) {
                HStack(spacing: ZSpacing.step3) {
                    Text("home.collection.title")
                        .typeStyle(isCompact ? .headline : .title, .display, weight: .extraBold)
                        .foregroundStyle(ZColor.textStrong)
                        .multilineTextAlignment(.center)

                    // Not a ``ReadAloudButton``: that brings an announcer of
                    // its own, and the question and the packs share this one.
                    IconButton(
                        .volume2,
                        label: String(
                            format: String(localized: "speech.readAloud.accessibility"),
                            Self.question.text,
                        ),
                        tone: .accent,
                        diameter: ZSpacing.touchMinimum,
                    ) {
                        say(Self.question)
                    }
                }

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

    /// The grid, scrolling only once it no longer fits (#262): five
    /// collections fit the shortest phone, and a card that scrolls hides what
    /// is in it from a child who cannot read — but ten packs and the "+" do
    /// not fit, and a grid that ran off the card would hide them all the same.
    private var collections: some View {
        ViewThatFits(in: .vertical) {
            grid
            ScrollView {
                grid
            }
            .scrollBounceBehavior(.basedOnSize)
            .scrollIndicatorsFlash(onAppear: true)
        }
    }

    /// The album's grid, at the album's sizes — see ``StickerGrid``.
    private var grid: some View {
        LazyVGrid(
            columns: [
                GridItem(
                    .adaptive(minimum: isCompact ? Self.compactColumn : StickerGrid
                        .column(compact: false)),
                    spacing: StickerGrid.spacing(compact: isCompact),
                    alignment: .top,
                ),
            ],
            spacing: StickerGrid.spacing(compact: isCompact),
        ) {
            ForEach(entries, id: \.id) { entry in
                sticker(entry)
            }
            more
        }
        .frame(maxWidth: .infinity)
    }

    /// A plus on a sticker, where the next collection would be. A picture and
    /// a word like every entry, never a word alone.
    private var more: some View {
        Button {
            close()
            addBirds()
        } label: {
            StickerCaption(caption: String(localized: "home.collection.more"), earned: true) {
                RewardSticker(
                    icon: .plus,
                    tone: .leaf,
                    rotation: .zero,
                    size: StickerGrid.size(compact: isCompact),
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(localized: "home.collection.more.accessibility"))
    }

    /// One collection: its bird, its name, and — while it is chosen — the
    /// rim, the check and a little more size than the others.
    private func sticker(_ entry: CollectionEntry) -> some View {
        let isChosen = entry.isChosen(in: selection)

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

    /// „Welche Vögel?", shown and said.
    private static let question = SpokenLine.fixed("home.collection.title")

    /// Says one line, building the announcer the first time something speaks.
    /// Kept afterwards, so the next line cuts this one off instead of talking
    /// over it — the album's ``CollectionScreen`` does it the same way. With
    /// the packs, so a pack's recorded title is found (#306).
    private func say(_ line: SpokenLine, unprompted: Bool = false) {
        let voice = announcer ?? SpeechAnnouncer(library: library)
        announcer = voice
        voice.announce(line, unprompted: unprompted)
    }
}

// MARK: - Previews

private let previewEntries: [CollectionEntry] = [
    .preview(nil, "Alle Vögel"),
    .preview("deutschland", "Vögel Deutschlands"),
    .preview("welt", "Vögel der Welt"),
    .preview("afrika", "Vögel Afrikas"),
]

#Preview("iPhone portrait", traits: .fixedLayout(width: 390, height: 844)) {
    CollectionPicker(
        entries: previewEntries,
        selection: ["afrika", "welt"],
        library: .empty,
        choose: { _ in },
        close: {},
        addBirds: {},
    )
    .environment(\.horizontalSizeClass, .compact)
}

#Preview("iPad", traits: .fixedLayout(width: 1194, height: 834)) {
    CollectionPicker(
        entries: previewEntries,
        selection: [],
        library: .empty,
        choose: { _ in },
        close: {},
        addBirds: {},
    )
    .environment(\.horizontalSizeClass, .regular)
}
