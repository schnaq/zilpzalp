/// What can go wrong while listing, downloading or opening a pack.
///
/// Every case names the thing at fault, because the parents' area has to say
/// which pack or which file went wrong. Nothing here is ever a crash: a bucket
/// that answers with nonsense is a bad afternoon, not a broken app.
public enum PackDownloadError: Error, Sendable, Equatable {
    /// `packs/index.json` could not be fetched, or does not decode.
    case indexUnreachable(reason: String)
    /// A file the download needs could not be fetched from the bucket.
    case fileUnreachable(path: String, reason: String)
    /// The manifest was fetched but is not a pack manifest, or names a
    /// different pack than the index entry it belongs to.
    case manifestInvalid(packID: String, reason: String)
    /// An index entry or a manifest names a path that would leave the pack's
    /// own directory. Rejected before a single byte is fetched or written.
    case invalidPath(packID: String, path: String)
    /// A fetched file does not hash to what the manifest declares. The pack
    /// stays half downloaded and nothing of it becomes visible.
    case hashMismatch(packID: String, file: String, expected: String, actual: String)
    /// There is no such pack below `Packs/`.
    case notInstalled(packID: String)
    /// Creating, writing, moving or removing below `Packs/` failed.
    case diskFailure(path: String, reason: String)
}
