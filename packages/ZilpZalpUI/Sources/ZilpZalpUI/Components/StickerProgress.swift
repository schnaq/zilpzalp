import SwiftUI

/// How far a bird has come towards its sticker, told in markers.
///
/// One marker per recognition the sticker takes, filled from the left: a child
/// who cannot count to five still sees "nearly" and "all of them". No digits,
/// for the reason ``QuizProgress`` gives — the audience cannot read one.
///
/// **Not stars, and not leaves.** The stars on the round end are what the
/// round scored and the leaves in the quiz are how far the round has come;
/// this is neither, so it borrows the sticker's own sun instead. A filled
/// marker is `--color-reward`, the shade the sticker's rim is cut from, and an
/// empty one is the same sunken sand a locked sticker lies on.
///
/// **No outline.** Every other surface in this system carries a chunky one,
/// and at the 12 pt this row is drawn at in a phone's album a 3 pt rim would
/// be most of the marker. The fill carries the whole difference.
///
/// Spoken, the row splits in two exactly as ``QuizProgress`` does: ``label``
/// names it, ``value`` says where it stands, and both are finished text from
/// the caller — this package holds no product copy.
///
/// ```swift
/// StickerProgress(count: 3, of: 5, label: "Drei von fünf erkannt")
/// ```
public struct StickerProgress: View {
    /// The marker size the round end draws on an iPad. An album's stickers are
    /// smaller and pass their own; see ``init(count:of:label:value:markerSize:)``.
    public static let defaultMarkerSize: CGFloat = 20

    private let markerSize: CGFloat
    private let label: String
    private let value: String?

    /// How many markers there are, never negative.
    let total: Int
    /// How many of them are filled, clamped into `0 ... total`.
    let count: Int

    /// - Parameters:
    ///   - count: How far the bird has come. Clamped into `0 ... total`
    ///     rather than rejected: a bird recognised more often than its sticker
    ///     takes is a full row, not a trap.
    ///   - total: How many recognitions the sticker takes. A negative number
    ///     is read as none, which draws nothing at all.
    ///   - label: What this row *is*, as finished text, e.g. "Zwei von fünf
    ///     erkannt". Required: the markers carry no text of their own, so
    ///     without it the row would announce nothing.
    ///   - value: Where it stands, when the caller would rather split the
    ///     sentence the way VoiceOver does. Optional — an empty value is no
    ///     value, and the name alone is a complete announcement.
    ///   - markerSize: Diameter of one marker. Five of them and their gaps
    ///     want about six markers' width, so a row under an 80 pt sticker
    ///     takes 12 and one under a 200 pt sticker takes 24.
    public init(
        count: Int,
        of total: Int,
        label: String,
        value: String? = nil,
        markerSize: CGFloat = StickerProgress.defaultMarkerSize,
    ) {
        let clamped = max(total, 0)
        self.total = clamped
        self.count = min(max(count, 0), clamped)
        self.label = label
        self.value = value
        self.markerSize = markerSize
    }

    /// What the row draws, left to right — the whole visible state of this
    /// component. Everything else is colour and geometry.
    var filled: [Bool] {
        (0 ..< total).map { $0 < count }
    }

    public var body: some View {
        HStack(spacing: (markerSize * StickerProgressMetrics.gapRatio).rounded()) {
            ForEach(Array(filled.enumerated()), id: \.offset) { marker in
                Circle()
                    .fill(marker.element ? ZColor.reward : ZColor.surfaceSunken)
                    .frame(width: markerSize, height: markerSize)
            }
        }
        // One row, one announcement: five nameless circles would be noise.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label)
        .accessibilityValue(value ?? "")
    }
}

/// The row's own numbers. No JSX to port — the design export has no such row.
enum StickerProgressMetrics {
    /// The gap between two markers, as a share of one marker. Keyed to the
    /// marker rather than a spacing token so that a row always measures about
    /// six markers across, whichever sticker it sits under.
    static let gapRatio: CGFloat = 0.35
}

// MARK: - Previews

#Preview("A sticker filling up") {
    VStack(alignment: .leading, spacing: ZSpacing.step5) {
        ForEach(0 ... 5, id: \.self) { done in
            StickerProgress(count: done, of: 5, label: "\(done) von 5 erkannt")
        }
        // Twelve of five is not a state; the row clamps rather than complains.
        StickerProgress(count: 12, of: 5, label: "voll")
        StickerProgress(count: 2, of: -3, label: "nichts zu zeigen")
    }
    .padding(ZSpacing.step6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}

#Preview("Under the stickers it belongs to") {
    HStack(alignment: .top, spacing: ZSpacing.step7) {
        VStack(spacing: ZSpacing.step3) {
            RewardSticker(icon: .bird, size: 200)
            StickerProgress(count: 5, of: 5, label: "5 von 5 erkannt", markerSize: 24)
        }
        VStack(spacing: ZSpacing.step2) {
            RewardSticker(icon: .bird, locked: true, size: 80)
            StickerProgress(count: 2, of: 5, label: "2 von 5 erkannt", markerSize: 12)
        }
    }
    .padding(ZSpacing.step7)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfaceForest)
}
