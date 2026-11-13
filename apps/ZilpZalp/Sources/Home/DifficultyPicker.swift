import SwiftUI
import ZilpZalpCore
import ZilpZalpUI

/// „Wie schwer?" — the four levels, on a card over the dimmed home screen.
///
/// The same shape as ``CollectionPicker`` and for its reasons: what the choice
/// is for stays visible behind it, a tap beside the card is a way out, a tap
/// on a level chooses at once and says its name, and there is nothing to
/// confirm. Only one level at a time, though.
///
/// **A ramp, then Klassisch.** Leicht, Mittel and Schwer stand as three tiles
/// in one row on every device, so the order reads left to right as easy to
/// hard — a column on a phone would have turned it into a list. Klassisch is
/// the game as it always was and sits *between* Leicht and Mittel in what it
/// asks of a child; as a fourth rung it would read as "harder than Schwer", so
/// it is a full-width row underneath instead.
struct DifficultyPicker: View {
    /// ``CollectionPicker``'s width, so the two cards are one shape.
    private static let maximumWidth: CGFloat = 720

    /// The chosen rung grows by this much, tile and name together — as the
    /// chosen collection sticker does.
    private static let chosenScale: CGFloat = 1.06

    /// A rung on an iPad: three of them and two gaps fill the 650 pt inside the
    /// widest card. A phone's rung is a third of what its card leaves, about
    /// 96 pt on a 390 pt iPhone.
    private static let maximumTile: CGFloat = 200

    /// Room inside the scrolling fallback for what hangs off the levels — the
    /// stickers above the top row, the check past the Klassisch row — so the
    /// scroll view's edge never cuts them.
    private static let scrollHeadroom = ZSpacing.step6
    private static let scrollMargin = ZSpacing.step3

    /// How far one binoculars sticker overlaps the one beside it.
    private static let stickerOverlap: CGFloat = 0.2

    /// What there is to choose between, in ``DifficultyLevel/order``.
    let levels: [DifficultyLevel]

    /// The level being played.
    let chosen: Difficulty

    /// A tapped level, which becomes the chosen one.
    let choose: (Difficulty) -> Void

    /// Back to the games. The pill and a tap beside the card both do this.
    let close: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// One announcer for the question and every tapped level, so a second tap
    /// cuts the first one off — and filled on first use rather than as a
    /// `@State` default, which would build a synthesiser on every tap. See
    /// ``CollectionPicker``'s.
    @State private var announcer: SpeechAnnouncer?

    /// `onAppear` can fire more than once for one arrival.
    @State private var hasAsked = false

    /// The width the levels have to fill, measured: the rungs are sized
    /// against it. It depends on the card and never on the rungs or on which
    /// fallback is showing, so it settles after one extra layout pass.
    @State private var rampWidth: CGFloat = 0

