import SwiftUI
import UIKit
import ZilpZalpData

/// What ``RoundEndScreen`` puts on its sticker: one species of the round just
/// played, resolved from the pack once.
///
/// Its own file because the screen it belongs to sits on SwiftLint's 400-line
/// ceiling, and because this is a value with no view in it — the picture and
/// the name of one bird, and nothing about how they are laid out.
struct RoundEndSticker {
    let name: String

    /// "Amsel" — what the screen says right after „Super gemacht!" when this
    /// bird is a first find (#264). Resolved here with the bird rather than
    /// from ``name`` in the screen, because the spoken form of a name is
    /// `pronunciation` where the manifest sets one, and that is also the name
    /// the recorded clip was made from.
    let spokenName: SpokenLine

    /// "Super gemacht! Amsel gesammelt!" — what VoiceOver announces for a
    /// first find. Text only: since #264 no clip says it, and what is heard is
    /// „Super gemacht!" followed by ``spokenName``.
    var praise: String {
        String(format: String(localized: "roundEnd.sticker.new.spoken"), spokenName.text)
    }

    /// `nil` when the photo file is missing — ``RewardSticker`` then shows its
    /// glyph, which is still a sticker.
    let image: Image?

    /// - Returns: `nil` when there is no species, or no installed pack knows
    ///   the id.
    init?(species: String?, from library: PackLibrary) {
        guard
            let species,
            let bird = library.birds.first(where: { $0.id == species })
        else {
            return nil
        }

        name = bird.name
        spokenName = .name(bird)
        image = library.photoURL(for: bird)
            .flatMap { UIImage(contentsOfFile: $0.path(percentEncoded: false)) }
            .map { Image(uiImage: $0) }
    }
}
