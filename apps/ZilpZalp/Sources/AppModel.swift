import Foundation
import Observation
import os
import ZilpZalpCore
import ZilpZalpData

/// What the shell knows: the species packs on this device, the profiles, and
/// which child is playing right now.
///
/// The packs are opened at launch rather than when a game starts, and a pack
/// that cannot be read is a broken build — one that should say so on a calm
/// screen instead of dropping a child into a round with no birds in it. `try!`
/// would turn the same mistake into a crash on a child's iPad, which is why an
/// empty ``PackLibrary`` reaches the shell and a sentence reaches the child.
/// The profile store is treated the same way: a file that will not decode is a
/// sentence for a grown-up, never a crash and never a silently emptied family.
///
/// `@Observable` since #28 — the active profile changes while the app runs,
/// and the whole shell hangs off which child it is.
@MainActor
@Observable
final class AppModel {
    /// The bundled pack, everything a grown-up has downloaded, and the one
    /// component that talks to the network. See ``PackModel``.
    ///
    /// Here rather than inside the grown-ups' area for the same reason the
    /// settings are: what a child plays with is read where no grown-up is
    /// standing, and a download outlives the screen that started it.
    let packs = PackModel(
        directory: ScreenshotSeed.directory ?? .applicationSupportDirectory,
    )

    /// What the grown-ups decided, for the whole device.
    ///
    /// Here rather than inside the grown-ups' area (#35 left a note asking
    /// for exactly this move) because the daily limit is read where no
    /// grown-up is standing: on the home screen, when a child taps a game.
    ///
    /// The screenshot run reads and writes its own directory — see
    /// ``ScreenshotSeed``. A limit a grown-up once set on the machine taking
    /// the pictures would otherwise send the run to "Zeit fürs Nest".
    let parental = ParentalSettingsModel(
        directory: ScreenshotSeed.directory ?? .applicationSupportDirectory,
    )

    /// The profiles as they are on disk, in the order the store keeps them.
    private(set) var profiles: [Profile] = []

    /// The child playing right now. `nil` means the picker is due — either
    /// nobody has been chosen yet, or somebody just tapped the avatar in the
    /// top bar to hand the iPad over.
    private(set) var activeProfileID: Profile.ID?

    /// `false` until ``load()`` has been round the profile store once. The
    /// shell shows the bare page ground until then, so a family with two
    /// children never sees the picker flash up before the child who was
    /// playing yesterday is restored.
    private(set) var isLoaded = false

    /// The profile store could not be opened, read or written. One flag for
    /// all three: from a child's side they are the same event, and the screen
    /// says the same calm sentence.
    private(set) var storeFailed = false

    /// What the round the child has just finished changed about its profile,
    /// `nil` until one has been booked in this run of the app.
    ///
    /// Kept because the round end asks more than once: it comes back into
    /// view when the child returns from the album, and booking twice to
    /// answer twice would be a second round in the file.
    private(set) var lastRound: RoundOutcome?

    /// The round ``lastRound`` describes. See ``record(_:)``.
    private var recordedRound: UUID?

    /// `nil` when Application Support itself could not be located, which
    /// leaves ``storeFailed`` set and the app on its failure screen.
    private let store: ProfileStore?

    /// Which child the app opened on last time.
    ///
    /// A `UUID` string in `UserDefaults`, not a field in `profiles.json`: it
    /// describes this device's last session rather than the family's data, and
    /// putting it in the file would mean a write — and a possible write
    /// failure — on every tap of a profile card. `@AppStorage` would do the
    /// same job and buys nothing, because no view reads the value.
    ///
    /// Not spelled `profile.lastActive`: every `profile.`-prefixed name in
    /// this app is a String Catalog key, and a `UserDefaults` key wearing that
    /// prefix would send the next reader looking for a translation of it.
    private static let rememberedKey = "lastActiveProfile"

    /// The full profile behind ``activeProfileID``.
    var activeProfile: Profile? {
        profiles.first { $0.id == activeProfileID }
    }

