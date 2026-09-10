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

    /// Whether this round earned `species`' sticker: the fifth recognition
    /// happened in it.
    ///
    /// Asked of both profiles, because that is the whole of the news. A bird
    /// recognised for the sixth time is not a new sticker, and one that stands
    /// at four is not one yet.
    func earnedSticker(for species: String?) -> Bool {
        guard let species else { return false }
        return !before.hasSticker(for: species) && after.hasSticker(for: species)
    }

    /// How often `species` has been recognised now that the round is written
    /// down, for the markers under it. Unclamped: ``StickerMarkers`` is what
    /// turns a count into a row of five and into a sentence.
    func recognitions(of species: String?) -> Int {
        species.map { after.recognitions[$0, default: 0] } ?? 0
    }
}
