import Foundation
import Observation
import os
import ZilpZalpCore
import ZilpZalpData

/// What the shell knows: the species pack that ships inside the app, the
/// profiles on this device, and which child is playing right now.
///
/// The pack is opened once at launch rather than when a game starts. A pack
/// that cannot be read is a broken build, and a broken build should say so on
/// a calm screen instead of dropping a child into a round with no birds in it.
/// `try!` would turn the same mistake into a crash on a child's iPad, which is
/// why the failure is a `nil` here and a sentence there. The profile store is
/// treated the same way: a file that will not decode is a sentence for a
/// grown-up, never a crash and never a silently emptied family.
///
/// `@Observable` since #28 — the active profile changes while the app runs,
/// and the whole shell hangs off which child it is.
@MainActor
@Observable
final class AppModel {
    /// `nil` only when `Bundle.module` carries no manifest, which
    /// `mise run check` already guards through `tools/sync_bundled_packs.py`.
    let catalog: PackCatalog?

    /// What the grown-ups decided, for the whole device.
    ///
    /// Here rather than inside the grown-ups' area (#35 left a note asking
    /// for exactly this move) because the daily limit is read where no
    /// grown-up is standing: on the home screen, when a child taps a game.
    let parental = ParentalSettingsModel()

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
    /// Kept because the celebration is more than one screen: the round end
    /// asks whether the sticker is a first find, and the rank ascent it pushes
    /// asks the same round about the ladder. Booking twice to answer twice
    /// would be a second round in the file.
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
            catalog = try PackCatalog.bundled()
        } catch {
            catalog = nil
            let reason = String(describing: error)
            Logger.packs.error("Bundled pack did not open: \(reason, privacy: .public)")
        }

        do {
            store = try ProfileStore(directory: ProfileStore.applicationSupport())
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

        guard let store else {
            isLoaded = true
            return
        }

        do {
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
            species: result.species,
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
    /// `Logger.audio` in `Audio/AudioSession.swift` still spells it out for
    /// itself. Pulling all three onto this constant is a one-line change to
    /// that file, and `Audio/` belongs to another branch tonight — so the
    /// merge is worth more than the tidiness, and this is the note that the
    /// third copy has now arrived.
    static let subsystem = "com.schnaq.zilpzalp"

    /// Opening and reading species packs.
    static let packs = Logger(subsystem: subsystem, category: "packs")

    /// Opening, reading and writing the profile store.
    static let profiles = Logger(subsystem: subsystem, category: "profiles")
}
