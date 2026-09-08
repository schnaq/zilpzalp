import SwiftUI
import UIKit
import ZilpZalpData

/// What ``RoundEndScreen`` puts on its sticker: one species of the round just
/// played, resolved from the pack once.
///
/// Its own file because the screen it belongs to sits on SwiftLint's 400-line
/// ceiling, and because this is a value with no view in it — the picture, the
/// name and the attribution of one bird, and nothing about how they are laid
/// out.
struct RoundEndSticker {
    let name: String
    /// `nil` when the photo file is missing — ``RewardSticker`` then shows its
    /// glyph, which is still a sticker.
    let image: Image?
    let credit: String

    /// - Returns: `nil` when there is no pack, no species, or the pack does
    ///   not know the id.
    init?(species: String?, from catalog: PackCatalog?) {
        guard
            let catalog,
            let species,
            let bird = catalog.pack.birds.first(where: { $0.id == species })
        else {
            return nil
        }

        name = bird.name
        image = catalog.photoURL(for: bird)
            .flatMap { UIImage(contentsOfFile: $0.path(percentEncoded: false)) }
            .map { Image(uiImage: $0) }
        credit = bird.creditLine
    }
}
