import Foundation
import os
import ZilpZalpData

/// The grown-ups' settings while the area is on screen: read once, written on
/// every flipped switch.
///
/// The screen owns its own instance rather than reaching into ``AppModel``.
/// Nothing else reads these values yet — the games start doing so with #30 and
/// #36 — and at that point one shared instance moves into the shell, which is
/// a change to a file several branches share and therefore not this one.
@MainActor
@Observable
final class ParentalSettingsModel {
    /// The defaults until ``load()`` has been through. `private(set)` so that
    /// a write always goes through ``set(_:to:)`` and reaches the disk.
    private(set) var settings = ParentalSettings()

    private let store: ParentalSettingsStore

    /// - Parameter directory: Where `Settings/parental.json` lives underneath.
    ///   Application Support, except in a preview.
    init(directory: URL = .applicationSupportDirectory) {
        store = ParentalSettingsStore(directory: directory)
    }

    /// Reads the file. A device that has never been here gets the defaults
    /// without an error; a file that cannot be read gets them with one in the
    /// log, because a grown-up cannot act on it and the switches standing at
    /// their defaults is the calm answer.
    func load() async {
        do {
            settings = try await store.load()
        } catch {
            settings = ParentalSettings()
            // The error names a file format, never a setting — `DecodingError`
            // reports the key it tripped over and the type it wanted, not the
            // value it found.
            let reason = String(describing: error)
            Logger.parents.error("Settings did not open: \(reason, privacy: .public)")
        }
    }

    /// Flips one switch and writes the file.
    ///
    /// The screen is updated first and does not wait for the disk: a switch
    /// that lags behind the finger reads as a broken switch.
    func set(_ field: WritableKeyPath<ParentalSettings, Bool>, to value: Bool) {
        settings[keyPath: field] = value

        let written = settings
        Task {
            do {
                try await store.save(written)
            } catch {
                let reason = String(describing: error)
                Logger.parents.error("Settings did not save: \(reason, privacy: .public)")
            }
        }
    }
}

private extension Logger {
    /// The grown-ups' area and its settings file.
    ///
    /// The third copy of the bundle identifier from `project.yml`, after
    /// `Logger.audio` and `Logger.packs`. The note on the second one asks the
    /// third to pull it into one constant; doing that means editing two files
    /// other branches are working in tonight, so it waits for a change that
    /// owns them.
    static let parents = Logger(subsystem: "com.schnaq.zilpzalp", category: "parents")
}
