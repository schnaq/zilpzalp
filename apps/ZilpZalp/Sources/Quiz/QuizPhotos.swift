import SwiftUI
import UIKit
import ZilpZalpCore
import ZilpZalpData

/// The photos a round's tiles draw from: the files the round being played
/// asks for, opened when it is dealt, and which of them each question shows.
///
/// A species may carry several photos (#194), and a child that meets the same
/// picture in every question learns the picture rather than the bird. Which
/// photo a tile gets is ``RoundPhotos``'s rule; this type is what holds the
/// images beside it, so that ``QuizSession`` asks one thing for one tile.
struct QuizPhotos {
    /// The species by id, for the file names and for how many photos each one
    /// declares — no I/O, the manifests are open already.
    ///
    /// ``RoundPhotos`` is dealt against what a manifest declares rather than
    /// what is on disk, because the deal is what says which files to open.
    private let birds: [String: Bird]

    /// Where the files are.
    private let library: PackLibrary

    /// The photos opened so far, by species and photo index — **only the ones
    /// that opened**.
    ///
    /// Filled in ``deal(_:using:)`` and nowhere else: a tile is rebuilt on
    /// every layout pass, so a lookup that could open a file would put file
    /// I/O on the main thread of every frame. Opened eagerly for the whole
    /// round rather than per question, because `UIImage` maps the file and
    /// defers the decode to the first draw — so this costs one look-up per
    /// tile, and in exchange no tile ever appears as the sand placeholder and
    /// fills in a moment later.
    ///
    /// **Only what the round asks for** (#214). Every installed species' whole
    /// set is hundreds of files once the packs carry three photos each, and a
    /// round of ten questions shows at most forty. What an earlier round
    /// opened stays: a species that comes round again costs no look-up, and
    /// the worst case is the whole library, which is where this used to start.
    private var images: [String: [Int: Image]] = [:]

    /// Which photo each tile of the round being played shows.
    private var dealt: RoundPhotos

    /// - Parameters:
    ///   - library: the packs that opened.
    ///   - round: the round whose tiles are dealt first.
    ///   - generator: the source of randomness.
    init(library: PackLibrary, round: Round, using generator: inout some RandomNumberGenerator) {
        self.library = library
        birds = Dictionary(uniqueKeysWithValues: library.birds.map { ($0.id, $0) })
        dealt = RoundPhotos(
            round: round,
            photoCounts: birds.mapValues(\.photos.count),
            using: &generator,
        )
        open(dealt.dealtPhotos)
    }

    /// Deals the tiles of the next round and opens what they show. Called
    /// wherever a round is, or the new round would draw its tiles from the last
    /// one's table.
    mutating func deal(_ round: Round, using generator: inout some RandomNumberGenerator) {
        dealt = RoundPhotos(
            round: round,
            photoCounts: birds.mapValues(\.photos.count),
            using: &generator,
        )
        open(dealt.dealtPhotos)
    }

    /// The photo `species` shows in the question at `question`, `nil` when no
    /// file of it opened — the tile then draws its own placeholder rather than
    /// an empty square.
    ///
    /// The fallback to the portrait is for the species whose dealt file is not
    /// on disk although its manifest names it: a tile that shows the portrait
    /// twice is better than a tile that shows nothing.
    func photo(_ species: String, question: Int) -> Image? {
        guard let photos = images[species] else { return nil }
        return photos[dealt.photo(for: species, question: question)] ?? photos[0]
    }

    /// Opens the files of `needed` that are not open yet — the portrait
    /// instead where a dealt file is missing, so that ``photo(_:question:)``
    /// has something to fall back to.
    private mutating func open(_ needed: [String: Set<Int>]) {
        for (species, indices) in needed {
            guard let bird = birds[species] else { continue }
            for index in indices where images[species]?[index] == nil {
                if let image = image(of: bird, at: index) {
                    images[species, default: [:]][index] = image
                } else if index != 0, images[species]?[0] == nil,
                          let portrait = image(of: bird, at: 0)
                {
                    images[species, default: [:]][0] = portrait
                }
            }
        }
    }

    private func image(of bird: Bird, at index: Int) -> Image? {
        library.photoURL(for: bird, at: index)
            .flatMap { UIImage(contentsOfFile: $0.path(percentEncoded: false)) }
            .map(Image.init(uiImage:))
    }
}
