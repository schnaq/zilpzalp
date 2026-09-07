import SwiftUI

/// ``BrandMark`` and ``Wordmark`` side by side — the app's signature on the
/// start screen and above the grown-up area.
///
/// Horizontal only. No screen in `design/ui_kits/ipad_app/` composes the two:
/// `HomeScreen.jsx` puts the wordmark alone in the top bar and
/// `GrownupsScreen.jsx` shows no brand at all, so a stacked arrangement would
/// be invented rather than ported. It can be added when a screen asks for one.
public struct BrandLockup: View {
    /// Mark edge length as a multiple of the wordmark's type size.
    ///
    /// The drawing fills 95.7 % of its square frame vertically (measured off
    /// `assets/logo.svg`), and "ZilpZalp" runs almost the full em from the `l`
    /// ascender to the `p` descender. At 1.2 the bird therefore stands about a
    /// sixth taller than the word — leading the pair without dwarfing it.
    private static let markSizeRatio: CGFloat = 1.2

    /// Gap as a multiple of the wordmark's type size.
    ///
    /// A third of the type size is the gap the pair wants to read as one unit,
    /// but the mark brings part of it along: its artwork leaves ~12 % of a
    /// frame that is itself 1.2 × the type size free on the right, which is
    /// already 0.14 of it. The layout only has to add the rest.
    private static let spacingRatio: CGFloat = 0.2

    /// Kept as a value rather than as a size so the pair inherits
    /// ``Wordmark/minimumSize`` from one clamp instead of two.
    let wordmark: Wordmark
    private let accessibilityLabel: String

    /// - Parameters:
    ///   - size: The wordmark's type size in points; the mark scales with it.
    ///     Clamped up to ``Wordmark/minimumSize``.
    ///   - tone: Which colours the wordmark takes. The mark keeps its own
    ///     colours in every tone — it is drawn art, not a glyph.
    ///   - accessibilityLabel: What VoiceOver announces for the pair, which is
    ///     one element rather than two. ``ZBrand/name`` by default.
    public init(
        size: CGFloat = 64,
        tone: Wordmark.Tone = .duo,
        accessibilityLabel: String = ZBrand.name,
    ) {
        wordmark = Wordmark(size: size, tone: tone)
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        // Both ratios are taken off the requested point size, which is what the
        // wordmark asks for rather than what it finally draws: until
        // `fix/zfont-fixed-size` lands, an AX text size grows the word but not
        // the mark, and the proportions below drift with it. Worth a look at
        // the previews once that PR is in.
        HStack(spacing: wordmark.size * Self.spacingRatio) {
            BrandMark(size: wordmark.size * Self.markSizeRatio)
            wordmark
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview("Lockup on paper") {
    VStack(alignment: .leading, spacing: ZSpacing.step6) {
        BrandLockup(size: 88)
        BrandLockup(size: 44, tone: .monoDark)
    }
    .padding(ZSpacing.step6)
    .background(ZColor.surfacePage)
}

#Preview("Lockup on forest") {
    VStack(alignment: .leading, spacing: ZSpacing.step6) {
        BrandLockup(size: 88, tone: .monoLight)
        BrandLockup(size: 44, tone: .monoLight)
    }
    .padding(ZSpacing.step6)
    .background(ZColor.surfaceForest)
}
