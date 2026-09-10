import SwiftUI

/// One wordless answer in a bird quiz: a big photo a four-year-old can hit.
///
/// Ported from `design/components/quiz/ChoiceTile.jsx`. The tile knows nothing
/// about birds, packs or licences. It is handed a finished `Image` and a
/// ``Phase``; which bird that is and when the phase changes are the screen's
/// business. The photo carries no attribution of its own — it reaches the
/// child edge to edge, and every medium is credited on the credits screen
/// generated from the pack manifests (#200).
///
/// **Wordless by design.** The JSX can print a bird's name under the photo;
/// this port cannot. Quiz tiles never carry the name of the bird they show —
/// a child who cannot read would learn nothing from it, and a child who can
/// would simply read the answer. The name lives in ``label`` instead, where
/// VoiceOver speaks it and nobody sees it.
///
/// **Never a failure.** ``Phase/retry`` is sun yellow with a `rotate-ccw`
/// glyph: try again, not wrong. There is no red, no X and no disabled state
/// anywhere in this control — a tapped-out tile is dimmed, never blocked.
///
/// ```swift
/// ChoiceTile(
///     image: photo,
///     label: "Amsel",
///     tone: .beeren,
///     phase: .idle,
/// ) { answer(.amsel) }
/// ```
public struct ChoiceTile: View {
    /// Where this tile stands in the round.
    ///
    /// Named `Phase` rather than `State`: a nested `State` would shadow
    /// `SwiftUI.State` everywhere inside this file.
    public enum Phase: CaseIterable, Hashable, Sendable {
        /// Untouched, waiting.
        case idle
        /// The child's finger just landed here. Hoopoe orange.
        case chosen
        /// The answer. Olive, a `check`, and the tile lifts.
        case correct
        /// Not this one. Sun yellow and a `rotate-ccw` — never red, never an
        /// X, and the round carries on.
        case retry

        /// The badge in the top-right corner, if this phase shows one. An
        /// unresolved tile shows none: a marker on every tile marks nothing.
        var badge: ChoiceTileBadge? {
            switch self {
            case .idle, .chosen:
                nil
            case .correct:
                ChoiceTileBadge(icon: .check, fill: ZColor.correct, foreground: ZColor.white)
            case .retry:
                // Sun yellow carries dark ink, as everywhere else in the system.
                ChoiceTileBadge(icon: .rotateCcw, fill: ZColor.retry, foreground: ZColor.bark700)
            }
        }

        /// What the tile feels like when it reaches this phase, `nil` where it
        /// should feel like nothing at all.
        ///
        /// The taps a child cannot hear over a playground still land: the
        /// answer is a `success`, another go is a `warning`. Deliberately
        /// **not** `.error`, which is the system's failure signal — this
        /// control has no failure state, no red and no X, and a buzz that
        /// says "wrong" would put one back in through the fingertips.
        ///
        /// `idle` and `chosen` feel like nothing: `chosen` is the frame
        /// between the tap and the verdict, and `idle` is what every tile
        /// returns to when the next question is dealt — a whole grid buzzing
        /// its way back to rest would be the loudest thing in the round.
        ///
        /// Whether the phone plays it at all is the system's: SwiftUI honours
        /// the device's haptics setting, and this control never asks twice.
        var feedback: SensoryFeedback? {
            switch self {
            case .idle, .chosen: nil
            case .correct: .success
            case .retry: .warning
            }
        }

        /// How the border, the ledge and the ring are painted. `idle` takes
        /// all three from the tile's own ``Tone``; the other three phases
        /// override them, exactly as `STATE` does in the JSX.
        func palette(on tone: Tone) -> ChoiceTilePalette {
            switch self {
            case .idle:
                ChoiceTilePalette(border: tone.edge, ledge: tone.edge, ring: nil)
            case .chosen:
                ChoiceTilePalette(
                    border: ZColor.accent,
                    ledge: ZColor.accentShadow,
                    ring: ZColor.orange100,
                )
            case .correct:
                ChoiceTilePalette(
                    border: ZColor.correct,
                    ledge: ZColor.olive700,
                    ring: ZColor.olive200,
                )
            case .retry:
                ChoiceTilePalette(
                    border: ZColor.retry,
                    ledge: ZColor.sun600,
                    ring: ZColor.sun200,
                )
            }
        }
    }

    /// The nine rubric tints `ChoiceTile.jsx` declares.
    ///
    /// The JSX table gives five colours per tone; two of them — the tile body
    /// and its label colour — only ever show behind a bird's name, and this
    /// port draws no name. What is left is the field behind the placeholder
    /// glyph and the deep shade the border and the ledge are cut from.
    ///
    /// The identifiers are the German token names from the design export, as
    /// in ``ZColor/Rubric``; they are not product copy.
    public enum Tone: CaseIterable, Hashable, Sendable {
        /// The neutral default: sand on cream, no topic claimed.
        case papier
        case wald
        case wiese
        case rufe
        case belohnung
        case federn
        case rinde
        case beeren
        case sumpf

