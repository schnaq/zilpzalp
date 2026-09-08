import Foundation
import Observation
import os
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
    private static let rememberedKey = "profile.lastActive"

    /// The full profile behind ``activeProfileID``.
    var activeProfile: Profile? {
        profiles.first { $0.id == activeProfileID }
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
        guard let store else {
            isLoaded = true
            return
        }

        do {
            let stored = try await store.profiles()
            profiles = stored
            activeProfileID = Self.profileToOpen(among: stored, remembered: rememberedProfileID)
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

    /// Which child the app opens on — the zero/one/many rule, in the one place
    /// it is allowed to run.
    ///
    /// Launch only. A family with a single profile still has to be able to
    /// reach "Neues Nest", and they reach it through the picker that
    /// ``chooseAgain()`` opens; if this rule ran there too it would put that
    /// one child straight back on the home screen and a second child could
    /// never be created.
    ///
    /// The remembered child wins over the count, so a restart lands where the
    /// iPad was put down. Without one: nobody yet (the creation screen is the
    /// root), exactly one (that child, no picker), or several (the picker).
    private static func profileToOpen(
        among profiles: [Profile],
        remembered: Profile.ID?,
    ) -> Profile.ID? {
        if let remembered, profiles.contains(where: { $0.id == remembered }) {
            return remembered
        }
        return profiles.count == 1 ? profiles.first?.id : nil
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