    private var metrics: Metrics {
        horizontalSizeClass == .compact ? .phone : .pad
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
        // The dimmed home screen behind must not be offered to VoiceOver.
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
        ZCard(padding: metrics.section) {
            VStack(spacing: metrics.section) {
                HStack(spacing: ZSpacing.step3) {
                    Text("home.difficulty.title")
                        .typeStyle(metrics.title, .display, weight: .extraBold)
                        .foregroundStyle(ZColor.textStrong)
                        .multilineTextAlignment(.center)

                    // Not a ``ReadAloudButton``: the question and the levels
                    // share this card's announcer.
                    SpeakerButton(text: Self.question.text) {
                        say(Self.question, unprompted: false)
                    }
                }

                fittingChoices

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

    /// The levels at the biggest size the card's height allows: 200 pt rungs,
    /// then ``PhotoQuartet/largeTile`` ones, the smallest that keep the iPad's
    /// tile. Only where even those do not fit — an iPad mini on its side, a
    /// short Stage Manager window — do they scroll, so Klassisch and „Los!"
    /// are never cut off.
    private var fittingChoices: some View {
        let ramp = levels.filter { $0.difficulty != .classic }
        let classic = levels.first { $0.difficulty == .classic }

        return ViewThatFits(in: .vertical) {
            choices(ramp, classic, maximumTile: Self.maximumTile, width: rampWidth)
            choices(ramp, classic, maximumTile: PhotoQuartet.largeTile, width: rampWidth)
            ScrollView {
                choices(
                    ramp,
                    classic,
                    maximumTile: PhotoQuartet.largeTile,
                    width: rampWidth - 2 * Self.scrollMargin,
                )
                .padding(.horizontal, Self.scrollMargin)
                .padding(.top, Self.scrollHeadroom)
                .padding(.bottom, Self.scrollMargin)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        // Measured here rather than on a ramp, so the width is the same
        // whichever of the three is showing.
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
            rampWidth = $0
        }
    }

    /// The ramp, the grown-ups' line under it and the Klassisch row, with
    /// rungs as big as `width` allows up to `maximumTile` — never below the
    /// touch floor.
    private func choices(
        _ ramp: [DifficultyLevel],
        _ classic: DifficultyLevel?,
        maximumTile: CGFloat,
        width: CGFloat,
    ) -> some View {
        let gap = metrics.rungGap
        let fitting = min(maximumTile, (width - 2 * gap) / 3).rounded(.down)
        let edge = max(ZSpacing.touchMinimum, fitting)

        return VStack(spacing: metrics.section) {
            VStack(spacing: metrics.hintGap) {
                HStack(alignment: .top, spacing: gap) {
                    ForEach(ramp) { level in
                        rung(level, edge: edge)
                    }
                }
                .frame(maxWidth: .infinity)

                hint
            }

            if let classic {
                classicRow(classic, rungEdge: edge)
            }
        }
    }

    /// The one line for the grown-up looking over the shoulder: what the ramp
    /// means. A child reads the stickers instead.
    private var hint: some View {
        Text("home.difficulty.hint")
            .typeStyle(.body, .body, weight: .semibold)
            .foregroundStyle(ZColor.textBody)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// One rung: the level's tile with its stickers, and its name — the
    /// whole cell a little bigger while it is the chosen one.
    private func rung(_ level: DifficultyLevel, edge: CGFloat) -> some View {
        levelButton(level) { isChosen in
            VStack(spacing: metrics.nameGap) {
                PhotoQuartet(photos: level.photos, size: edge, chosen: isChosen)
                    .overlay(alignment: .topTrailing) { stickers(level.lookalikes) }

                name(level.title)
            }
            // The gap between tile and name answers a tap too.
            .contentShape(Rectangle())
            .scaleEffect(isChosen ? Self.chosenScale : 1)
            // Nothing at all where the system asks for less motion: the rim
            // and the check carry the choice anyway.
            .animation(
                reduceMotion ? nil : ZMotion.easeBounce.animation(duration: ZMotion.fast),
                value: isChosen,
            )
        }
    }

    /// One binoculars sticker per look-alike, on the tile's top edge near its
    /// right corner: half of it above the tile, so no more than the top strip
    /// of a photo is under it and never the bird. A second one overlaps the
    /// first from the left, tilted the other way and stuck on top of it.
    private func stickers(_ count: Int) -> some View {
        let diameter = metrics.sticker
        // This overlay counts from the tile's outer edge, past the rim.
        let rim = ZBorder.widthThick

        return HStack(spacing: -diameter * Self.stickerOverlap) {
            ForEach((0 ..< count).reversed(), id: \.self) { index in
                GlyphBadge(.binoculars, diameter: diameter, rotation: .degrees(index == 0 ? -8 : 6))
                    .zIndex(Double(index))
            }
        }
        .offset(x: -(metrics.stickerIn + rim), y: rim - metrics.stickerUp)
    }

    /// Klassisch: the portrait, the name and „Bunt gemischt", on the same
    /// papier tone as the rungs and chosen the same way — but not grown,
    /// because a full-width row that grew would leave the card. It wears the
    /// check of rungs `rungEdge` wide, so the row and the tiles above it never
    /// wear two different checks.
    ///
    /// The photo sits inside the rim with sand around it, as the tiles' photos
    /// do, and the row is as tall as that makes it: 82 pt on a phone, 102 on
    /// an iPad.
    private func classicRow(_ level: DifficultyLevel, rungEdge: CGFloat) -> some View {
        let photo = metrics.classicPhoto
        let inset = ZBorder.widthThick + metrics.classicSand

        return levelButton(level) { isChosen in
            HStack(spacing: metrics.classicGap) {
                PhotoQuartet(photos: level.photos, size: photo, style: .mosaic)

                VStack(alignment: .leading, spacing: 0) {
                    name(level.title)
                    Text("home.difficulty.classic.hint")
                        .typeStyle(.body, .body, weight: .semibold, singleLine: true)
                        .foregroundStyle(ZColor.textBody)
                }
            }
            // As far in from the left as from the top and the bottom.
            .padding(.leading, inset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: photo + 2 * inset)
            .papierSurface(
                RoundedRectangle(cornerRadius: ZRadius.large, style: .continuous),
                chosen: isChosen,
                ledge: ZShadow.ledgeOffset,
            )
            .overlay(alignment: .bottomTrailing) {
                if isChosen {
                    ChosenCheck(tileSize: rungEdge)
                }
            }
            .contentShape(Rectangle())
        }
        // The rungs show what their level means; this row says it.
        .accessibilityHint(String(localized: "home.difficulty.classic.hint"))
    }

    /// A level as a button, rung or row: a tap picks it, VoiceOver reads its
    /// name, and it is selected while it is the one being played — which
    /// `label` is handed too.
    private func levelButton(
        _ level: DifficultyLevel,
        @ViewBuilder label: (_ isChosen: Bool) -> some View,
    ) -> some View {
        let isChosen = level.difficulty == chosen

        return Button {
            pick(level)
        } label: {
            label(isChosen)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(level.title)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    /// A level's name, under its tile or in the Klassisch row.
    private func name(_ title: String) -> some View {
        Text(verbatim: title)
            .typeStyle(metrics.name, .display, weight: .extraBold, singleLine: true)
            .foregroundStyle(ZColor.textStrong)
    }

    /// A tapped level: chosen at once, and its name said.
    private func pick(_ level: DifficultyLevel) {
        choose(level.difficulty)
        say(level.spoken, unprompted: false)
    }

    /// „Wie schwer?", shown and said.
    private static let question = SpokenLine.fixed("home.difficulty.title")

    /// Says one line, building the announcer the first time something speaks
    /// and keeping it, so the next line cuts this one off.
    private func say(_ line: SpokenLine, unprompted: Bool) {
        let voice = announcer ?? SpeechAnnouncer()
        announcer = voice
        voice.announce(line, unprompted: unprompted)
    }

    /// The picker's numbers on a phone and on an iPad, so the size class is
    /// asked in one place. The values without a token are the reviewed
    /// mockup's.
    private struct Metrics {
        static let phone = Metrics(compact: true)
        static let pad = Metrics(compact: false)

        /// The card's padding, and the gap between what it stacks.
        let section: CGFloat
        let title: ZType.Step
        let rungGap: CGFloat
        /// Between the rungs and the grown-ups' line under them.
        let hintGap: CGFloat
        /// Between a rung's tile and its name.
        let nameGap: CGFloat
        let name: ZType.Step
        /// A binoculars sticker's diameter, and how far in from the tile's
        /// right corner and up from its top edge it sits — counted, as the
        /// mockup counts, from inside the rim.
        let sticker: CGFloat
        let stickerIn: CGFloat
        let stickerUp: CGFloat
        /// The Klassisch row's photo, the sand between it and the rim, and
        /// the gap to the words beside it.
        let classicPhoto: CGFloat
        let classicSand: CGFloat
        let classicGap: CGFloat

        private init(compact: Bool) {
            section = compact ? ZSpacing.step5 : ZSpacing.step6
            title = compact ? .headline : .title
            rungGap = compact ? ZSpacing.step3 : ZSpacing.step5
            hintGap = compact ? ZSpacing.step4 : ZSpacing.step5
            nameGap = compact ? ZSpacing.step2 : ZSpacing.step3
            name = compact ? .label : .headline
            sticker = compact ? 30 : 44
            stickerIn = compact ? 4 : 14
            stickerUp = compact ? 17 : 24
            classicPhoto = compact ? 60 : 72
            classicSand = compact ? 6 : 10
            classicGap = compact ? ZSpacing.step3 : ZSpacing.step4
        }
    }
}

// MARK: - Previews

#Preview("iPhone portrait", traits: .fixedLayout(width: 390, height: 844)) {
    DifficultyPicker(
        levels: DifficultyLevel.previews,
        chosen: .medium,
        choose: { _ in },
        close: {},
    )
    .environment(\.horizontalSizeClass, .compact)
}

#Preview("iPad", traits: .fixedLayout(width: 1194, height: 834)) {
    DifficultyPicker(
        levels: DifficultyLevel.previews,
        chosen: .classic,
        choose: { _ in },
        close: {},
    )
    .environment(\.horizontalSizeClass, .regular)
}