        /// The lightest tint of the rubric — what shows behind the
        /// placeholder glyph until a photo arrives.
        var field: Color {
            switch self {
            case .papier: ZColor.sand200
            case .wald: ZColor.olive100
            case .wiese: ZColor.olive50
            case .rufe: ZColor.orange50
            case .belohnung: ZColor.sun100
            case .federn: ZColor.clay50
            case .rinde: ZColor.bark100
            case .beeren: ZColor.berry100
            case .sumpf: ZColor.marsh100
            }
        }

        /// The deep shade: the 5 pt border and the ledge underneath it.
        var edge: Color {
            switch self {
            case .papier: ZColor.sand400
            case .wald: ZColor.olive700
            case .wiese: ZColor.olive600
            case .rufe: ZColor.orange700
            case .belohnung: ZColor.sun600
            case .federn: ZColor.clay700
            case .rinde: ZColor.bark700
            case .beeren: ZColor.berry700
            case .sumpf: ZColor.marsh700
            }
        }
    }

    /// The smallest square this tile draws, and the smallest one it can draw
    /// honestly.
    ///
    /// `--touch-hero`, the token the design set aside for exactly this control
    /// — "answer tiles and the big play button", and one of the three touch
    /// sizes spec § 3 fixes against Dynamic Type (64/96/160 pt). Issue #11
    /// asked for the design's 220 pt tile, which no phone has room for: the
    /// quiz measures 169 pt on an iPhone 17 and 162 pt on an iPhone 17e.
    ///
    /// Chosen rather than derived. Until #200 it was the width the attribution
    /// strip needed inside the photo, 168 pt, and arithmetic settled it; with
    /// the strip gone there is nothing left to measure. That a floor is wanted
    /// at all is because a good deal of the tile is drawn at a fixed size —
    /// the 56 pt badge, its 30 pt glyph, the 5 pt border, the 40 pt corner —
    /// and a small enough square is more of those than photo. Where exactly
    /// that starts is a judgement rather than a calculation, and the design
    /// has made it.
    ///
    /// It does not fit every phone, and it cannot: a 375×667 pt screen leaves
    /// the quiz room for about 81 pt a tile. The clamp below is the wrong
    /// answer for a caller in that position — it draws a tile the screen has
    /// no room for — so a caller with less room than this should scale the
    /// tile as a whole rather than hand the size over and hope. See
    /// `QuizTile`.
    public static let minimumSize = ZSpacing.touchHero

    /// `ChoiceTile.jsx`'s own default, and a comfortable iPad grid cell.
    public static let defaultSize: CGFloat = 260

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let image: Image?
    private let label: String
    private let tone: Tone
    private let dimmed: Bool
    private let action: () -> Void

    /// Where the tile stands in the round.
    let phase: Phase
    /// The edge length actually drawn, already clamped to ``minimumSize``.
    let size: CGFloat

    /// - Parameters:
    ///   - image: The bird photo, already resolved by the app — this package
    ///     loads nothing. Without one the tile shows the sand placeholder and
    ///     a bird glyph; ship real photos before launch.
    ///   - label: What VoiceOver announces, usually the bird's name. Required,
    ///     not optional: the tile shows no words at all, so without this it
    ///     would be an unnamed button.
    ///   - tone: The rubric tint. See ``Tone``.
    ///   - phase: See ``Phase``.
    ///   - dimmed: Fades a tile that is not the answer once the round is
    ///     resolved. Opacity only — the tile stays tappable, because a wrong
    ///     tap must never feel like a locked door.
    ///   - size: Edge length of the square, clamped up to ``minimumSize``.
    ///   - action: Run on tap.
    public init(
        image: Image? = nil,
        label: String,
        tone: Tone = .papier,
        phase: Phase = .idle,
        dimmed: Bool = false,
        size: CGFloat = ChoiceTile.defaultSize,
        action: @escaping () -> Void = {},
    ) {
        self.image = image
        self.label = label
        self.tone = tone
        self.phase = phase
        self.dimmed = dimmed
        self.size = max(size, Self.minimumSize)
        self.action = action
    }

    /// The colours this tile is painted in right now.
    var palette: ChoiceTilePalette {
        phase.palette(on: tone)
    }

