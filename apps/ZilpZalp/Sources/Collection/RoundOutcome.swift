import Foundation
import ZilpZalpData

/// What a round changed about the child who played it: the profile before it
/// was booked, and the profile after.
///
/// Two snapshots rather than a list of differences, because everything the
/// celebration wants to know is a comparison — was this bird's sticker earned
/// just now, how far has it come — and a comparison asked of the profiles
/// themselves cannot drift from what was written down.
/// ``AppModel/record(_:)`` is the only thing that makes one.
struct RoundOutcome: Hashable {
    /// The profile as it stood when the round ended, before it was booked.
    let before: Profile

    /// The profile as ``ProfileStore`` wrote it. Whatever the celebration
    /// shows, this is the state a restart would find.
    let after: Profile

    /// Whether this round earned `species`' sticker: it was missing from the
    /// album before and is in it now.
    ///
    /// Asked of both profiles, because that is the whole of the news. A bird
    /// recognised once more after its sticker is not a new sticker, and one
    /// short of the threshold is not one yet.
    func earnedSticker(for species: String?) -> Bool {
        guard let species else { return false }
        return !before.hasSticker(for: species) && after.hasSticker(for: species)
    }

    /// The markers under `species` now that the round is written down: how
    /// often it has been recognised, out of the child's threshold.
    ///
    /// A bird whose sticker is in the album shows a full row whatever its
    /// counter says — a sticker earned at three stays when the threshold goes
    /// up to five (#260), and "4 von 5" under it would claim it is still to be
    /// earned. Otherwise unclamped: ``StickerMarkers`` turns a count into a
    /// row and a sentence.
    func progress(of species: String?) -> (count: Int, threshold: Int) {
        let threshold = after.stickerThreshold
        guard let species else { return (0, threshold) }
        let count = after.recognitions[species, default: 0]
        return (after.hasSticker(for: species) ? max(count, threshold) : count, threshold)
    }
}
