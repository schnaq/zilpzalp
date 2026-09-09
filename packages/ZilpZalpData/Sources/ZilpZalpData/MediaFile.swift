import Foundation

/// Whether a path out of an index or a manifest may be appended to a directory
/// of ours.
///
/// Everything the app fetches, writes and opens is addressed by a string
/// somebody else generated, so `photos/../../../Preferences/x.plist` has to be
/// stopped here rather than by the file system. Only plain relative paths pass:
/// no empty component, no `.`, no `..`, no leading slash, no backslash, no
/// percent escape that could smuggle one of those back in.
///
/// A free function beside ``URL/mediaFile(_:)`` rather than a method of
/// ``PackDownloader``: the downloader asks it before it writes a file, the two
/// catalogs before they open one, and it is the same question about the same
/// strings.
func isSafeRelativePath(_ path: String) -> Bool {
    guard !path.isEmpty, !path.hasPrefix("/"), !path.contains("\\"), !path.contains("%") else {
        return false
    }
    return path
        .split(separator: "/", omittingEmptySubsequences: false)
        .allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
}

extension URL {
    /// The file a manifest names relative to the directory it lies in, `nil`
    /// when the name is not a plain relative path or no file is there.
    ///
    /// The one rule every medium follows — a photo, a call, a recorded
    /// sentence, in a pack or in the fixed set — so ``PackCatalog`` and
    /// ``SpeechCatalog`` both resolve through it rather than each spelling it
    /// out. `nil` rather than a URL that fails later: a tile then draws its
    /// placeholder and the player stays silent.
    ///
    /// A downloaded pack's manifest is a document somebody else wrote, so the
    /// name goes through ``isSafeRelativePath(_:)`` before it is appended — the
    /// same check the downloader makes before it writes a file. A directory is
    /// not a medium either: `fileExists` says yes to one, and an empty name
    /// would otherwise resolve to the pack itself.
    func mediaFile(_ relative: String) -> URL? {
        guard isSafeRelativePath(relative) else { return nil }

        let file = appending(path: relative)
        var isDirectory: ObjCBool = false
        let there = FileManager.default.fileExists(
            atPath: file.path(percentEncoded: false),
            isDirectory: &isDirectory,
        )
        guard there, !isDirectory.boolValue else { return nil }

        return file
    }
}
