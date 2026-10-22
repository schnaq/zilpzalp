import Foundation
import os

/// How ``ProfileStore`` talks to iCloud key-value storage: what the cloud
/// holds, how it meets the file, and how the file goes back up.
extension ProfileStore {
    /// How long a deleted profile's id is remembered, so that a device that
    /// was away while it was deleted does not bring it back.
    fileprivate static let tombstoneLifetime: TimeInterval = 90 * 24 * 60 * 60

    /// The cloud's keys: `profile.<id>` for each profile, and one for the
    /// deleted ones.
    ///
    /// ponytail: unversioned. A schema bump has to move to new keys (say
    /// `profile.v2.<id>`) so that an older build never merges a newer shape.
    fileprivate static let cloudPrefix = "profile."
    fileprivate static let deletedKey = "profiles.deleted"

    /// Compact, but sorted like the file, so that an unchanged profile is the
    /// same bytes and is not written to the cloud again.
    fileprivate static let cloudEncoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    /// Two sets of profiles as one: a profile on both sides merged, a profile
    /// on one side kept, a deleted one dropped wherever it still stands.
    ///
    /// In creation order; ties — profiles from before iCloud — in the order
    /// `local` has them, then the cloud's. Deleted ids older than
    /// ``tombstoneLifetime`` are forgotten.
    static func merged(_ local: Contents, _ cloud: Contents, now: Date) -> Contents {
        let deleted = local.deleted.merging(cloud.deleted, uniquingKeysWith: max)
            .filter { now.timeIntervalSince($0.value) < tombstoneLifetime }
        var profiles: [Profile] = []
        for profile in local.profiles + cloud.profiles where deleted[profile.id.uuidString] == nil {
            if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
                profiles[index] = profiles[index].merged(with: profile)
            } else {
                profiles.append(profile)
            }
        }
        // `sort` is stable, which is what keeps the ties in place.
        profiles.sort { $0.createdAt < $1.createdAt }
        return Contents(profiles: profiles, deleted: deleted)
    }

    /// What the cloud holds. A value that does not decode — damaged, or from a
    /// build that spells a profile differently — is passed over and logged:
    /// one bad key must not cost the other children their sync.
    static func contents(of cloud: any CloudKeyValueStore) -> Contents {
        var contents = Contents()
        let decoder = JSONDecoder()
        for (key, value) in cloud.dictionaryRepresentation where key.hasPrefix(cloudPrefix) {
            guard let data = value as? Data,
                  let profile = try? decoder.decode(Profile.self, from: data)
            else {
                Logger.cloud.error("Cloud profile did not decode: \(key, privacy: .public)")
                continue
            }
            contents.profiles.append(profile)
        }
        if let data = cloud.data(forKey: deletedKey) {
            contents.deleted = (try? decoder.decode([String: Date].self, from: data)) ?? [:]
        }
        return contents
    }

    func mirror(_ contents: Contents, to cloud: any CloudKeyValueStore) {
        for profile in contents.profiles {
            // Encoding a profile has no failing case: every field is a plain
            // value. Skipping one is still better than not writing the file.
            guard let data = try? Self.cloudEncoder.encode(profile) else { continue }
            cloud.mirror(data, forKey: Self.cloudPrefix + profile.id.uuidString)
        }
        for id in contents.deleted.keys where cloud.data(forKey: Self.cloudPrefix + id) != nil {
            cloud.removeObject(forKey: Self.cloudPrefix + id)
        }
        // Not while there is nothing to say: a reinstall's empty list would
        // overwrite the cloud's before the first download arrived.
        if !contents.deleted.isEmpty, let data = try? Self.cloudEncoder.encode(contents.deleted) {
            cloud.mirror(data, forKey: Self.deletedKey)
        }
    }
}
