import Foundation
import ZilpZalpData

/// What a round changed about the child who played it: the profile before it
/// was booked, and the profile after.
///
/// Two snapshots rather than a list of differences, because everything the
/// celebration wants to know is a comparison — was this bird already in the
/// album, did the stars carry the child over a threshold — and a comparison
/// asked of the profiles themselves cannot drift from what was written down.
/// ``AppModel/record(_:)`` is the only thing that makes one.
struct RoundOutcome: Hashable {
    /// The profile as it stood when the round ended, before it was booked.
    let before: Profile

    /// The profile as ``ProfileStore`` wrote it. Whatever the celebration
    /// shows, this is the state a restart would find.
    let after: Profile

    /// Whether this round was the first time the album ever held `species`.
    ///
    /// Asked of ``before`` alone: every species of the round is in ``after``
    /// by construction, so the answer that means anything is whether it was
    /// missing beforehand.
    func isFirstFind(of species: String?) -> Bool {
        guard let species else { return false }
        return !before.collectedSpecies.contains(species)
    }
}
