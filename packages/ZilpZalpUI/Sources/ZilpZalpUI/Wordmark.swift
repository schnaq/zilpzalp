import SwiftUI

/// The ZilpZalp wordmark: "Zilp" and "Zalp" set solid in Baloo 2 ExtraBold.
///
/// Ported from `design/components/brand/Wordmark.jsx`. The design's guidance
/// stands: never restyle, outline, rotate or add a bird glyph to it — the
/// drawing lives in ``BrandMark``, and ``BrandLockup`` is how the two combine.
///
/// - Note: Baloo 2 is registered from the app bundle through `UIAppFonts`, not
///   from this package, so the previews below render in the system face. What
///   they show is the colour, the size and the tracking — the shape of the
///   letters only appears once the wordmark sits in the app.
public struct Wordmark: View {
    /// Which colours the two halves take.
    public enum Tone: Sendable, Hashable, CaseIterable {
        /// Olive and orange — the default, for the cream ground.
        case duo
        /// Both halves in the warm white, for photos and the forest ground.
        case monoLight
        /// Both halves in the soot ink, for a quiet mark on cream.
        case monoDark
    }

    /// The floor from the design brief. Smaller than this the two halves stop
    /// reading as one mark, so sizes below it are clamped rather than rejected
    /// — a caller passing 34 gets a legible wordmark, not a broken layout.
    public nonisolated static let minimumSize: CGFloat = 40

    /// The point size actually rendered: the requested size, never below
    /// ``minimumSize``.
    let size: CGFloat
    private let tone: Tone

    /// - Parameters:
    ///   - size: Type size in points, clamped up to ``minimumSize``. The `64`
    ///     default is the design's own; the top bar uses `44`.
    ///   - tone: Which colours the halves take.
    public init(size: CGFloat = 64, tone: Tone = .duo) {
        self.size = max(size, Self.minimumSize)
        self.tone = tone
    }

    public var body: some View {
        halves
            // The one place in this package that sizes type outside
            // `ZType.Step`: the wordmark's size is a free parameter (44 in the
            // top bar, 88 on a reward screen) and no step covers those, so it
            // goes through the module's other font entry point.
            //
            // The two are not yet one: `Step.font` is `fixedSize`, `ZFont.font`
            // still scales with Dynamic Type. `fix/zfont-fixed-size` aligns it,
            // and this call needs no change when it lands — until then an AX
            // text size grows the wordmark along with it.
            .font(ZFont.font(.display, weight: .extraBold, size: size))
            // `ZType.Step.tracking(_:)` resolves em to points for a step; this
            // is the same conversion for a free size.
            .tracking(size * ZType.Tracking.tightEm)
            // `white-space: nowrap` in the JSX: the mark is one word and must
            // never be squeezed or truncated by whatever holds it.
            .fixedSize(horizontal: true, vertical: false)
    }

    /// The two halves as one `Text`, so that font and tracking apply to the
    /// whole word and VoiceOver announces it as one.
    private var halves: Text {
        Text(ZBrand.leadingHalf).foregroundStyle(tone.leadingColor)
            + Text(ZBrand.trailingHalf).foregroundStyle(tone.trailingColor)
    }
}

/// The tone mapping straight from the ternaries in `Wordmark.jsx`: only `duo`
/// makes the mark two-coloured, both mono tones paint the whole word in one.
extension Wordmark.Tone {
    var leadingColor: Color {
        switch self {
        case .duo: ZColor.primary
        case .monoLight: ZColor.white
        case .monoDark: ZColor.textStrong
        }
    }

    var trailingColor: Color {
        switch self {
        case .duo: ZColor.accent
        case .monoLight: ZColor.white
        case .monoDark: ZColor.textStrong
        }
    }
}

#Preview("Wordmark tones on paper") {
    VStack(alignment: .leading, spacing: ZSpacing.step5) {
        Wordmark(size: 88, tone: .duo)
        Wordmark(size: 88, tone: .monoDark)
        // Barely legible on cream, and that is the point: `monoLight` belongs
        // on the forest ground or on a photo.
        Wordmark(size: 88, tone: .monoLight)
        Wordmark(size: Wordmark.minimumSize)
    }
    .padding(ZSpacing.step6)
    .background(ZColor.surfacePage)
}

#Preview("Wordmark tones on forest") {
    VStack(alignment: .leading, spacing: ZSpacing.step5) {
        Wordmark(size: 88, tone: .monoLight)
        Wordmark(size: 88, tone: .duo)
        Wordmark(size: 88, tone: .monoDark)
        Wordmark(size: Wordmark.minimumSize, tone: .monoLight)
    }
    .padding(ZSpacing.step6)
    .background(ZColor.surfaceForest)
}
