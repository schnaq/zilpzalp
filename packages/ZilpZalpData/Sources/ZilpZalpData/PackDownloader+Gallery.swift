import Foundation

/// What the pack gallery needs from the downloader (#262), beside the
/// download itself.
public extension PackDownloader {
    /// One preview of a bird that is not on the device yet (#262), the bytes
    /// of a small JPEG.
    ///
    /// Through the same door as everything else: appended to `baseURL`,
    /// refused when the key would leave it, no redirect followed. The shared
    /// session's `URLCache` keeps what came, so a grown-up opening the same
    /// pack twice does not fetch it twice.
    ///
    /// - Parameter key: ``PackIndex/Species/preview``.
    /// - Throws: `PackDownloadError.invalidPath` or `.fileUnreachable`.
    func preview(_ key: String) async throws -> Data {
        guard isSafeRelativePath(key) else {
            throw PackDownloadError.invalidPath(packID: "", path: key)
        }
        return try await fetch(baseURL.appending(path: key), named: key)
    }
}

extension PackDownloader {
    /// What a failed write means to a grown-up: a full device, or anything
    /// else that went wrong on disk.
    ///
    /// The full device is recognised from the write itself rather than asked
    /// for beforehand, which keeps the app off the `DiskSpace` Required Reason
    /// API (docs/kids-category.md). Nothing is lost by it: the files that were
    /// verified stay in the partial directory, and the next attempt resumes.
    static func diskError(_ error: any Error, writing destination: URL) -> PackDownloadError {
        let path = destination.path(percentEncoded: false)
        let nsError = error as NSError
        let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        let full = (error as? CocoaError)?.code == .fileWriteOutOfSpace
            || [nsError, underlying]
            .contains { $0?.domain == NSPOSIXErrorDomain && $0?.code == Int(ENOSPC) }
        return full ? .outOfSpace(path: path) : .diskFailure(
            path: path,
            reason: error.localizedDescription,
        )
    }
}