    /// The games the home screen offers, in the order it draws their tiles.
    ///
    /// Game 1 is always among them. Game 2 asks its question with a recorded
    /// call, so it is offered only where there are calls to ask with — four
    /// species carrying one on disk, counted inside the collection the child
    /// chose rather than across every installed pack (#187).
    /// Below that the tile is absent rather than teased or locked, exactly as
    /// games 3 and 4 are (#31). Nothing else decides it — where the calls are,
    /// the game is (#138).
    ///
    /// Computed rather than stored: packs arrive and are deleted in the
    /// grown-ups' area while the app runs (#34), a child can change its
    /// collection between two rounds, and a stored answer would be one the
    /// home screen could disagree with.
    var games: [Game] {
        collection.offersCalls ? [.names, .calls] : [.names]
    }

    /// The playing child's day against the limit the grown-ups set.
    ///
    /// Computed on every read, never stored, and that is the whole of the
    /// day-rollover handling: today's key is formed from `Date()` each time,
    /// so an app left open past midnight asks about the new day the next time
    /// anybody asks at all. Nothing has to notice the day turning over.
    ///
    /// Without a chosen child there is nothing to count, and the answer is a
    /// budget nobody has spent — never an exhausted one, which would strand
    /// the profile picker behind "Zeit fürs Nest".
    var timeBudget: TimeBudget {
        TimeBudget(
            limitMinutes: parental.settings.dailyLimitMinutes,
            playedToday: activeProfile?.playtime[Self.today] ?? 0,
        )
    }

    /// Stars the playing child has collected today, across every round and
    /// every launch of the app — what "Zeit fürs Nest" tells it about its day.
    var starsToday: Int {
        activeProfile?.dailyStars[Self.today] ?? 0
    }

    /// Today's key into ``Profile/playtime`` and ``Profile/dailyStars``, in
    /// the device's own calendar and time zone.
    private static var today: String {
        Profile.dayKey(for: Date())
    }

    init() {
        do {
            store = try ProfileStore(
                directory: ScreenshotSeed.directory ?? ProfileStore.applicationSupport(),
            )
        } catch {
            store = nil
            storeFailed = true
            let reason = String(describing: error)
            Logger.profiles.error("Profile store did not open: \(reason, privacy: .public)")
        }
    }

    /// Reads the profiles and decides which screen the app starts on.
    ///
    /// Awaited once from the root view. Everything after it is a tap.
    func load() async {
        // Before the profiles, and whatever happens to them: a limit the
        // shell does not know yet is a limit that does not apply, and the
        // first tap on a game tile comes soon after this.
        await parental.load()
        // And the packs: which games the home screen offers depends on what
        // is installed, and the first tap comes soon after this.
        await packs.load()

        guard let store else {
            isLoaded = true
            return
        }

        do {
            try await ScreenshotSeed.populate(store)
            let stored = try await store.profiles()
            profiles = stored
            activeProfileID = ProfileChoice.atLaunch(
                among: stored,
                remembered: rememberedProfileID,
            )
        } catch {
            storeFailed = true
            let reason = String(describing: error)
            Logger.profiles.error("Profiles did not load: \(reason, privacy: .public)")
        }

        isLoaded = true
    }

    /// A child tapped their own card.
    func select(_ id: Profile.ID) {
        activeProfileID = id
        rememberedProfileID = id
    }

    /// Hands the device on: back to "Wer spielt heute?".
    ///
    /// Forgets the remembered child as well. Leaving a profile is a deliberate
    /// act, and a restart should not quietly undo it.
    func chooseAgain() {
        activeProfileID = nil
        rememberedProfileID = nil
    }

    /// Writes a new profile and makes it the one playing.
    ///
    /// The name is expected trimmed and non-empty; the creation screen is the
    /// only caller and does both before it gets here.
    func create(name: String, avatar: String) async {
        guard let store else { return }

        do {
            let profile = try await store.add(name: name, avatar: avatar)
            // `add` appends, so appending here leaves this array in the order
            // the file now has — no second read to find that out.
            profiles.append(profile)
            select(profile.id)
        } catch {
            storeFailed = true
            let reason = String(describing: error)
            Logger.profiles.error("Profile was not written: \(reason, privacy: .public)")
        }
    }

