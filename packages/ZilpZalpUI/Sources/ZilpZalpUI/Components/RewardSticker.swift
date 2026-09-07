import SwiftUI

/// A collected bird, as a sticker in an album.
///
/// Ported from `design/components/quiz/RewardSticker.jsx`. A round, outlined
/// disc holding a photo or a glyph, tilted a few degrees so it looks stuck on
/// rather than laid out.
///
/// **Locked stickers stay visible.** A sticker not yet earned is drawn in
/// grey with a padlock, never hidden and never an empty slot: what a child
/// can see is what a child can want. It also sits straight — the tilt is the
/// reward.
///
/// Not a control. Like ``Badge``, it has no action and no press state; a
/// screen that wants a tappable sticker wraps it in its own `Button`.
///
/// ```swift
/// RewardSticker(image: photo, credit: "Foto: … (CC BY)", label: "Zilpzalp")
/// ```
public struct RewardSticker: View {
    /// The four sticker tints from the JSX. `rare` is the berry one; keep it
    /// for genuinely rare finds so it keeps meaning something.
    public enum Tone: CaseIterable, Hashable, Sendable {
        case sun
        case leaf
        case hoopoe
        case rare

        var palette: RewardStickerPalette {
            switch self {
            case .sun:
                RewardStickerPalette(
                    background: ZColor.sun300,
                    edge: ZColor.sun600,
                    foreground: ZColor.bark700,
                )
            case .leaf:
                RewardStickerPalette(
                    background: ZColor.olive200,
                    edge: ZColor.olive600,
                    foreground: ZColor.olive800,
                )
            case .hoopoe:
                RewardStickerPalette(
                    background: ZColor.orange200,
                    edge: ZColor.orange600,
                    foreground: ZColor.orange700,
                )
            case .rare:
                RewardStickerPalette(
                    background: ZColor.berry300,
                    edge: ZColor.berry700,
                    foreground: ZColor.white,
                )
            }
        }
    }

    /// `RewardSticker.jsx`'s own default. The reward screen shows one at 200.
    public static let defaultSize: CGFloat = 140

    /// The `rotate(-4deg)` of the JSX, and the "stickers sit at −4°" line in
    /// `design/readme.md`.
    public static let defaultRotation = Angle.degrees(-4)

    private let image: Image?
    private let icon: ZIcon
    private let credit: String?
    private let label: String?
    private let tone: Tone
    private let rotation: Angle
    private let size: CGFloat

    /// Not earned yet.
    let locked: Bool

    /// - Parameters:
    ///   - image: The bird photo, already resolved by the app. Without one the
    ///     sticker shows ``icon`` on its tone.
    ///   - icon: The glyph to show when there is no photo.
    ///   - credit: Attribution, rendered inside the photo along its bottom
    ///     edge — the same strip ``ChoiceTile`` uses. Required by the licence
    ///     for CC BY material; the caller decides, this package cannot tell.
    ///   - label: The word under the sticker, usually the bird's name.
    ///     Optional: an album of stickers may caption them or not.
    ///   - tone: See ``Tone``. Ignored while ``locked``.
    ///   - locked: Not earned yet. The sticker turns grey, gains a padlock and
    ///     loses its tilt — but keeps its picture, so a child can see what is
    ///     still out there.
    ///   - rotation: How far the sticker is tilted. Straightened while locked.
    ///   - size: Diameter of the disc.
    public init(
        image: Image? = nil,
        icon: ZIcon = .star,
        credit: String? = nil,
        label: String? = nil,
        tone: Tone = .sun,
        locked: Bool = false,
        rotation: Angle = RewardSticker.defaultRotation,
        size: CGFloat = RewardSticker.defaultSize,
    ) {
        self.image = image
        self.icon = icon
        self.credit = credit
        self.label = label
        self.tone = tone
        self.locked = locked
        self.rotation = rotation
        self.size = size
    }

    /// The colours the disc is drawn in: grey sand while locked, its tone
    /// otherwise.
    var palette: RewardStickerPalette {
        locked ? .locked : tone.palette
    }

    /// The glyph in the middle when there is no photo: a padlock while
    /// locked, the sticker's own otherwise.
    var displayedIcon: ZIcon {
        locked ? .lock : icon
    }

    /// Whether the photo is drawn. A locked sticker keeps it — greyed out,
    /// with the padlock moved to a badge — because hiding it would hide the
    /// very thing worth collecting.
    var showsImage: Bool {
        image != nil
    }

    /// A locked sticker sits straight. The tilt is part of the reward.
    var displayedRotation: Angle {
        locked ? .zero : rotation
    }

