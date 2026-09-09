import SwiftUI
import UIKit
import ZilpZalpData

/// Every photo of an opened pack, keyed by species id.
///
/// The album draws a whole page of stickers at once, and a
/// `View` is rebuilt on every layout pass — so the files are opened once, when
/// the screen is built, and never again while it is on stage. `UIImage` maps
/// the file and defers the decode to the first draw, exactly as `QuizSession`
/// relies on, so this costs a handful of look-ups rather than ten decodes.
struct SpeciesPhotos {
    private let images: [String: Image]

    /// - Parameter catalog: the opened pack, or `nil` when none could be. An
    ///   empty set of photos is not an error state: every sticker falls back
    ///   to the glyph `RewardSticker` draws without one.
    init(_ catalog: PackCatalog?) {
        guard let catalog else {
            images = [:]
            return
        }
        images = Dictionary(
            uniqueKeysWithValues: catalog.pack.birds.compactMap { bird in
                catalog.photoURL(for: bird)
                    .flatMap { UIImage(contentsOfFile: $0.path(percentEncoded: false)) }
                    .map { (bird.id, Image(uiImage: $0)) }
            },
        )
    }

    /// The photo of `species`, `nil` when the pack has no such bird or the
    /// file was missing.
    subscript(species: String) -> Image? {
        images[species]
    }
}
