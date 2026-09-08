import SwiftUI

/// The attribution strip that sits *inside* a photo, along its bottom edge.
///
/// `design/readme.md` fixes the treatment: cream text on a warm protection
/// gradient, bottom-left, small enough that a child ignores it and legible
/// enough that a CC BY photo is properly credited. Never a caption row under
/// the image, never over the bird's head.
///
/// Internal on purpose. It is not a component a screen composes with; it is
/// the one credit rendering shared by ``ChoiceTile`` and ``RewardSticker``, so
/// that two places showing the same photo cannot drift apart. Whether a photo
/// needs a credit at all is the caller's call — this package knows nothing
/// about licences.
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
            // Leading and trailing differ: the left edge is the one the
            // rounded corner eats into. See ``PhotoCreditMetrics/leadingPadding``.
            .padding(.leading, PhotoCreditMetrics.leadingPadding)
            .padding(.trailing, PhotoCreditMetrics.trailingPadding)
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
    /// `12px` right. The design pads both sides with it; here only this one
    /// still can — see ``leadingPadding``.
    static let trailingPadding: CGFloat = 12
    /// What the left edge needs instead of ``trailingPadding``.
    ///
    /// `design/components/quiz/ChoiceTile.jsx` hangs this strip under the
    /// bottom of a `size * 0.78` photo band that has the bird's name below
    /// it, so it sits on a straight edge and `12px` clears everything. This
    /// port draws no name — quiz tiles are wordless — the photo fills the
    /// whole square, and the strip lands on the tile's own corner. Two things
    /// then cross the first glyph: the 40 pt curve, and the 5 pt border
    /// ``ChoiceTile`` strokes *inside* the same shape, which the CSS draws
    /// outside the photo. Insetting by the radius puts the text back on the
    /// straight part of the edge, where the design always had it.
    ///
    /// Only the leading side. Trailing stays at ``trailingPadding``: the text is
    /// left-aligned, so a wrapped line ends well before the right corner, and
    /// a second inset would cost width the licence needs.
    static let leadingPadding = ZRadius.tile
    /// `7px` — the text sits close to the photo's edge.
    static let bottomPadding: CGFloat = 7
    /// A photographer's name and licence fit on two lines at any tile size we
    /// draw; a third would start eating the bird.
    static let lineLimit = 2
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

#Preview("The corner, at the smallest tile there is") {
    // In its real host, at ``ChoiceTile/minimumSize``: the narrowest strip the
    // component ever draws, over the 40 pt corner *and* under the 5 pt border
    // the tile strokes inside the same shape. Both used to cut into the first
    // glyph — which is why the bare field above is not enough to judge this.
    //
    // The `CC BY-SA 4.0` line runs out of column at this size and is truncated.
    // That is #111 rather than a new fault, and it is the reason the floor is
    // where it is: the base pack's own longest line, a `CC BY`, still holds two
    // whole lines here — see ``ChoiceTile/minimumSize``.
    HStack(alignment: .top, spacing: ZSpacing.gapTiles) {
        ForEach(previewCredits, id: \.self) { credit in
            ChoiceTile(
                label: "Amsel",
                credit: credit,
                tone: .beeren,
                size: ChoiceTile.minimumSize,
            )
        }
    }
    .padding(ZSpacing.step7)
    .background(ZColor.surfacePage)
}

/// The worst case for the corner: a name long enough to wrap onto the line
/// that sits deepest in the curve, and one that starts on a narrow glyph,
/// where a clip is hardest to spot and easiest to misread.
private let previewCredits = [
    "Foto: Alexis Tinker-Tsavalas (CC BY-SA 4.0)",
    "Jane Ivanović-Tremayne (CC BY)",
]
