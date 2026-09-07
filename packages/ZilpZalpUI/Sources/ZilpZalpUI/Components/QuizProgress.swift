import SwiftUI

/// How far a round has come, told in leaves.
///
/// Ported from `design/components/quiz/QuizProgress.jsx`. One leaf per
/// question: grown olive for a question already answered, cream and outlined
/// for the one being played, sand for the ones still to come.
///
/// **No digits, anywhere.** Not "2/5", not "40 %", not a count. The audience
/// cannot read, and a number would be the only thing on the screen that
/// demanded it. The row is a shape that fills up, which is a thing a
/// four-year-old understands without being taught.
///
/// Spoken, the row splits in two: ``label`` names it and never changes,
/// ``value`` says where it stands. Both are finished text from the caller.
///
/// ```swift
/// TopBar(center: {
///     QuizProgress(
///         total: 5,
///         completed: 2,
///         current: 2,
///         label: "Fortschritt",
///         value: "Zwei von fünf",
///     )
/// })
/// ```
public struct QuizProgress: View {
    /// What one leaf is saying.
    enum LeafState: Hashable, Sendable {
        /// Answered. Olive on olive.
        case done
        /// The question in play. Cream, outlined, and a shade larger.
        case current
        /// Still to come. Sand.
        case upcoming

        var fill: Color {
            switch self {
            case .done: ZColor.primary
            case .current: ZColor.white
            case .upcoming: ZColor.surfaceSunken
            }
        }

        var glyph: Color {
            switch self {
            case .done: ZColor.white
            case .current, .upcoming: ZColor.olive300
            }
        }

        /// Only the current leaf is outlined; on the other two the outline
        /// would only compete with the fill.
        var outline: Color {
            switch self {
            case .done, .upcoming: .clear
            case .current: ZColor.primary
            }
        }
    }

    /// `QuizProgress.jsx`'s own leaf size. A round of five fits the top bar at
    /// this size on both iPhone and iPad.
    public static let defaultLeafSize: CGFloat = 44

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let leafSize: CGFloat
    private let label: String
    private let value: String?

    /// Questions in this round, never negative.
    let total: Int
    /// How many are answered, clamped into `0 ... total`.
    let completed: Int
    /// Which question is in play, or `nil` when none is — an index outside
    /// the round is dropped rather than drawn somewhere arbitrary.
    let current: Int?

    /// - Parameters:
    ///   - total: Questions in this round. Rounds are three to six long; a
    ///     negative number is read as none.
    ///   - completed: How many are answered. Clamped into `0 ... total`
    ///     rather than rejected — a progress row is not the place to trap
    ///     mid-game.
    ///   - current: The index of the question in play. Ignored when it falls
    ///     outside the round.
    ///   - label: What this row *is*, e.g. "Fortschritt". Required, and
    ///     stable: it names the element and does not change as the round
    ///     moves on.
    ///   - value: Where the round stands, as finished text — the counts belong
    ///     in the value slot, not folded into the name, so VoiceOver can tell
    ///     "what is this" from "where is it now". `HomeTile` draws the same
    ///     line for its stars.
    ///
    ///     The sentence is deliberately *not* assembled here: "2 von 5" is
    ///     German product copy and "2 of 5" is English copy in a German app,
    ///     and this package holds neither. The screen has the String Catalog;
    ///     it says the sentence, and this component puts it in the right slot.
    ///   - leafSize: Diameter of one leaf.
    public init(
        total: Int,
        completed: Int,
        current: Int? = nil,
        label: String,
        value: String? = nil,
        leafSize: CGFloat = QuizProgress.defaultLeafSize,
    ) {
        let clampedTotal = max(total, 0)
        self.total = clampedTotal
        self.completed = min(max(completed, 0), clampedTotal)
        self.current = current.flatMap { (0 ..< clampedTotal).contains($0) ? $0 : nil }
        self.label = label
        self.value = value
        self.leafSize = leafSize
    }

    /// What the row draws, left to right. The whole visible state of this
    /// component: everything else is colour and geometry.
    ///
    /// A question that is both answered and in play reads as answered — the
    /// leaf that just filled must not empty itself again when the round moves
    /// on.
    var leafStates: [LeafState] {
        (0 ..< total).map { index in
            if index < completed {
                .done
            } else if index == current {
                .current
            } else {
                .upcoming
            }
        }
    }

    public var body: some View {
        HStack(spacing: ZSpacing.step3) {
            ForEach(Array(leafStates.enumerated()), id: \.offset) { leafAtIndex in
                leaf(leafAtIndex.element)
            }
        }
        // One row, one announcement: five separate "leaf" elements would be
        // noise, and the leaves carry no text of their own to fall back on.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        // An empty value is no value: VoiceOver skips it, so a caller that
        // passes none simply gets the name.
        .accessibilityValue(value ?? "")
    }

    private func leaf(_ state: LeafState) -> some View {
        Icon(.leaf, size: .custom((leafSize * QuizProgressMetrics.glyphRatio).rounded()))
            .foregroundStyle(state.glyph)
            .frame(width: leafSize, height: leafSize)
            .background(Circle().fill(state.fill))
            .overlay(Circle().strokeBorder(state.outline, lineWidth: ZBorder.width))
            .scaleEffect(state == .current ? QuizProgressMetrics.currentScale : 1)
            // A leaf filling in is motion like any other: with reduced motion
            // it simply changes, without the bounce.
            .animation(
                reduceMotion ? nil : ZMotion.easeBounce.animation(duration: ZMotion.normal),
                value: state,
            )
    }
}

/// The row's own numbers, from the JSX.
enum QuizProgressMetrics {
    /// `Math.round(size * 0.52)` — the leaf inside its disc.
    static let glyphRatio: CGFloat = 0.52
    /// The question in play stands a little proud of the row.
    static let currentScale: CGFloat = 1.12
}

// MARK: - Previews

#Preview("A round filling up") {
    VStack(alignment: .leading, spacing: ZSpacing.step5) {
        ForEach(0 ... 5, id: \.self) { done in
            QuizProgress(total: 5, completed: done, current: done, label: "Fortschritt")
        }
    }
    .padding(ZSpacing.step6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}

#Preview("Round lengths and stray counts") {
    VStack(alignment: .leading, spacing: ZSpacing.step5) {
        QuizProgress(total: 3, completed: 0, current: 0, label: "Fortschritt")
        QuizProgress(total: 10, completed: 3, current: 3, label: "Fortschritt")
        QuizProgress(total: 10, completed: 10, label: "Fortschritt")
        // Twelve of ten is not a state; the row clamps rather than complains.
        QuizProgress(total: 10, completed: 12, current: 99, label: "Fortschritt")
        // A smaller leaf, for the narrower top bar on iPhone.
        QuizProgress(total: 5, completed: 2, current: 2, label: "Fortschritt", leafSize: 32)
    }
    .padding(ZSpacing.step6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}

#Preview("In the top bar, where it lives") {
    VStack(spacing: 0) {
        TopBar(
            leading: { IconButton(.chevronLeft, label: "zurück") {} },
            center: {
                QuizProgress(
                    total: 5,
                    completed: 2,
                    current: 2,
                    label: "Fortschritt",
                    value: "Zwei von fünf",
                )
            },
            trailing: { IconButton(.userRoundCog, label: "für Erwachsene", tone: .clay) {} },
        )
        Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}
