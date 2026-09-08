import Foundation
import os
import ZilpZalpData

/// The grown-ups' settings, read at launch and written on every change.
///
/// ``AppModel`` owns the one instance and the grown-ups' area is handed it —
/// the move #35 said would happen as soon as a second reader turned up. The
/// daily limit is that reader: the home screen has to know where a tapped
/// tile leads before anybody opens the settings.
@MainActor
@Observable
final class ParentalSettingsModel {
    /// The defaults until ``load()`` has been through. `private(set)` so that
    /// a write always goes through ``set(_:to:)`` and reaches the disk.
    private(set) var settings = ParentalSettings()

    private let store: ParentalSettingsStore

    /// The write in flight, if there is one.
    ///
    /// Two settings changed in quick succession start two writes, and two
    /// unstructured tasks reach an actor in whatever order the runtime hands
    /// them over — no language rule says the first one arrives first. Reversed,
    /// the older snapshot lands last and the file says the opposite of the
    /// screen. So each write waits for the one before it, and a read waits for
    /// all of them rather than racing a save that has not landed yet.
    private var lastWrite: Task<Void, Never>?

    /// - Parameter directory: Where `Settings/parental.json` lives underneath.
    ///   Application Support, except in a preview.
    init(directory: URL = .applicationSupportDirectory) {
        store = ParentalSettingsStore(directory: directory)
    }

    /// Reads the file. A device that has never been here gets the defaults
    /// without an error; a file that cannot be read gets them with one in the
    /// log, because a grown-up cannot act on it and the settings standing at
    /// their defaults is the calm answer.
    func load() async {
        await lastWrite?.value

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

    /// Changes one setting and writes the file.
    ///
    /// The screen is updated first and does not wait for the disk: a switch
    /// that lags behind the finger reads as a broken switch.
    ///
    /// Generic over the field's type rather than one method per type: the
    /// daily limit is an `Int?` and the switch is a `Bool`, and the ordering
    /// above is what both of them need.
    func set<Value>(_ field: WritableKeyPath<ParentalSettings, Value>, to value: Value) {
        settings[keyPath: field] = value

        let written = settings
        let previous = lastWrite
        lastWrite = Task {
            await previous?.value

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
