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
///
/// Every tile shows what its questions look like — four real birds, the
/// look-alikes side by side in the top row — and carries one binoculars
/// sticker per look-alike, so a child who cannot read can count how tricky a
/// level is. The chosen level is olive with a check, never colour alone, and
/// a chosen rung grows a little as well.
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

    /// The width the ramp has to fill, measured: the rungs are sized against
    /// it. It depends on the card and never on the rungs, so it settles after
    /// one extra layout pass.
    @State private var rampWidth: CGFloat = 0

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
        ZCard(padding: isCompact ? ZSpacing.step5 : ZSpacing.step6) {
            VStack(spacing: isCompact ? ZSpacing.step5 : ZSpacing.step6) {
                HStack(spacing: ZSpacing.step3) {
                    Text("home.difficulty.title")
                        .typeStyle(isCompact ? .headline : .title, .display, weight: .extraBold)
                        .foregroundStyle(ZColor.textStrong)
                        .multilineTextAlignment(.center)

                    // Not a ``ReadAloudButton``: the question and the levels
                    // share this card's announcer.
                    SpeakerButton(text: Self.question.text) {
                        say(Self.question, unprompted: false)
                    }
                }

                VStack(spacing: isCompact ? ZSpacing.step4 : ZSpacing.step5) {
                    ramp
                    hint
                }

                if let classic = levels.first(where: { $0.difficulty == .classic }) {
                    classicRow(classic)
                }

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

    /// Leicht, Mittel, Schwer in one row, as big as the card allows up to
    /// ``maximumTile`` — never below the touch floor.
    private var ramp: some View {
        let gap = isCompact ? ZSpacing.step3 : ZSpacing.step5
        let fitting = min(Self.maximumTile, (rampWidth - 2 * gap) / 3).rounded(.down)
        let edge = max(ZSpacing.touchMinimum, fitting)

        return HStack(alignment: .top, spacing: gap) {
            ForEach(levels.filter { $0.difficulty != .classic }) { level in
                rung(level, edge: edge)
            }
        }
        .frame(maxWidth: .infinity)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: {
            rampWidth = $0
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
        let isChosen = level.difficulty == chosen

        return Button {
            pick(level)
        } label: {
            VStack(spacing: isCompact ? ZSpacing.step2 : ZSpacing.step3) {
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
        .buttonStyle(.plain)
        .accessibilityLabel(level.title)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    /// One binoculars sticker per look-alike, on the tile's top edge near its
    /// right corner: half of it above the tile, so no more than the top strip
    /// of a photo is under it and never the bird. The first sits at the
    /// corner, a second overlaps it from the left, tilted the other way and
    /// stuck on top of it.
    ///
    /// The mockup's offsets — 24 pt up and 14 pt in on an iPad, 17 up and 4 in
    /// on a phone — count from inside the tile's 5 pt rim; this overlay counts
    /// from its outer edge, hence the rim in the sums.
    private func stickers(_ count: Int) -> some View {
        let diameter: CGFloat = isCompact ? 30 : 44
        let rim = ZBorder.widthThick

        return HStack(spacing: -diameter * Self.stickerOverlap) {
            ForEach((0 ..< count).reversed(), id: \.self) { index in
                Group {
                    if index == 0 {
                        GlyphBadge(.binoculars, diameter: diameter)
                    } else {
                        GlyphBadge(.binoculars, diameter: diameter, rotation: .degrees(6))
                    }
                }
                .zIndex(Double(index))
            }
        }
        .offset(
            x: -((isCompact ? 4 : 14) + rim),
            y: rim - (isCompact ? 17 : 24),
        )
    }

    /// Klassisch: the portrait, the name and „Bunt gemischt", on the same
    /// papier tone as the rungs and chosen the same way — but not grown,
    /// because a full-width row that grew would leave the card.
    private func classicRow(_ level: DifficultyLevel) -> some View {
        let isChosen = level.difficulty == chosen
        let height: CGFloat = isCompact ? 72 : 96
        let photo: CGFloat = isCompact ? 60 : 72
        let shape = RoundedRectangle(cornerRadius: ZRadius.large, style: .continuous)

        return Button {
            pick(level)
        } label: {
            HStack(spacing: isCompact ? ZSpacing.step3 : ZSpacing.step4) {
                PhotoQuartet(photos: level.photos, size: photo, style: .mosaic)

                VStack(alignment: .leading, spacing: 0) {
                    name(level.title)
                    Text("home.difficulty.classic.hint")
                        .typeStyle(.body, .body, weight: .semibold, singleLine: true)
                        .foregroundStyle(ZColor.textBody)
                }
            }
            // The photo sits as far in from the left as from the top.
            .padding(.leading, (height - photo) / 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: height)
            .background(shape.fill(ZColor.sand200))
            .overlay {
                shape.strokeBorder(
                    isChosen ? ZColor.primary : ZColor.sand400,
                    lineWidth: ZBorder.widthThick,
                )
            }
            .background(
                shape
                    .fill(isChosen ? ZColor.primaryShadow : ZColor.sand400)
                    .offset(y: ZShadow.ledgeOffset),
            )
            .overlay(alignment: .bottomTrailing) {
                if isChosen {
                    ChosenCheck(compact: isCompact)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(level.title)
        .accessibilityAddTraits(isChosen ? .isSelected : [])
    }

    /// A level's name, under its tile or in the Klassisch row.
    private func name(_ title: String) -> some View {
        Text(verbatim: title)
            .typeStyle(
                isCompact ? .label : .headline,
                .display,
                weight: .extraBold,
                singleLine: true,
            )
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
