import SwiftUI
import UIKit
import ZilpZalpData

/// Every photo the app can show, keyed by species id — the bundled pack's and
/// every downloaded one's.
///
/// The album draws a whole page of stickers at once, and a
/// `View` is rebuilt on every layout pass — so the files are opened once, when
/// the screen is built, and never again while it is on stage. `UIImage` maps
/// the file and defers the decode to the first draw, exactly as `QuizSession`
/// relies on, so this costs a handful of look-ups rather than ten decodes.
struct SpeciesPhotos {
    private let images: [String: Image]

    /// - Parameter library: the packs that opened. An empty library is not an
    ///   error state: every sticker falls back to the glyph `RewardSticker`
    ///   draws without one.
    init(_ library: PackLibrary) {
        images = Dictionary(
            uniqueKeysWithValues: library.birds.compactMap { bird in
                library.photoURL(for: bird)
                    .flatMap { UIImage(contentsOfFile: $0.path(percentEncoded: false)) }
                    .map { (bird.id, Image(uiImage: $0)) }
            },
        )
    }

    /// The photo of `species`, `nil` when no pack holds such a bird or the
    /// file was missing.
    subscript(species: String) -> Image? {
        images[species]
    }
}
