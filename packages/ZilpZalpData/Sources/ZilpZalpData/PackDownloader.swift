import CryptoKit
import Foundation

/// Fetches species packs from the media bucket into Application Support.
///
/// The only component of the app that talks to the network, and it talks to
/// exactly one host: every URL it opens is built by appending a path to
/// `baseURL`, and `NoRedirects` keeps a `3xx` from moving it elsewhere.
/// iNaturalist and xeno-canto are curation-time sources of
/// `tools/fetch-media` and are never contacted at runtime.
///
/// A download is resumable at file granularity. Files land in
/// `Packs/<id>.partial/`, each one verified against the SHA-256 its manifest
/// declares before it counts, and only a directory in which every declared
/// file is present and verified is moved to `Packs/<id>/`. So an interrupted
/// download costs the files it had not reached yet and nothing else, and a
/// half pack is never visible as installed.
public actor PackDownloader {
    /// Where the index sits in the bucket (#14).
    private static let indexKey = "packs/index.json"

    /// `Packs/<pack-id>/` below the directory handed to `init`, as section 5
    /// of the spec lays it out.
    private static let packsDirectoryName = "Packs"

    /// A download in flight is `Packs/<id>.partial/`. A suffix rather than a
    /// hidden directory: a human looking into Application Support sees what
    /// happened.
    private static let partialSuffix = ".partial"

    private static let manifestName = "manifest.json"

    private let baseURL: URL
    private let packsDirectory: URL
    private let session: URLSession

    /// - Parameters:
    ///   - baseURL: the public bucket endpoint, everything else is relative to
    ///     it. Tests hand in a local stand-in server instead.
    ///   - directory: the directory `Packs/` is created in — Application
    ///     Support in the app, a temporary directory in the tests.
    ///   - session: only injected by the tests, which register a `URLProtocol`
    ///     on an ephemeral configuration.
    public init(baseURL: URL, directory: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        packsDirectory = directory.appending(path: Self.packsDirectoryName)
        self.session = session
    }

    // MARK: - The bucket

    /// The packs the bucket offers.
    ///
    /// - Returns: the index entries, in the order the index lists them.
    /// - Throws: `PackDownloadError.indexUnreachable` for every failure —
    ///   no network, a 404, an error page instead of the index. The caller
    ///   acts on all of them the same way. `CancellationError` when the task
    ///   was cancelled.
    public func availablePacks() async throws -> [PackIndex.Entry] {
        let data: Data
        do {
            data = try await fetch(baseURL.appending(path: Self.indexKey), named: Self.indexKey)
        } catch let PackDownloadError.fileUnreachable(_, reason) {
            throw PackDownloadError.indexUnreachable(reason: reason)
        }

        do {
            return try JSONDecoder().decode(PackIndex.self, from: data).packs
        } catch {
            throw PackDownloadError.indexUnreachable(reason: "\(error)")
        }
    }

    /// Downloads one pack and installs it.
    ///
    /// Returns once the pack is installed. On any error — a failed fetch, a
    /// hash that does not match, a cancelled task — the half downloaded
    /// directory stays behind so that the next call resumes instead of
    /// starting over. One call per pack at a time: two overlapping ones share
    /// that directory, and the second fails when it publishes what the first
    /// has already moved.
    ///
    /// - Parameters:
    ///   - entry: an entry from `availablePacks()`.
    ///   - progress: called with the bytes fetched or already on disk and the
    ///     entry's `downloadSize`, after the manifest and after every file.
    ///     A closure rather than an `AsyncStream` because the download is one
    ///     awaited call that either returns or throws, and a stream would make
    ///     the caller drain a second channel for what the first already tells
    ///     it. It runs on this actor's executor, not on the main one.
    /// - Throws: `PackDownloadError`, or `CancellationError`.
    public func download(
        _ entry: PackIndex.Entry,
        progress: @Sendable (_ bytesDownloaded: Int, _ bytesTotal: Int) -> Void = { _, _ in },
    ) async throws {
        guard Self.isSafeComponent(entry.id) else {
            throw PackDownloadError.invalidPath(packID: entry.id, path: entry.id)
        }
        guard isSafeRelativePath(entry.manifest) else {
            throw PackDownloadError.invalidPath(packID: entry.id, path: entry.manifest)
        }

        let partial = try createPartialDirectory(for: entry.id)

        let manifestURL = baseURL.appending(path: entry.manifest)
        let manifestData = try await fetch(manifestURL, named: entry.manifest)
        let pack = try decodeManifest(manifestData, expecting: entry.id)

        var downloaded = manifestData.count
        progress(downloaded, entry.downloadSize)

        // Every name before the first byte: a poisoned path at the end of a
        // manifest must not cost a parent the files that precede it, and a
        // pack of many birds names hundreds of them.
        let assets = pack.declaredFiles
        if let unsafe = assets.first(where: { !isSafeRelativePath($0.file) }) {
            throw PackDownloadError.invalidPath(packID: entry.id, path: unsafe.file)
        }

        // Media are relative to the manifest, not to the base: the manifest
        // says `photos/amsel.png` and sits at `packs/<id>/manifest.json`.
        let packURL = manifestURL.deletingLastPathComponent()
        for asset in assets {
            try Task.checkCancellation()
            let destination = partial.appending(path: asset.file)
            if let alreadyThere = verifiedSize(of: destination, sha256: asset.sha256) {
                downloaded += alreadyThere
            } else {
                let data = try await fetch(packURL.appending(path: asset.file), named: asset.file)
                let digest = Self.hexDigest(of: data)
                guard digest == asset.sha256 else {
                    throw PackDownloadError.hashMismatch(
                        packID: entry.id,
                        file: asset.file,
                        expected: asset.sha256,
                        actual: digest,
                    )
                }
                try write(data, to: destination)
                downloaded += data.count
            }
            progress(downloaded, entry.downloadSize)
        }

        // The manifest last, so that a partial directory only carries one
        // once every file it names has been verified.
        try write(manifestData, to: partial.appending(path: Self.manifestName))
        try publish(partial, as: packsDirectory.appending(path: entry.id))
    }

    // MARK: - What is on disk

    /// Every pack installed below `Packs/`, opened and measured.
    ///
    /// **An installation under the bundled pack's id is ignored and deleted.**
    /// The pack was downloadable before it began shipping inside the app
    /// (#192), and left alone such a copy would appear as a second pack of the
    /// same title — in the collection picker and as a deletable row in the
    /// grown-ups' area.
    ///
    /// - Returns: the packs that opened, in directory order, and one error per
    ///   pack that did not. **A pack that will not open costs its own species
    ///   and nothing else**: the app keeps playing with the rest, and the
    ///   grown-ups' area can name the broken one and offer to delete it. A
    ///   directory without a manifest is a download that never finished and is
    ///   skipped without a word.
    public func installations() -> (installed: [PackInstallation], failures: [PackDownloadError]) {
        // Before `Packs/` is read, so what went is not read at all. Silently,
        // because a removal that fails costs the space and nothing else: the
        // loop skips the pack either way, and the next launch tries again.
        try? delete(packID: PackCatalog.bundledPackID)

        let contents: [URL]
        do {
            contents = try FileManager.default.contentsOfDirectory(
                at: packsDirectory,
                includingPropertiesForKeys: nil,
            )
        } catch CocoaError.fileReadNoSuchFile {
            // Nothing has ever been downloaded. That is the normal state of a
            // fresh install, not a failure.
            return ([], [])
        } catch {
            return ([], [.diskFailure(
                path: packsDirectory.path(percentEncoded: false),
                reason: error.localizedDescription,
            )])
        }

        var installed: [PackInstallation] = []
        var failures: [PackDownloadError] = []
        for directory in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let packID = directory.lastPathComponent
            // Never the bundled pack, whose leftovers were just deleted: a
            // deletion that failed must not put the pack on screen twice.
            guard packID != PackCatalog.bundledPackID,
                  !packID.hasSuffix(Self.partialSuffix),
                  let data = try? Data(contentsOf: directory.appending(path: Self.manifestName))
            else {
                continue
            }

            do {
                try installed.append(PackInstallation(
                    catalog: PackCatalog(
                        pack: decodeManifest(data, expecting: packID),
                        directory: directory,
                    ),
                    bytes: directory.directoryBytes(),
                ))
            } catch {
                failures.append(
                    error as? PackDownloadError
                        ?? .manifestInvalid(packID: packID, reason: "\(error)"),
                )
            }
        }
        return (installed, failures)
    }

    /// Removes a downloaded pack: the installed directory and a half
    /// downloaded one, so that deleting frees the space and a later download
    /// starts clean. Removing what is not there is done, not failed — the
    /// parents' area has one button per pack and should not have to know
    /// which of the two directories exist.
    public func delete(packID: String) throws {
        guard Self.isSafeComponent(packID) else {
            throw PackDownloadError.invalidPath(packID: packID, path: packID)
        }

        for directory in [
            packsDirectory.appending(path: packID),
            packsDirectory.appending(path: packID + Self.partialSuffix),
        ] {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch CocoaError.fileNoSuchFile {
                continue
            } catch {
                throw PackDownloadError.diskFailure(
                    path: directory.path(percentEncoded: false),
                    reason: error.localizedDescription,
                )
            }
        }
    }

    // MARK: - Fetching

    /// Fetches one object of the bucket.
    ///
    /// `url` is built by appending to `baseURL` and nowhere else, which is
    /// what keeps the app on the single host it may talk to. `name` is the
    /// path an error names.
    ///
    /// - Throws: `PackDownloadError.fileUnreachable` for every transport and
    ///   status failure, `CancellationError` when the task was cancelled.
    private func fetch(_ url: URL, named name: String) async throws -> Data {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(from: url, delegate: NoRedirects.shared)
        } catch {
            // A cancelled task arrives here as `URLError.cancelled`. It is the
            // caller's decision, not a failed download, and must not be
            // dressed up as one.
            try Task.checkCancellation()
            throw PackDownloadError.fileUnreachable(path: name, reason: error.localizedDescription)
        }

        guard let status = (response as? HTTPURLResponse)?.statusCode else {
            throw PackDownloadError.fileUnreachable(path: name, reason: "no HTTP response")
        }
        guard (200 ..< 300).contains(status) else {
            throw PackDownloadError.fileUnreachable(path: name, reason: "HTTP \(status)")
        }
        return data
    }

    private static func hexDigest(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func decodeManifest(_ data: Data, expecting packID: String) throws -> Pack {
        let pack: Pack
        do {
            pack = try PackManifest.decode(data)
        } catch {
            throw PackDownloadError.manifestInvalid(packID: packID, reason: "\(error)")
        }
        guard pack.voice != nil || pack.birds.allSatisfy({ $0.speech?.isEmpty ?? true }) else {
            // A photo and a call carry their licence in their own fields and
            // cannot decode without one; a clip's licence is the manifest's
            // voice. Without it the pack would install recordings nobody may
            // be credited for — which `tools/license_gate.py` refuses at
            // curation time and nothing re-checks after a download.
            throw PackDownloadError.manifestInvalid(
                packID: packID,
                reason: "the pack has recorded sentences but names no voice",
            )
        }
        guard pack.id == packID else {
            // The id is the directory name, in the bucket and on disk. A
            // manifest that disagrees would install a pack under a name
            // nothing else uses.
            throw PackDownloadError.manifestInvalid(
                packID: packID,
                reason: "the manifest calls the pack '\(pack.id)'",
            )
        }
        return pack
    }

    // MARK: - Paths

    /// Whether a string may be used as a single directory name — a pack id.
    private static func isSafeComponent(_ component: String) -> Bool {
        isSafeRelativePath(component) && !component.contains("/")
    }

    // MARK: - Disk

    /// Creates `Packs/` and the pack's partial directory below it.
    ///
    /// `Packs/` is excluded from the iCloud backup when it is created: every
    /// pack can be fetched again from the bucket, so backing them up would
    /// only inflate a backup that also has to fit children's photos.
    private func createPartialDirectory(for packID: String) throws -> URL {
        let manager = FileManager.default
        var packs = packsDirectory
        let partial = packsDirectory.appending(path: packID + Self.partialSuffix)

        do {
            if !manager.fileExists(atPath: packs.path(percentEncoded: false)) {
                try manager.createDirectory(at: packs, withIntermediateDirectories: true)
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                try packs.setResourceValues(values)
            }
            try manager.createDirectory(at: partial, withIntermediateDirectories: true)
        } catch {
            throw PackDownloadError.diskFailure(
                path: partial.path(percentEncoded: false),
                reason: error.localizedDescription,
            )
        }
        return partial
    }

    /// The size of a file that is already there and hashes to `sha256`, `nil`
    /// when it is missing or does not match.
    ///
    /// This is what makes a download resumable: a file that survived the last
    /// attempt is not fetched again, a half written one does not pass and is.
    /// Unreadable means "fetch it", so nothing throws here.
    private func verifiedSize(of file: URL, sha256: String) -> Int? {
        guard let data = try? Data(contentsOf: file), Self.hexDigest(of: data) == sha256 else {
            return nil
        }
        return data.count
    }

    private func write(_ data: Data, to destination: URL) throws {
        do {
            try FileManager.default.createDirectory(
                at: destination.deletingLastPathComponent(),
                withIntermediateDirectories: true,
            )
            try data.write(to: destination, options: .atomic)
        } catch {
            throw PackDownloadError.diskFailure(
                path: destination.path(percentEncoded: false),
                reason: error.localizedDescription,
            )
        }
    }

    /// Makes a fully verified partial directory the installed pack.
    ///
    /// One move, so a pack is either the old one or the new one and never a
    /// mixture — which is the whole reason the files are collected next door
    /// instead of in place.
    private func publish(_ partial: URL, as installed: URL) throws {
        let manager = FileManager.default
        do {
            if manager.fileExists(atPath: installed.path(percentEncoded: false)) {
                // Replacing, not removing and moving: there is no moment in
                // which the pack is gone from disk.
                _ = try manager.replaceItemAt(installed, withItemAt: partial)
            } else {
                try manager.moveItem(at: partial, to: installed)
            }
        } catch {
            throw PackDownloadError.diskFailure(
                path: installed.path(percentEncoded: false),
                reason: error.localizedDescription,
            )
        }
    }
}
