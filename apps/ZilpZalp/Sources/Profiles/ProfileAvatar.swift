import SwiftUI
import ZilpZalpData
import ZilpZalpUI

extension EnvironmentValues {
    /// The photos every avatar disc draws from — ``PackModel/photos``, put
    /// where a disc deep inside a card can reach it.
    ///
    /// In the environment rather than in ``AvatarDisc``'s initialiser because
    /// an avatar turns up in five places that have no business knowing about
    /// packs: the picker's cards, the home screen's top bar, a row of „Unser
    /// Schwarm", the album's title, the creation grid. Handing the library
    /// down through all of them would put a `photos:` parameter on every one
    /// of those views and on everything that draws them.
    ///
    /// Empty by default, which is what a preview and a broken build get: the
    /// disc then draws the glyph ``AvatarStyle`` carries. It is the app's one
    /// set of photos, opened once per pack change — never a second cache.
    @Entry var speciesPhotos = SpeciesPhotos(.empty)
}

/// How one avatar is drawn: which bird's photo, and what to show instead when
/// there is no photo to show.
///
/// The colours are the fallback's, not the avatar's. A bird photo fills the
/// disc and identifies the child by itself — which is the whole point of #205
/// — so the palette here is only ever seen on the two discs that hold no
/// photo: the plus of „Neues Nest", and an avatar this build cannot place.
struct AvatarStyle {
    /// The species whose photo the disc shows, `nil` on a disc that is not a
    /// bird at all — see ``newNest``.
    let species: String?
    /// The glyph for a disc with no photo behind it.
    let icon: ZIcon
    let fill: Color
    let edge: Color
    let glyph: Color
}

extension AvatarStyle {
    /// **What a profile written before #205 keeps for a face.**
    ///
    /// The avatar was one of eight Lucide glyphs until a child said they were
    /// not birds (#193, #205), and a profile on a TestFlight iPhone still
    /// names one. Each of them gets the bird it was closest to — the house
    /// becomes the Hausrotschwanz, the leaf the leaf-green Zilpzalp, the
    /// feather the Wiedehopf and its crest — so a child finds the same card
    /// where it left it, in the same corner of the picker, rather than the
    /// grey disc an unknown name would draw.
    ///
    /// `star` is missing on purpose: the starling's species id *is* `star`,
    /// so that profile resolves to a bird with no mapping at all. Every bird
    /// named here is one of ``Profile/avatarChoices``, so a migrated child can
    /// still find its own avatar in the creation grid.
    ///
    /// Read only, and nothing rewrites the file: a child that picks a new bird
    /// overwrites the old name itself, and until then the glyph name is what
    /// an older build would still read. That is what makes this enough and a
    /// schema bump unnecessary (#205).
    private static let glyphBirds = [
        "bird": "amsel",
        "egg": "blaumeise",
        "feather": "wiedehopf",
        "house": "hausrotschwanz",
        "leaf": "zilpzalp",
        "lightbulb": "kohlmeise",
        "sparkles": "eisvogel",
    ]

    /// What to draw for a stored `Profile.avatar`.
    ///
    /// The name is a species id, one of the eight glyph names above, or
    /// something this build has never heard of — a file written by a newer
    /// version. All three end up as a species id here, and whether a photo
    /// answers to it is ``AvatarDisc``'s question: a name with no photo draws
    /// the bird glyph on sand, never a crash and never an empty hole where a
    /// child's own card should be.
    static func avatar(_ name: String) -> AvatarStyle {
        AvatarStyle(
            species: glyphBirds[name] ?? name,
            icon: .bird,
            // Sand, muted ink: `RewardStickerPalette.locked`, which is also
            // what a locked sticker and a dimmed tile wear. A disc that holds
            // no picture should look like a picture that has not arrived.
            fill: ZColor.surfaceSunken,
            edge: ZColor.borderCard,
            glyph: ZColor.ink300,
        )
    }

