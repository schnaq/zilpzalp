import SwiftUI
import UIKit
import ZilpZalpCore
import ZilpZalpData

/// The photos a round's tiles draw from: every species' files, opened once, and
/// which of them each question shows.
///
/// A species may carry several photos (#194), and a child that meets the same
/// picture in every question learns the picture rather than the bird. Which
/// photo a tile gets is ``RoundPhotos``'s rule; this type is what holds the
/// images beside it, so that ``QuizSession`` asks one thing for one tile.
struct QuizPhotos {
    /// Every species' photos in manifest order — **only the ones that opened**.
    ///
    /// Opened together rather than per question: `UIImage` maps the file and
    /// defers the decode to the first draw, so this costs a handful of file
    /// lookups, and in exchange no tile ever appears as the sand placeholder
    /// and fills in a moment later. Four such flashes per question would be the
    /// most visible thing on the screen.
    private let images: [String: [Image]]

    /// Which photo each tile of the round being played shows.
    private var dealt: RoundPhotos

    /// - Parameters:
    ///   - library: the packs that opened.
    ///   - round: the round whose tiles are dealt first.
    ///   - generator: the source of randomness.
    init(library: PackLibrary, round: Round, using generator: inout some RandomNumberGenerator) {
        images = Dictionary(
            uniqueKeysWithValues: library.birds.map { bird in
                (
                    bird.id,
                    bird.photos.indices.compactMap { index in
                        library.photoURL(for: bird, at: index)
                            .flatMap { UIImage(contentsOfFile: $0.path(percentEncoded: false)) }
                            .map(Image.init(uiImage:))
                    },
                )
            },
        )
        dealt = RoundPhotos(round: round, photoCounts: images.mapValues(\.count), using: &generator)
    }

    /// Deals the tiles of the next round. Called wherever a round is, or the
    /// new round would draw its tiles from the last one's table.
    mutating func deal(_ round: Round, using generator: inout some RandomNumberGenerator) {
        dealt = RoundPhotos(round: round, photoCounts: images.mapValues(\.count), using: &generator)
    }

    /// The photo `species` shows in the question at `question`, `nil` when no
    /// file of it opened — the tile then draws its own placeholder rather than
    /// an empty square.
    ///
    /// The counts ``RoundPhotos`` was dealt with are the opened photos', so the
    /// index is in range; the fallback is what a species whose files changed
    /// under a running session would take.
    func photo(_ species: String, question: Int) -> Image? {
        guard let photos = images[species], !photos.isEmpty else { return nil }
        let index = dealt.photo(for: species, question: question)
        return photos.indices.contains(index) ? photos[index] : photos[0]
    }
}
