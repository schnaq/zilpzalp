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
    /// disc then draws the glyph it falls back to. It is the app's one set of
    /// photos, opened once per pack change — never a second cache.
    @Entry var speciesPhotos = SpeciesPhotos(.empty)
}

/// What one disc in the profile screens shows.
///
/// Two things, and the second one is not a child: a bird, and the plus that
/// opens a new nest. There is nothing per-avatar left to carry beyond the
/// species — a photo fills the disc and identifies the child by itself, which
/// is the whole point of #205, where eight hand-picked colour triples used to
/// do that job for eight glyphs.
enum AvatarStyle {
    /// The bird whose photo the disc shows, by species id.
    case bird(species: String)

    /// The plus on the "Neues Nest" card. The one disc that is a door rather
    /// than a bird, so it wears the primary olive instead of a photo and
    /// cannot be mistaken for a child who already exists.
    case newNest

    /// What to draw for a stored `Profile.avatar` — a species id, a glyph name
    /// an older build wrote, or a name this build has never heard of, all
    /// resolved by ``Profile/species(forAvatar:)``.
    ///
    /// Whether a photo answers to that species is ``AvatarDisc``'s question: a
    /// bird with no photo draws the glyph on sand, never a crash and never an
    /// empty hole where a child's own card should be.
    static func avatar(_ name: String) -> AvatarStyle {
        .bird(species: Profile.species(forAvatar: name))
    }
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

    var body: some View {
        switch style {
        case let .bird(species):
            bird(photos[species])
        case .newNest:
            // The plus is a door, so it is olive rather than photographed.
            glyphDisc(
                .plus,
                fill: ZColor.primary,
                edge: ZColor.primaryShadow,
                glyph: ZColor.textOnColor,
            )
        }
    }

    /// One child's bird — its photo, or the glyph that stands in for a species
    /// no open pack carries.
    @ViewBuilder private func bird(_ photo: Image?) -> some View {
        if let photo {
            RewardSticker(image: photo, chosen: chosen, rotation: .zero, size: diameter)
                .accessibilityHidden(true)
        } else {
            // Sand and muted ink: `RewardStickerPalette.locked`, which is also
            // what a locked sticker and a dimmed tile wear. A disc that holds
            // no picture should look like a picture that has not arrived.
            glyphDisc(
                .bird,
                fill: ZColor.surfaceSunken,
                edge: ZColor.borderCard,
                glyph: ZColor.ink300,
            )
        }
    }

    /// A disc with no photo in it.
    private func glyphDisc(
        _ icon: ZIcon,
        fill: Color,
        edge: Color,
        glyph: Color,
    ) -> some View {
        Icon(icon, size: .custom((diameter * Self.glyphRatio).rounded()))
            .foregroundStyle(glyph)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(fill))
            .overlay { Circle().strokeBorder(edge, lineWidth: ZBorder.width) }
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