    /// The plus on the "Neues Nest" card. The one disc that is a door rather
    /// than a bird, so it wears the primary olive instead of a photo and
    /// cannot be mistaken for a child who already exists.
    static let newNest = AvatarStyle(
        species: nil,
        icon: .plus,
        fill: ZColor.primary,
        edge: ZColor.primaryShadow,
        glyph: ZColor.textOnColor,
    )
}

/// A bird photo on a round, outlined disc: a profile's avatar, and the plus
/// that opens a new one.
///
/// The album's sticker, straight rather than tilted (``RewardSticker``) — the
/// same shape the collection picker gives a collection (#187), so the child
/// on the home screen and the bird in the album are drawn by one component
/// and cannot drift apart. Straight because an avatar is a face and not a
/// reward: it sits in a top bar and in a list of rows, where a tilt reads as
/// sloppy rather than as stuck on.
///
/// Decorative throughout — every disc in this feature sits inside a button,
/// and the button carries the name. Two accessibility elements where a child
/// sees one thing would only make VoiceOver say it twice.
struct AvatarDisc: View {
    /// How much of the disc the glyph fills, where there is no photo.
    /// ``IconButton``'s ratio and ``RewardSticker``'s, so all three read at
    /// the same weight.
    private static let glyphRatio: CGFloat = 0.45

    let style: AvatarStyle
    let diameter: CGFloat
    /// Marks the chosen avatar on the creation screen: the olive rim and the
    /// check ``RewardSticker`` gives a chosen sticker (#189). Colour alone
    /// could not carry it — a child who tells no olive from sand still has to
    /// see which bird is picked.
    var chosen = false

    @Environment(\.speciesPhotos) private var photos

    private var photo: Image? {
        style.species.flatMap { photos[$0] }
    }

    var body: some View {
        if let photo {
            RewardSticker(
                image: photo,
                chosen: chosen,
                rotation: .zero,
                size: diameter,
            )
            .accessibilityHidden(true)
        } else {
            glyphDisc
        }
    }

    /// The disc without a photo: the plus of „Neues Nest", and an avatar whose
    /// species no open pack carries.
    private var glyphDisc: some View {
        Icon(style.icon, size: .custom((diameter * Self.glyphRatio).rounded()))
            .foregroundStyle(style.glyph)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(style.fill))
            .overlay { Circle().strokeBorder(style.edge, lineWidth: ZBorder.width) }
            .overlay { ring }
            .accessibilityHidden(true)
    }

    /// Sits *outside* the disc — negative padding on an overlay grows it
    /// outward — so the ring never eats into the glyph it is pointing at.
    ///
    /// Only this path needs one: a disc with a photo is a `RewardSticker` and
    /// brings the rim and the check with it. `ZColor.focusRing` at full
    /// strength rather than ``ZShadow/focusRingColor``, which is the same
    /// orange at 45 % and sized for a keyboard focus ring — this ring says
    /// "this is the one you picked".
    @ViewBuilder private var ring: some View {
        if chosen {
            Circle()
                .strokeBorder(ZColor.focusRing, lineWidth: ZShadow.focusRingWidth)
                .padding(-ZShadow.focusRingWidth)
        }
    }
}

#Preview("The ten birds, and the discs that are not birds") {
    let rows = [Array(Profile.avatarChoices.prefix(5)), Array(Profile.avatarChoices.suffix(5))]

    VStack(spacing: ZSpacing.step6) {
        ForEach(rows, id: \.self) { row in
            HStack(spacing: ZSpacing.step5) {
                ForEach(row, id: \.self) { choice in
                    AvatarDisc(style: .avatar(choice), diameter: 96)
                }
            }
        }

        HStack(spacing: ZSpacing.step5) {
            AvatarDisc(style: .newNest, diameter: 96)
            // A glyph avatar from an older profile, an avatar no pack carries,
            // and the chosen one.
            AvatarDisc(style: .avatar("feather"), diameter: 96)
            AvatarDisc(style: .avatar("a bird this build never heard of"), diameter: 96)
            AvatarDisc(style: .avatar("star"), diameter: 96, chosen: true)
        }
    }
    .padding(ZSpacing.step7)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
    .environment(\.speciesPhotos, SpeciesPhotos((try? .bundled()) ?? .empty))
}
