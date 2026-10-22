import Foundation
import ZilpZalpData

/// The family's iCloud, as far as the shell is concerned: which store the
/// profiles and the settings are backed up to, and the wait for another
/// device's changes.
extension AppModel {
    /// iCloud key-value storage — or nowhere in a screenshot run, whose
    /// made-up child must not land in the iCloud of the machine taking the
    /// pictures.
    static let cloud: NSUbiquitousKeyValueStore? = ScreenshotSeed.directory == nil ? .default : nil

    /// Listens for another device's writes for as long as the app runs, then
    /// asks iCloud for them.
    ///
    /// In that order, so that nothing is missed: `synchronize()` only asks,
    /// and on a reinstall the answer — usually everything — arrives a moment
    /// after launch, as one of these notifications.
    func startCloudSync() {
        guard let cloud = Self.cloud else { return }
        let changes = NotificationCenter.default
            .notifications(named: NSUbiquitousKeyValueStore.didChangeExternallyNotification)
            .map { _ in () }
        Task { [weak self] in
            for await _ in changes {
                await self?.cloudChanged()
            }
        }
        cloud.synchronize()
    }
}
