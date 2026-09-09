import ZilpZalpCore
import ZilpZalpData

/// When a bird's sticker is in a child's album, and how far the next one has
/// come (#177).
///
/// The tally lives on the profile in `ZilpZalpData`, the threshold in
/// ``Scoring`` in `ZilpZalpCore`, and those two packages deliberately do not
/// know each other — a store does not need the rules of the game, and one
/// integer is no reason to introduce a dependency between them. The app links
/// both, so this is where the two meet: one comparison, in one place, rather
/// than every screen deciding for itself what "collected" means.
extension Profile {
    /// Whether `species` has been recognised the five times its sticker takes.
    func hasSticker(for species: String) -> Bool {
        recognitions[species, default: 0] >= Scoring.recognitionsForSticker
    }

    /// How far `species` has come towards its sticker, never past the five it
    /// takes: a bird known twenty times over is one sticker, and a row of five
    /// markers has nowhere to put the rest.
    func stickerProgress(for species: String) -> Int {
        min(recognitions[species, default: 0], Scoring.recognitionsForSticker)
    }
}
