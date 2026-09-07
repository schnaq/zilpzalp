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
    /// `12px` left and right.
    static let horizontalPadding: CGFloat = 12
    /// `7px` — the text sits close to the photo's edge.
    static let bottomPadding: CGFloat = 7
    /// A photographer's name and licence fit on two lines at any tile size we
    /// draw; a third would start eating the bird.
    static let lineLimit = 2
}

#Preview("Credit on a photo field") {
    VStack(spacing: ZSpacing.step5) {
        ForEach(
            ["Foto: Andrej Chudý (CC BY)", "Foto: Alexis Tinker-Tsavalas (CC BY-SA 4.0)"],
            id: \.self,
        ) { credit in
            ZColor.bark300
                .frame(width: 260, height: 180)
                .overlay(alignment: .bottom) { PhotoCredit(text: credit) }
                .clipShape(RoundedRectangle(cornerRadius: ZRadius.tile, style: .continuous))
        }
    }
    .padding(ZSpacing.step6)
    .background(ZColor.surfacePage)
}
