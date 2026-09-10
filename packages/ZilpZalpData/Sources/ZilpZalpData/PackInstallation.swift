import Foundation

/// One pack that lies below `Packs/`: opened, and measured.
///
/// What ``PackDownloader/installations()`` hands back and what the grown-ups'
/// area draws a row from — the pack for its title and its species count, the
/// catalog for the library the games play from, the bytes for the line that
/// says what it costs on the device.
///
/// The three together rather than three calls, because they are read together
/// and every one of them means walking `Packs/` again.
public struct PackInstallation: Sendable, Identifiable {
    /// The opened pack, for ``PackLibrary``.
    public let catalog: PackCatalog

    /// What the pack takes up on disk, in bytes: every file below its
    /// directory, the manifest included.
    public let bytes: Int

    public var pack: Pack {
        catalog.pack
    }

    /// The pack id, which is also the name of its directory.
    public var id: String {
        pack.id
    }
}

extension URL {
    /// How many bytes the regular files below this directory take up, 0 for a
    /// directory that cannot be read.
    ///
    /// Reads `.isRegularFileKey` and `.fileSizeKey` and nothing else. **No
    /// date key and no `attributesOfItem`**: those are the Required Reason
    /// APIs `docs/kids-category.md` weighs up, and a size the parents' area
    /// prints is not a reason to declare one.
    ///
    /// Best effort, because it answers a sentence on a screen: a file that
    /// disappears while the walk runs costs its own bytes from the total and
    /// nothing more.
    func directoryBytes() -> Int {
        let keys: Set<URLResourceKey> = [.isRegularFileKey, .fileSizeKey]
        guard
            let files = FileManager.default.enumerator(
                at: self,
                includingPropertiesForKeys: Array(keys),
            )
        else {
            return 0
        }

        var total = 0
        for case let file as URL in files {
            guard let values = try? file.resourceValues(forKeys: keys),
                  values.isRegularFile == true,
                  let size = values.fileSize
            else {
                continue
            }
            total += size
        }
        return total
    }
}