    public var body: some View {
        Button(action: action) {
            face
        }
        .buttonStyle(ChoiceTileButtonStyle(palette: palette))
        // `translateY(-4px)` on a correct tile: the answer rises off the
        // page. An offset, so nothing around it moves.
        .offset(y: phase == .correct ? -ChoiceTileMetrics.correctLift : 0)
        .opacity(dimmed ? ChoiceTileMetrics.dimmedOpacity : 1)
        .animation(
            reduceMotion ? nil : ZMotion.easeBounce.animation(duration: ZMotion.slow),
            value: phase,
        )
        .animation(ZMotion.easeOut.animation(duration: ZMotion.fast), value: dimmed)
        // The verdict in the hand, beside the colour and the badge — see
        // ``Phase/feedback``. The closure form rather than the plain one:
        // only the phase a tile arrives at decides, so the whole grid falling
        // back to `idle` on the next question stays silent.
        .sensoryFeedback(trigger: phase) { _, arrived in arrived.feedback }
        .accessibilityLabel(label)
    }

    /// The square itself: photo or placeholder, and the phase badge on top.
    private var face: some View {
        Rectangle()
            .fill(tone.field)
            .overlay {
                if let image {
                    // Fills the square and crops what does not fit — the
                    // design asks for a centred square crop, never a letterbox.
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    Icon(
                        .bird,
                        size: .custom((size * ChoiceTileMetrics.placeholderRatio).rounded()),
                    )
                    .foregroundStyle(ZColor.bark500)
                }
            }
            .frame(width: size, height: size)
            // Clips the overflowing photo to the tile's own rounded corners.
            .clipShape(RoundedRectangle(cornerRadius: ZRadius.tile, style: .continuous))
            .overlay(alignment: .topTrailing) { badge }
    }

    /// The round check or rotate-ccw marker. It pops in with the phase change;
    /// the animation comes from the modifier on ``body``, which is the only
    /// place that knows whether the child asked for reduced motion.
    @ViewBuilder private var badge: some View {
        if let badge = phase.badge {
            Icon(badge.icon, size: .custom(ChoiceTileMetrics.badgeGlyph))
                .foregroundStyle(badge.foreground)
                .frame(
                    width: ChoiceTileMetrics.badgeDiameter,
                    height: ChoiceTileMetrics.badgeDiameter,
                )
                .background(Circle().fill(badge.fill))
                .padding(ChoiceTileMetrics.badgeInset)
                .transition(.scale(scale: ChoiceTileMetrics.badgeEntryScale)
                    .combined(with: .opacity))
        }
    }
}

// MARK: - Previews

#Preview("Phases, with a photo") {
    HStack(alignment: .top, spacing: ZSpacing.gapTiles) {
        ForEach(ChoiceTile.Phase.allCases, id: \.self) { phase in
            ChoiceTile(
                image: previewPhoto(),
                label: "Amsel",
                tone: .beeren,
                phase: phase,
                size: ChoiceTile.minimumSize,
            )
        }
    }
    .padding(ZSpacing.step7)
    .background(ZColor.surfacePage)
}

#Preview("The size set, and what stays fixed across it") {
    // The floor, the 220 pt #11 asked for, and the design's own tile. The row
    // is about the parts that do not scale with the square — the badge, its
    // glyph, the border and the corner — because they are what fixes
    // ``ChoiceTile/minimumSize`` where it is.
    HStack(alignment: .top, spacing: ZSpacing.gapTiles) {
        ForEach([ChoiceTile.minimumSize, 220, ChoiceTile.defaultSize], id: \.self) { size in
            ChoiceTile(
                image: previewPhoto(),
                label: "Amsel",
                tone: .beeren,
                phase: .correct,
                size: size,
            )
        }
    }
    .padding(ZSpacing.step7)
    .background(ZColor.surfacePage)
}

#Preview("A resolved round: one answer, three dimmed") {
    HStack(alignment: .top, spacing: ZSpacing.gapTiles) {
        ChoiceTile(
            image: previewPhoto(),
            label: "Zilpzalp",
            tone: .wald,
            phase: .correct,
            size: 230,
        )
        ChoiceTile(image: previewPhoto(), label: "Amsel", tone: .beeren, dimmed: true, size: 230)
        ChoiceTile(image: previewPhoto(), label: "Wiedehopf", tone: .rufe, dimmed: true, size: 230)
        ChoiceTile(image: previewPhoto(), label: "Blaumeise", tone: .sumpf, dimmed: true, size: 230)
    }
    .padding(ZSpacing.step7)
    .background(ZColor.surfacePage)
}

#Preview("Rubric tones, no photo yet") {
    ScrollView(.horizontal) {
        HStack(alignment: .top, spacing: ZSpacing.gapTiles) {
            ForEach(ChoiceTile.Tone.allCases, id: \.self) { tone in
                // 120 pt is below the floor and is clamped up to it.
                ChoiceTile(label: String(describing: tone), tone: tone, size: 120)
            }
        }
        .padding(ZSpacing.step7)
    }
    .background(ZColor.surfacePage)
}
