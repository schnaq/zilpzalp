import Foundation
import ZilpZalpCore

/// What a rank is called, in German, on the screens that show one.
///
/// `ZilpZalpCore` holds the ladder and its thresholds and no product text at
/// all, so the eight names live in the String Catalog under the rank's raw
/// value — `rank.amsel.name`, `rank.amsel.ascent`, `rank.amsel.missing`.
///
/// **The keys are written out, not assembled from `rawValue`.** An assembled
/// key compiles and then renders itself: a `String.LocalizationValue` built
/// from a runtime string finds nothing in the catalog, and the ladder read
/// "rank.kohlm…" under every bird until this was spelled out. Written out,
/// the switch is also what forces a ninth rank to bring its three sentences
/// with it.
///
/// **Whole sentences, not an article and a noun.** German would need the
/// indefinite article in the nominative for "Du bist jetzt *eine* Amsel" and
/// the dative in a contraction for "bis *zur* Amsel", and both differ by
/// gender. Three fragments per rank, assembled in a view, is how a
/// translation becomes ungrammatical without anybody noticing.
extension Rank {
    /// The bare name: "Amsel". The rungs of the ladder, the badge in the
    /// album, the line under a name in the swarm.
    var displayName: String {
        switch self {
        case .kohlmeise: String(localized: "rank.kohlmeise.name")
        case .amsel: String(localized: "rank.amsel.name")
        case .blaumeise: String(localized: "rank.blaumeise.name")
        case .rotkehlchen: String(localized: "rank.rotkehlchen.name")
        case .star: String(localized: "rank.star.name")
        case .buntspecht: String(localized: "rank.buntspecht.name")
        case .eisvogel: String(localized: "rank.eisvogel.name")
        case .wiedehopf: String(localized: "rank.wiedehopf.name")
        }
    }

    /// "Du bist jetzt eine Amsel!" — the headline of the ascent, spoken as
    /// well as written.
    ///
    /// `kohlmeise` has one too, though nothing can reach it: a profile starts
    /// there and the ladder only climbs. It completes the set.
    var ascentSentence: String {
        switch self {
        case .kohlmeise: String(localized: "rank.kohlmeise.ascent")
        case .amsel: String(localized: "rank.amsel.ascent")
        case .blaumeise: String(localized: "rank.blaumeise.ascent")
        case .rotkehlchen: String(localized: "rank.rotkehlchen.ascent")
        case .star: String(localized: "rank.star.ascent")
        case .buntspecht: String(localized: "rank.buntspecht.ascent")
        case .eisvogel: String(localized: "rank.eisvogel.ascent")
        case .wiedehopf: String(localized: "rank.wiedehopf.ascent")
        }
    }

    /// "Noch 33 Sterne bis zur Blaumeise" — asked of the rank being climbed
    /// *to*, which is why the article is baked into each of the eight.
    func starsMissing(_ stars: Int) -> String {
        String(format: missingFormat, stars)
    }

    private var missingFormat: String {
        switch self {
        case .kohlmeise: String(localized: "rank.kohlmeise.missing")
        case .amsel: String(localized: "rank.amsel.missing")
        case .blaumeise: String(localized: "rank.blaumeise.missing")
        case .rotkehlchen: String(localized: "rank.rotkehlchen.missing")
        case .star: String(localized: "rank.star.missing")
        case .buntspecht: String(localized: "rank.buntspecht.missing")
        case .eisvogel: String(localized: "rank.eisvogel.missing")
        case .wiedehopf: String(localized: "rank.wiedehopf.missing")
        }
    }
}
