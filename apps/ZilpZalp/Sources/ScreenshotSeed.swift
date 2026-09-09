import Foundation
import ZilpZalpData

/// The child the App Store screenshots are taken of.
///
/// `mise run screenshots` launches the app with `-screenshots`, and from that
/// argument on the app keeps its profiles and the grown-ups' settings under a
/// fresh temporary directory instead of Application Support. Two things follow
/// from that, and both are the point: whatever family plays on the machine
/// taking the pictures is never read and never written, and the pictures show
/// the same child with the same stars however often they are taken.
///
/// The one profile is written through ``ProfileStore`` rather than dropped in
/// as a `profiles.json` from outside, so the file the app reads is a file the
/// app wrote.
///
/// Debug only. ``directory`` is `nil` in a Release build whatever the app is
/// launched with, and ``populate(_:)`` then does nothing — but the type is
/// compiled in every configuration, so ``AppModel`` needs no `#if` of its own.
enum ScreenshotSeed {
    /// A first name and one of ``Profile/avatarChoices``. Data, not product
    /// copy: nothing here belongs in the String Catalog.
    private static let name = "Mia"
    private static let avatar = "feather"

    /// How often this child has recognised each of the base pack's ten
    /// species. Six of them are past the five their sticker takes (#177), so
    /// the album shows what has been found; the other four stand part of the
    /// way, so it also shows what is still out there and how close it is. An
    /// album with no gap left is not what a sticker album looks like.
    private static let recognitions: [String: Int] = [
        "amsel": 7,
        "blaumeise": 6,
        "kohlmeise": 5,
        "rotkehlchen": 5,
        "star": 5,
        "zilpzalp": 8,
        "buntspecht": 4,
        "hausrotschwanz": 3,
        "eisvogel": 1,
        "wiedehopf": 0,
    ]

    /// A believable number of stars for a child who has been playing a while.
    /// Nothing arrives over the round end at any count — the ranks and their
    /// thresholds are gone (#177) — so the only rule left is that it should
    /// look like the album beside it.
    private static let totalStars = 128

    /// Rounds behind the stars above, at the two to three a round earns.
    private static let roundsPlayed = 46

    /// Where the run keeps its profiles and settings — `nil` whenever this is
    /// not the run, which is every launch a child ever sees.
    ///
    /// A fresh directory per launch, so the run can relaunch the app to get
    /// back to a screen it has already left behind and find the same child
    /// there rather than the one the previous launch played a round with.
    static let directory: URL? = {
        #if DEBUG
            guard ProcessInfo.processInfo.arguments.contains("-screenshots") else { return nil }
            return FileManager.default.temporaryDirectory
                .appending(path: "Screenshots-\(UUID().uuidString)")
        #else
            return nil
        #endif
    }()

    /// Puts the child in the store, and does nothing at all outside the run.
    ///
    /// Two writes because ``ProfileStore`` creates an empty profile and knows
    /// no other way in: the first makes the file, the second replaces what it
    /// holds with the profile above. Whatever it throws is what ``AppModel``
    /// already treats as a store that will not open.
    ///
    /// Once per store, not once per call. Nothing in the run loads twice
    /// today, but a second Mia would leave two profiles in the file — and
    /// `ProfileChoice.atLaunch` asks which of two children is playing, so
    /// every picture after that would be of the profile picker.
    static func populate(_ store: ProfileStore) async throws {
        guard directory != nil, try await store.profiles().isEmpty else { return }

        let created = try await store.add(name: name, avatar: avatar)
        try await store.update(
            Profile(
                id: created.id,
                name: name,
                avatar: avatar,
                totalStars: totalStars,
                roundsPlayed: roundsPlayed,
                recognitions: recognitions,
            ),
        )
    }
}
