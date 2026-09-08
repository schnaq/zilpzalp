import SwiftUI
import ZilpZalpUI

/// How one avatar is drawn: which glyph, which three colours, and what
/// VoiceOver calls it.
///
/// Three colours because the design draws an avatar as the same round,
/// outlined disc as ``RewardSticker`` — fill, outline, glyph. The sticker's
/// own `Tone` cannot serve here: it has four tones and there are eight
/// avatars, and the whole point below is that no two avatars share a colour.
struct AvatarStyle {
    let icon: ZIcon
    /// What VoiceOver reads. The picture is the point for a child who cannot
    /// read; this is for the grown-up who cannot see.
    let name: LocalizedStringResource
    let fill: Color
    let edge: Color
    let glyph: Color
}

extension AvatarStyle {
    /// **The avatar → colour mapping, and the only copy of it.**
    ///
    /// A four-year-old finds their own card before they can read the name
    /// under it, and from across the table. Shape alone is a thin signal at
    /// that distance — a leaf and a feather are both "green pointy thing" — so
    /// no two choices share a fill. Seven light tints and, for `sparkles`, a
    /// dark olive: a disc nobody mistakes for the pale one beside it, which is
    /// what an eighth *light* tint would have been.
    ///
    /// Sand and cream are deliberately absent. Those are what ``RewardSticker``
    /// greys a *locked* sticker with, and an avatar that borrows the "not yet"
    /// colour would tell a child their own card is out of reach.
    ///
    /// Two pairs are closer than the rest, and measuring says how close: leaf
    /// against lightbulb is ΔE76 10.8, star against house 13.0, where every
    /// other pair is 24.5 or more. The palette is warm-only — three greens and
    /// three tan-oranges among eight — so separating those two pairs by hue is
    /// not on offer, and separating them by lightness would push one of each
    /// into the dark olive `sparkles` already occupies. They stay, because the
    /// glyphs carry the difference where the colour thins out: a leaf is not a
    /// lightbulb and a star is not a house at any size. Worth revisiting when
    /// Johanna's pictures (#45) replace the glyphs, which is the moment the
    /// shape stops being a flat line drawing.
    ///
    /// When Johanna's pictures replace the glyphs (#45) the picture arrives
    /// here and the colours stay: colour is the half of the signal that
    /// survives a dirty screen and a child who looks for a second, not a
    /// minute.
    private static let styles: [AvatarStyle] = [
        AvatarStyle(
            icon: .bird,
            name: "profile.avatar.bird",
            fill: ZColor.sun300,
            edge: ZColor.sun600,
            glyph: ZColor.bark700,
        ),
        AvatarStyle(
            icon: .egg,
            name: "profile.avatar.egg",
            fill: ZColor.clay100,
            edge: ZColor.clay300,
            glyph: ZColor.clay700,
        ),
        AvatarStyle(
            icon: .feather,
            name: "profile.avatar.feather",
            fill: ZColor.berry300,
            edge: ZColor.berry700,
            glyph: ZColor.berry700,
        ),
        AvatarStyle(
            icon: .leaf,
            name: "profile.avatar.leaf",
            fill: ZColor.marsh300,
            edge: ZColor.marsh700,
            glyph: ZColor.marsh700,
        ),
        AvatarStyle(
            icon: .star,
            name: "profile.avatar.star",
            fill: ZColor.orange200,
            edge: ZColor.orange600,
            glyph: ZColor.orange700,
        ),
        AvatarStyle(
            icon: .sparkles,
            name: "profile.avatar.sparkles",
            fill: ZColor.olive500,
            edge: ZColor.olive700,
            glyph: ZColor.cream50,
        ),
        AvatarStyle(
            icon: .house,
            name: "profile.avatar.house",
            fill: ZColor.bark300,
            edge: ZColor.bark700,
            glyph: ZColor.bark700,
        ),
        AvatarStyle(
            icon: .lightbulb,
            name: "profile.avatar.lightbulb",
            fill: ZColor.olive200,
            edge: ZColor.olive600,
            glyph: ZColor.olive800,
        ),
    ]

