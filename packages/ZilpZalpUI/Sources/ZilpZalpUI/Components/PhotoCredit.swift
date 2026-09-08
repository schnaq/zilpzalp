import SwiftUI

/// The attribution strip that sits *inside* a photo, along its bottom edge.
///
/// `design/readme.md` fixes the treatment: cream text on a warm protection
/// gradient, bottom-left, small enough that a child ignores it and legible
/// enough that a CC BY photo is properly credited. Never a caption row under
/// the image, never over the bird's head.
///
/// Internal on purpose. It is not a component a screen composes with; it is
/// the one credit rendering the package has, so that two hosts showing the
/// same photo cannot drift apart. In practice that is ``ChoiceTile``:
/// ``RewardSticker`` can be handed a credit but is never given one, because a
/// straight strip has no right inset inside a circle — see the note there.
/// Whether a photo needs a credit at all is the caller's call; this package
/// knows nothing about licences.
struct PhotoCredit: View {
    /// The finished credit line, e.g. `"Foto: Andrej Chudý (CC BY)"`. Composed
    /// by the app from the pack manifest; never assembled here.
    let text: String

    var body: some View {
        Text(verbatim: text)
            // 13 pt is below the type scale's floor on purpose: the scale
            // starts at 20 pt because that is what a child reads, and this
            // line is for adults and for the licence. `design/readme.md`
            // caps it at 14 pt.
            .font(ZFont.font(.body, weight: .semibold, size: PhotoCreditMetrics.size))
            .foregroundStyle(ZColor.cream50)
            .lineLimit(PhotoCreditMetrics.lineLimit)
            .frame(maxWidth: .infinity, alignment: .leading)
            // Both edges by the same amount: both corners are the same
            // corner. See ``PhotoCreditMetrics/horizontalPadding``.
            .padding(.horizontal, PhotoCreditMetrics.horizontalPadding)
            .padding(.top, PhotoCreditMetrics.topPadding)
            .padding(.bottom, PhotoCreditMetrics.bottomPadding)
            .background {
                // `linear-gradient(to top, rgba(42,34,19,.55), rgba(42,34,19,0))`
                // — `--ink-900` fading upwards out of the photo. Not
                // ``ZColor/scrim``: that is the 45 % modal veil, a different
                // job at a different opacity.
                LinearGradient(
                    colors: [.clear, ZColor.ink900.opacity(PhotoCreditMetrics.gradientOpacity)],
                    startPoint: .top,
                    endPoint: .bottom,
                )
            }
    }
}

/// The credit strip's own numbers. Most of them have no token: the type scale
/// stops at 16 pt and the spacing scale has no 14 or 7, so those are the
/// design's literals, named once instead of sprinkled through the view.
enum PhotoCreditMetrics {
    /// `13px/1.2 Nunito semibold`, and `design/readme.md`'s hard ceiling of
    /// 14 pt.
    static let size: CGFloat = 13
    /// `rgba(42,34,19,.55)` at the bottom of the gradient.
    static let gradientOpacity: Double = 0.55
    /// The `14px` top padding, which is also what makes the gradient band
    /// tall enough to protect the text.
    static let topPadding: CGFloat = 14
    /// `7px` in the design, one point more here — see
    /// ``horizontalPadding``, which that point pays for.
    static let bottomPadding: CGFloat = 8
    /// What both side edges have to give up to the host's rounded corner.
    ///
    /// `design/components/quiz/ChoiceTile.jsx` hangs this strip under the
    /// bottom of a `size * 0.78` photo band that has the bird's name below
    /// it, so it sits on a straight edge and `12px` clears everything. This
    /// port draws no name — quiz tiles are wordless — the photo fills the
    /// whole square, and the strip lands on the tile's own corner, where two
    /// things cross a glyph: the 40 pt curve, and the 5 pt border
    /// ``ChoiceTile`` strokes *inside* the same shape, which the CSS draws
    /// outside the photo.
    ///
    /// So the region a glyph may be drawn in is the tile's shape inset by the
    /// border, a corner of radius `tile − widthThick`. The lowest line of
    /// text has its box bottom ``bottomPadding`` above the tile's edge, which
    /// is `bottomPadding − widthThick` deep into that inner corner, and a
    /// circle of radius `r` stands `r − √(2rd − d²)` off the edge at depth
    /// `d`. That is 25.82, so 26.
    ///
    /// The tile's corner is `.continuous` rather than circular, and asks for
    /// about 26.07 at that depth — so the bottom corner of the text's *box*
    /// lands on the border's inner edge to within a tenth of a point rather
    /// than safely inside it. What clears it is that no glyph reaches the
    /// bottom of its own box: the deepest ink these lines draw stops some
    /// 2.5 pt above it, where the same edge stands under 23 pt off. That is a
    /// claim about type rather than about geometry, so it is not asserted
    /// here — `PhotoCreditClippingTests` puts it to the renderer.
    ///
    /// Both edges, because both corners are the same corner. #103 inset only
    /// the leading one, by the whole radius, and left the trailing one at
    /// `12px` on the grounds that a wrapped line ends well before it — true
    /// of a line that wraps, false of a credit short enough to stay on one
    /// (#111). Splitting the same 52 pt evenly fixes that and costs nothing:
    /// every tile size keeps the column, and therefore the wrap, it had.
    ///
    /// The one point of extra ``bottomPadding`` is what makes it fit. The
    /// corner's demand falls steeply with height — 28.88 pt a side at the
    /// design's `7px`, 26 at `8px` — and at 29 a side ``ChoiceTile``'s
    /// derived floor would land at 174 pt, above the 169 an iPhone 17
    /// measures, which would put the phone back on the transform #104
    /// removed.
    static let horizontalPadding: CGFloat = {
        let radius = ZRadius.tile - ZBorder.widthThick
        let depth = bottomPadding - ZBorder.widthThick
        let arc = radius - (2 * radius * depth - depth * depth).squareRoot()
        return (ZBorder.widthThick + arc).rounded(.up)
    }()