    /// A child chose which birds it wants to play with (#187).
    ///
    /// Kept in memory first and written after, so the home screen answers the
    /// tap in the same frame however slow the disk is.
    ///
    /// **A write that fails is not a screen a child sees.** Like
    /// ``record(_:)`` and unlike ``load()``, this leaves ``storeFailed``
    /// alone: the choice is on the screen and the round will ask for the right
    /// birds, and swapping the games for a grown-up's sentence about a file
    /// would be a strange answer to tapping a picture of a penguin. It is
    /// logged, and the next choice tries again.
    ///
    /// - Parameter collection: the pack's id, `nil` for every bird.
    func choose(collection: String?) async {
        guard let store, let index = profiles.firstIndex(where: { $0.id == activeProfileID })
        else {
            return
        }
        // Tapping a collection that is already chosen is a child asking to
        // hear its name again, not a change to write to disk.
        guard profiles[index].collection != collection else { return }

        profiles[index].collection = collection

        do {
            try await store.update(profiles[index])
        } catch {
            let reason = String(describing: error)
            Logger.profiles.error("Collection was not written: \(reason, privacy: .public)")
        }
    }

    /// Books a finished round onto the child who played it: its stars, its
    /// species into the album, its seconds onto today.
    ///
    /// Called by the round end when it appears. Both `onAppear` and `.task`
    /// run again when the child comes back from the album, so the round's own
    /// id — not the fact of having appeared — is what makes this happen once;
    /// every later call for the same round hands back the outcome of the
    /// first.
    ///
    /// **A store that will not write is not a screen a child sees.** Unlike
    /// ``load()`` and ``create(name:avatar:)`` this leaves ``storeFailed``
    /// alone: the round is over, the stars are on the screen, and swapping the
    /// celebration for a grown-up's sentence about a file would punish a child
    /// for a broken disk. It is logged, and the next round tries again.
    ///
    /// - Returns: the profile before and after, or `nil` when there was
    ///   nothing to write to or the write did not happen.
    @discardableResult
    func record(_ result: RoundResult) async -> RoundOutcome? {
        guard recordedRound != result.id else { return lastRound }
        recordedRound = result.id
        // Cleared before the write, not after it: from here on this round is
        // the one being answered about, and a write that fails must answer
        // "nothing" rather than hand back the round before it. Without this,
        // a failed write followed by a trip to the album would celebrate the
        // previous round's first find all over again.
        lastRound = nil

        guard let store, let before = activeProfile else { return nil }

        let round = PlayedRound(
            stars: result.stars,
            recognitions: result.recognitions,
            playtime: result.playtime,
        )

        do {
            let after = try await store.record(round: round, for: before.id, on: Date())
            if let index = profiles.firstIndex(where: { $0.id == after.id }) {
                profiles[index] = after
            }
            let outcome = RoundOutcome(before: before, after: after)
            lastRound = outcome
            return outcome
        } catch {
            let reason = String(describing: error)
            Logger.profiles.error("Round was not recorded: \(reason, privacy: .public)")
            return nil
        }
    }

    private var rememberedProfileID: Profile.ID? {
        get {
            UserDefaults.standard
                .string(forKey: Self.rememberedKey)
                .flatMap(UUID.init(uuidString:))
        }
        set {
            if let newValue {
                UserDefaults.standard.set(newValue.uuidString, forKey: Self.rememberedKey)
            } else {
                UserDefaults.standard.removeObject(forKey: Self.rememberedKey)
            }
        }
    }
}

private extension Logger {
    /// The app's bundle identifier from `project.yml`.
    ///
    /// `Logger.audio` in `Audio/AudioSession.swift`, `Logger.parents` and
    /// `Logger.packs` spell it out for themselves. Pulling them onto one
    /// constant means editing files other branches are working in, so it waits
    /// for a change that owns them.
    static let subsystem = "com.schnaq.zilpzalp"

    /// Opening, reading and writing the profile store.
    static let profiles = Logger(subsystem: subsystem, category: "profiles")
}