    /// What to draw for a stored `Profile.avatar`.
    ///
    /// That field is a string from disk rather than an enum, so it can name a
    /// glyph this build has never heard of: a file written by a newer version,
    /// or one of Johanna's pictures (#45) once they land. Such a name gets
    /// ``unknown`` — never a crash, and never an empty hole where a child's
    /// own card should be.
    static func avatar(_ name: String) -> AvatarStyle {
        styles.first { $0.icon.rawValue == name } ?? .unknown
    }

    /// The plus on the "Neues Nest" card. The one disc that is a door rather
    /// than a bird, so it wears the primary olive instead of an avatar's tint
    /// and cannot be mistaken for a child who already exists.
    static let newNest = AvatarStyle(
        icon: .plus,
        name: "profile.picker.new",
        fill: ZColor.primary,
        edge: ZColor.primaryShadow,
        glyph: ZColor.textOnColor,
    )

    /// An avatar name this build does not know. It draws the plain bird on
    /// sand, and it is named after the glyph it actually shows rather than
    /// after the name it failed to resolve — VoiceOver should describe the
    /// picture in front of the grown-up, not the app's disappointment.
    static let unknown = AvatarStyle(
        icon: .bird,
        name: "profile.avatar.bird",
        fill: ZColor.surfaceSunken,
        edge: ZColor.borderCard,
        glyph: ZColor.ink300,
    )
}

/// A glyph on its own coloured disc: a profile's avatar, and the plus that
/// opens a new one.
///
/// Decorative throughout — every disc in this feature sits inside a button,
/// and the button carries the name. Two accessibility elements where a child
/// sees one thing would only make VoiceOver say it twice.
struct AvatarDisc: View {
    /// How much of the disc the glyph fills. ``IconButton``'s ratio and
    /// ``RewardSticker``'s, so all three read at the same weight.
    private static let glyphRatio: CGFloat = 0.45

    let style: AvatarStyle
    let diameter: CGFloat
    /// Draws the focus ring around the disc — the chosen avatar on the
    /// creation screen. Colour alone could not carry it: the ring has to show
    /// on eight different fills.
    var chosen = false

    var body: some View {
        Icon(style.icon, size: .custom((diameter * Self.glyphRatio).rounded()))
            .foregroundStyle(style.glyph)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(style.fill))
            .overlay { Circle().strokeBorder(style.edge, lineWidth: ZBorder.width) }
            .overlay { ring }
            .accessibilityHidden(true)
    }

    /// Sits *outside* the disc — negative padding on an overlay grows it
    /// outward — so the ring never eats into the picture it is pointing at.
    ///
    /// `ZColor.focusRing` at full strength rather than
    /// ``ZShadow/focusRingColor``, which is the same orange at 45 %. That one
    /// is sized for a keyboard focus ring on the cream page; this ring has to
    /// stay obvious against eight different fills, two of them dark, and it
    /// says "this is the one you picked" rather than "this has focus".
    @ViewBuilder private var ring: some View {
        if chosen {
            Circle()
                .strokeBorder(ZColor.focusRing, lineWidth: ZShadow.focusRingWidth)
                .padding(-ZShadow.focusRingWidth)
        }
    }
}

#Preview("The eight choices, and the two discs that are not avatars") {
    VStack(spacing: ZSpacing.step6) {
        HStack(spacing: ZSpacing.step5) {
            ForEach(["bird", "egg", "feather", "leaf"], id: \.self) { name in
                AvatarDisc(style: .avatar(name), diameter: 96)
            }
        }
        HStack(spacing: ZSpacing.step5) {
            ForEach(["star", "sparkles", "house", "lightbulb"], id: \.self) { name in
                AvatarDisc(style: .avatar(name), diameter: 96)
            }
        }
        HStack(spacing: ZSpacing.step5) {
            AvatarDisc(style: .newNest, diameter: 96)
            AvatarDisc(style: .avatar("a picture that does not exist yet"), diameter: 96)
            AvatarDisc(style: .avatar("star"), diameter: 96, chosen: true)
        }
    }
    .padding(ZSpacing.step7)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}
