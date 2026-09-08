import Foundation
import ZilpZalpCore

/// What a rank is called, in German, on the screens that show one.
///
/// `ZilpZalpCore` holds the ladder and its thresholds and no product text at
/// all, so the eight names live in the String Catalog and are looked up by the
/// rank's raw value — `rank.amsel.name`, `rank.amsel.ascent`,
/// `rank.amsel.missing`. The raw values are the stable identifiers Core
/// promises them to be, which is what makes the key safe to assemble.
///
/// **Whole sentences, not an article and a noun.** German would need the
/// indefinite article in the nominative for "Du bist jetzt *eine* Amsel" and
/// the dative in a contraction for "bis *zur* Amsel", and both differ by
/// gender. Three fragments per rank, assembled in a view, is how a translation
/// becomes ungrammatical without anybody noticing; three finished sentences is
/// how it stays somebody's job to write.
extension Rank {
    /// The bare name: "Amsel". The rungs of the ladder, the badge in the
    /// album, the line under a name in the swarm.
    var displayName: String {
        localized("name")
    }

    /// "Du bist jetzt eine Amsel!" — the headline of the ascent, spoken as
    /// well as written.
    ///
    /// `kohlmeise` has one too, though nothing can reach it: a profile starts
    /// there and the ladder only climbs. It completes the set, so a lookup
    /// assembled from a raw value can never come back with the key itself.
    var ascentSentence: String {
        localized("ascent")
    }

    /// "Noch 33 Sterne bis zur Blaumeise" — asked of the rank being climbed
    /// *to*, which is why the article is baked into each of the eight.
    func starsMissing(_ stars: Int) -> String {
        String(format: localized("missing"), stars)
    }

    private func localized(_ part: String) -> String {
        String(localized: String.LocalizationValue("rank.\(rawValue).\(part)"))
    }
}