    public var body: some View {
        VStack(spacing: ZSpacing.step2) {
            disc
            if let label {
                Text(verbatim: label)
                    .font(ZType.Step.body.font(.display, weight: .bold))
                    .lineSpacing(ZType.Step.body.lineSpacing)
                    .foregroundStyle(locked ? ZColor.textMuted : ZColor.textStrong)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: size + RewardStickerMetrics.labelOverhang)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var disc: some View {
        Circle()
            .fill(palette.background)
            .overlay {
                if let image {
                    image
                        .resizable()
                        .scaledToFill()
                        // Locked keeps the picture but takes its colour away,
                        // so it reads as "not yet" without disappearing.
                        .grayscale(locked ? 1 : 0)
                        .opacity(locked ? RewardStickerMetrics.lockedPhotoOpacity : 1)
                } else {
                    Icon(
                        displayedIcon,
                        size: .custom((size * RewardStickerMetrics.glyphRatio).rounded()),
                    )
                    .foregroundStyle(palette.foreground)
                }
            }
            .overlay(alignment: .bottom) {
                if let credit, showsImage {
                    PhotoCredit(text: credit)
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay { Circle().strokeBorder(palette.edge, lineWidth: ZBorder.widthThick) }
            .overlay(alignment: .bottomTrailing) { lockBadge }
            .shadow(
                color: locked ? .clear : ZShadow.medium.color,
                radius: ZShadow.medium.radius,
                x: ZShadow.medium.offsetX,
                y: ZShadow.medium.offsetY,
            )
            .rotationEffect(displayedRotation)
    }

    /// The padlock for a locked sticker that shows a photo. Without a photo
    /// the padlock is already the glyph in the middle, and a second one would
    /// only shout.
    @ViewBuilder private var lockBadge: some View {
        if locked, showsImage {
            let diameter = (size * RewardStickerMetrics.badgeRatio).rounded()

            Icon(.lock, size: .custom((diameter * RewardStickerMetrics.badgeGlyphRatio).rounded()))
                .foregroundStyle(RewardStickerPalette.locked.foreground)
                .frame(width: diameter, height: diameter)
                .background(Circle().fill(RewardStickerPalette.locked.background))
                .overlay {
                    Circle().strokeBorder(
                        RewardStickerPalette.locked.edge,
                        lineWidth: ZBorder.width,
                    )
                }
        }
    }
}

/// The three colours one sticker is drawn in.
struct RewardStickerPalette: Sendable, Hashable {
    let background: Color
    let edge: Color
    let foreground: Color

    /// Not earned yet: sand, sand, muted ink — the same greying `HomeTile`
    /// uses for an activity that has not opened.
    static let locked = RewardStickerPalette(
        background: ZColor.surfaceSunken,
        edge: ZColor.borderCard,
        foreground: ZColor.ink300,
    )
}

/// The sticker's own numbers, from the JSX.
enum RewardStickerMetrics {
    /// `Math.round(size * 0.45)` — the glyph inside the disc.
    static let glyphRatio: CGFloat = 0.45
    /// `maxWidth: size + 40` for the caption under it.
    static let labelOverhang: CGFloat = 40
    /// How far a locked photo is faded behind its grey.
    static let lockedPhotoOpacity: Double = 0.7
    /// The padlock badge over a locked photo. No JSX equivalent — the JSX
    /// drops the photo instead of keeping it — so this is sized to stay
    /// legible at the 140 pt default without covering the bird.
    static let badgeRatio: CGFloat = 0.34
    /// The padlock inside that badge.
    static let badgeGlyphRatio: CGFloat = 0.55
}

// MARK: - Previews

#Preview("Tones, earned and locked") {
    VStack(spacing: ZSpacing.step6) {
        HStack(spacing: ZSpacing.step6) {
            ForEach(RewardSticker.Tone.allCases, id: \.self) { tone in
                RewardSticker(icon: .star, label: String(describing: tone), tone: tone)
            }
        }
        HStack(spacing: ZSpacing.step6) {
            ForEach(RewardSticker.Tone.allCases, id: \.self) { tone in
                RewardSticker(
                    icon: .star,
                    label: String(describing: tone),
                    tone: tone,
                    locked: true,
                )
            }
        }
    }
    .padding(ZSpacing.step7)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}

#Preview("With a photo: collected and still to find") {
    HStack(spacing: ZSpacing.step7) {
        RewardSticker(
            image: previewPhoto(),
            credit: "Foto: A. Chudý (CC BY)",
            label: "Zilpzalp gesammelt",
            size: 200,
        )
        RewardSticker(
            image: previewPhoto(),
            credit: "Foto: A. Chudý (CC BY)",
            label: "Wiedehopf",
            locked: true,
            size: 200,
        )
    }
    .padding(ZSpacing.step7)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfaceForest)
}

#Preview("Tilt, and a glyph album") {
    VStack(spacing: ZSpacing.step6) {
        HStack(spacing: ZSpacing.step6) {
            ForEach([-12.0, -4.0, 0.0, 7.0], id: \.self) { degrees in
                RewardSticker(icon: .feather, tone: .hoopoe, rotation: .degrees(degrees), size: 110)
            }
        }
        HStack(spacing: ZSpacing.step6) {
            RewardSticker(icon: .star, label: "Erster Stern", tone: .sun, size: 110)
            RewardSticker(icon: .music, label: "Zehn Rufe", tone: .leaf, size: 110)
            RewardSticker(icon: .sparkles, label: "Selten", tone: .rare, locked: true, size: 110)
            RewardSticker(icon: .egg, label: "Bald", tone: .leaf, locked: true, size: 110)
        }
    }
    .padding(ZSpacing.step7)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}