    /// A photographer's name and licence fit on two lines at any tile size we
    /// draw; a third would start eating the bird.
    static let lineLimit = 2
    /// The narrowest text column this strip may be given.
    ///
    /// Measured rather than chosen: the widest attribution the base pack
    /// produces, "Foto: Alexis Tinker-Tsavalas (CC BY)", needs this much
    /// column to hold ``lineLimit`` lines of the bundled Nunito SemiBold at
    /// ``size``. Anything narrower truncates the licence away, which is not a
    /// cosmetic loss. ``ChoiceTile/minimumSize`` is this plus the two paddings
    /// — the strip is what decides how small an answer tile can be.
    ///
    /// It is a floor for what ships today, not a promise: a longer
    /// photographer's name, or a `CC BY-SA 4.0` line, still needs a third line
    /// at that tile size. Widening the column rather than raising this number
    /// is what #122's gutter is for.
    static let minimumColumn: CGFloat = 115.3
}

#Preview("Credit on a photo field") {
    VStack(spacing: ZSpacing.step5) {
        ForEach(previewCredits, id: \.self) { credit in
            ZColor.bark300
                .frame(width: 260, height: 180)
                .overlay(alignment: .bottom) { PhotoCredit(text: credit) }
                .clipShape(RoundedRectangle(cornerRadius: ZRadius.tile, style: .continuous))
        }
    }
    .padding(ZSpacing.step6)
    .background(ZColor.surfacePage)
}

#Preview("Both corners, at every size the tile draws") {
    // In its real host: over the 40 pt corner *and* under the 5 pt border the
    // tile strokes inside the same shape, which is why the bare field above is
    // not enough to judge this. One size is not enough either — the line that
    // clipped last was not the one that wraps at the floor but the one short
    // enough to stay on a single line at 220 pt, where it fills the deepest
    // line to within a few points of the trailing corner (#111).
    //
    // The `CC BY-SA 4.0` line runs out of column at the floor and is
    // truncated. It is a fabrication rather than an attribution the base pack
    // produces, and it is the reason the floor is where it is: the pack's own
    // longest line, a `CC BY`, still holds two whole lines there — see
    // ``ChoiceTile/minimumSize``.
    ScrollView([.horizontal, .vertical]) {
        VStack(alignment: .leading, spacing: ZSpacing.gapTiles) {
            ForEach([ChoiceTile.minimumSize, 220, ChoiceTile.defaultSize], id: \.self) { size in
                HStack(alignment: .top, spacing: ZSpacing.gapTiles) {
                    ForEach(previewCredits, id: \.self) { credit in
                        ChoiceTile(label: "Amsel", credit: credit, tone: .beeren, size: size)
                    }
                }
            }
        }
        .padding(ZSpacing.step7)
    }
    .background(ZColor.surfacePage)
}

/// The three worst cases for the corners: a credit short enough to stay on one
/// line, and so to run the full width of the line that sits deepest in the
/// curve; the longest one the base pack produces, which wraps onto that line
/// instead; and a name that starts on a narrow glyph, where a clip on the
/// leading side is hardest to spot and easiest to misread.
///
/// Internal rather than private, as `previewPhoto()` is: `PhotoCreditClippingTests`
/// asserts on exactly these three, and a preview showing a different set from
/// the one the test guards would be worse than no preview.
let previewCredits = [
    "Foto: Dmitry Ivanov (CC BY)",
    "Foto: Alexis Tinker-Tsavalas (CC BY)",
    "Jane Ivanović-Tremayne (CC BY-SA 4.0)",
]
