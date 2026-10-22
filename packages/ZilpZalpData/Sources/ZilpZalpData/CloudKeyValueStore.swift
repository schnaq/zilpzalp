import Foundation
import os

/// The part of iCloud key-value storage the stores use to back up and sync the
/// profiles and the grown-ups' settings.
///
/// A protocol so that the tests run against a dictionary rather than against
/// the iCloud account of whoever runs them; the app passes
/// `NSUbiquitousKeyValueStore.default`. The data stays in the family's own
/// iCloud — nothing of it reaches us.
public protocol CloudKeyValueStore: AnyObject, Sendable {
    func data(forKey key: String) -> Data?
    func set(_ data: Data?, forKey key: String)
    func removeObject(forKey key: String)
    var dictionaryRepresentation: [String: Any] { get }
}

/// Unchecked because Foundation does not annotate it. The store is documented
/// as one shared object to use throughout the app, and it synchronises access
/// to its values itself, as `UserDefaults` does.
extension NSUbiquitousKeyValueStore: @retroactive @unchecked Sendable, CloudKeyValueStore {}

extension CloudKeyValueStore {
    /// What iCloud grants an app: one megabyte in all, and one per key.
    static var quota: Int {
        1_000_000
    }

    /// Writes `data` under `key` unless it is already there or would break
    /// the quota.
    ///
    /// Over the quota the store would refuse the write later and report it
    /// only through a notification nobody here waits for, so the key is
    /// skipped and logged instead: the device keeps its own copy either way.
    func mirror(_ data: Data, forKey key: String) {
        guard self.data(forKey: key) != data else { return }
        let others = dictionaryRepresentation
            .filter { $0.key != key }
            .reduce(0) { $0 + $1.key.utf8.count + (($1.value as? Data)?.count ?? 0) }
        let size = key.utf8.count + data.count
        guard size <= Self.quota, others + size <= Self.quota else {
            Logger.cloud.error("Not mirrored, over the iCloud quota: \(key, privacy: .public)")
            return
        }
        set(data, forKey: key)
    }
}

extension Logger {
    /// Backing up and syncing through iCloud key-value storage.
    static let cloud = Logger(subsystem: "com.schnaq.zilpzalp", category: "cloud")
}
