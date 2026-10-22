import Foundation
import ZilpZalpData

/// The dot on the home screen's grown-ups' door (#334): a pack in the bucket
/// the grown-ups have not seen in the gallery yet, or an update to one that is
/// installed. Decided by ``ZilpZalpData/PackIndex/hasNews(installed:seen:)``.
///
/// The catalogue comes from the same bucket and the same request as the
/// gallery's, and carries nothing about the device or the children (spec §3).
extension PackModel {
    /// Where ``seen`` is kept between launches.
    static let seenKey = "packsSeen"

    /// How long a catalogue fetched by ``checkForNews()`` is believed.
    /// Judgement: a pack is published a few times a year, and a child's
    /// session does not need to hear of it within the hour.
    private static let newsInterval = Duration.seconds(3 * 60 * 60)

    /// Whether the door wears its dot. `false` while no catalogue has come —
    /// offline, or the fetch failed — and never an error.
    var hasNews: Bool {
        guard case let .ready(index) = available else { return false }
        return index.hasNews(installed: installed, seen: seen)
    }

    /// ``loadAvailable()`` from the shell, at most once per ``newsInterval``:
    /// after launch and whenever the app comes back to the front. Counted
    /// per attempt, so a bucket that fails is not asked on every return.
    func checkForNews() async {
        if let last = lastNewsCheck, last.duration(to: .now) < Self.newsInterval {
            return
        }
        lastNewsCheck = .now
        await loadAvailable(migrating: false)
    }

    /// Every pack in the catalogue counts as seen from now on: the gallery has
    /// shown them. An outdated pack keeps the dot all the same.
    func markSeen() {
        guard case let .ready(index) = available else { return }
        seen.formUnion(index.packs.map(\.id))
        UserDefaults.standard.set(seen.sorted(), forKey: Self.seenKey)
    }
}
