import Foundation
import Observation
import os
import ZilpZalpData

/// Every species pack on the device, and the one way a new one gets there.
///
/// The shell reads ``library`` and ``photos`` — the bundled pack and every
/// downloaded one as one set of birds. The grown-ups' area reads the rest and
/// is the only screen that may: ``load()`` opens what is already on disk,
/// ``loadAvailable()`` fetches the catalogue over the network, and both
/// ``download(_:)`` and ``delete(_:)`` happen behind the lock. **A child's
/// screen never reaches any of them**, which is what keeps the app's one
/// network call in the Kids Category's clear (spec §3).
///
/// Owned by ``AppModel`` rather than by the grown-ups' screen, for two
/// reasons: the games need the library long before anybody opens the settings,
/// and a download keeps running when a parent leaves the screen.
@MainActor
@Observable
final class PackModel {
    /// What the bucket offers, as far as the screen knows.
    enum Available {
        /// The fetch is in flight — the state the section opens in.
        case loading
        /// It did not arrive. One calm sentence, and the way to try again;
        /// which of the many reasons it was makes no difference to a parent.
        case failed
        case ready([PackIndex.Entry])
    }

    /// Where the packs come from: the media bucket's public read endpoint.
    ///
    /// Not a secret and not configurable. It is `zilpzalp-media` at Scaleway
    /// in `fr-par`, whose objects are world-readable on purpose — everything
    /// in it is CC-licensed, and a signed URL would mean either a key in the
    /// app or a service of our own (spec §3). Writing is another matter and
    /// belongs to `tools/fetch-media` alone, with credentials from Infisical.
    ///
    /// The single host the app talks to. Every URL below it is built by
    /// appending to it, and `NoRedirects` refuses to be sent anywhere else.
    static let bucket = URL(string: "https://zilpzalp-media.s3.fr-par.scw.cloud")!

    /// Every species the app can show right now — the bundled pack first, then
    /// the installed ones in id order.
    private(set) var library: PackLibrary

    /// Their photos, opened once per change rather than per layout pass. Here
    /// beside the library because the two must never disagree: a pack deleted
    /// while the album is open would otherwise leave its stickers on screen.
    private(set) var photos: SpeciesPhotos

    /// The downloaded packs with their size on disk, for the grown-ups' rows.
    private(set) var installed: [PackInstallation] = []

    private(set) var available: Available = .loading

    /// How far a running download has got, 0 to 1, by pack id. A pack in here
    /// is a pack being fetched right now.
    private(set) var downloading: [String: Double] = [:]

    /// The packs whose last download did not finish. One line under the row,
    /// and the next tap tries again — resuming, since the files that were
    /// verified are still there.
    private(set) var failed: Set<String> = []

    /// The pack that ships inside the app, `nil` only in a broken build.
    /// Listed like the others and deletable by nobody, so the app can never
    /// end up with no birds in it (spec §3).
    let bundled: Pack?

    private let bundledCatalog: PackCatalog?
    private let downloader: PackDownloader

    /// - Parameter directory: where `Packs/` is created — Application Support,
    ///   or the screenshot run's own directory.
    init(directory: URL) {
        // Opened here rather than awaited in `load()`: the bundled pack is the
        // difference between the home screen and the "pack could not be
        // opened" sentence, and asking that question one frame late would
        // flash the failure at every launch.
        do {
            bundledCatalog = try PackCatalog.bundled()
        } catch {
            bundledCatalog = nil
            let reason = String(describing: error)
            Logger.packs.error("Bundled pack did not open: \(reason, privacy: .public)")
        }
        bundled = bundledCatalog?.pack

        let bundledOnly = PackLibrary([bundledCatalog].compactMap(\.self))
        library = bundledOnly
        photos = SpeciesPhotos(bundledOnly)
        downloader = PackDownloader(baseURL: Self.bucket, directory: directory)
    }

    /// What a parent has not got yet: everything the bucket offers minus what
    /// is already on the device.
    var downloadable: [PackIndex.Entry] {
        guard case let .ready(entries) = available else { return [] }
        return entries.filter { entry in !installed.contains { $0.id == entry.id } }
    }

    /// What the downloaded packs take up altogether — the line under the card.
    var totalBytes: Int {
        installed.reduce(0) { $0 + $1.bytes }
    }

    /// Opens the packs below `Packs/`. Awaited once at launch, after which the
    /// library only changes with a download or a deletion.
    func load() async {
        await readInstalled()
    }

    /// Fetches the catalogue from the bucket.
    ///
    /// **The app's only unprompted network call, and it happens behind the
    /// lock**: the grown-ups' area asks for it when it opens, no child's
    /// screen ever does.
    func loadAvailable() async {
        available = .loading
        do {
            available = try await .ready(downloader.availablePacks())
        } catch {
            available = .failed
            let reason = String(describing: error)
            Logger.packs.error("Pack index did not load: \(reason, privacy: .public)")
        }
    }

    /// Downloads a pack and makes its species part of the games.
    ///
    /// Returns at once; the row follows ``downloading``. A second tap while
    /// one is running is ignored rather than starting a second fetch into the
    /// same directory.
    func download(_ entry: PackIndex.Entry) {
        guard downloading[entry.id] == nil else { return }
        downloading[entry.id] = 0
        failed.remove(entry.id)

        Task {
            do {
                try await downloader.download(entry) { done, total in
                    // The downloader reports from its own executor, so the
                    // number hops to the main actor before it reaches a view.
                    Task { @MainActor [weak self] in
                        self?.note(done, of: total, for: entry.id)
                    }
                }
            } catch {
                // Nothing is half installed: the downloader publishes a pack
                // only once every file it names is there and verified, so what
                // is left behind is a partial directory the next attempt
                // resumes from.
                failed.insert(entry.id)
                let reason = String(describing: error)
                Logger.packs.error("Pack did not download: \(reason, privacy: .public)")
            }

            downloading[entry.id] = nil
            await readInstalled()
        }
    }

    /// Removes a downloaded pack, its half downloaded copy included. Its
    /// species leave the games with it; the album keeps what was collected,
    /// because that is the child's, not the pack's.
    func delete(_ packID: String) async {
        do {
            try await downloader.delete(packID: packID)
        } catch {
            let reason = String(describing: error)
            Logger.packs.error("Pack was not deleted: \(reason, privacy: .public)")
        }
        await readInstalled()
    }

    /// Reads `Packs/` and rebuilds what the shell plays from.
    ///
    /// The one place the library changes, so a pack that arrives or leaves
    /// while the app runs reaches the games, the album and the credits without
    /// a restart.
    private func readInstalled() async {
        let opened = await downloader.installations()
        for failure in opened.failures {
            let reason = String(describing: failure)
            Logger.packs.error("Installed pack did not open: \(reason, privacy: .public)")
        }

        installed = opened.installed
        library = PackLibrary([bundledCatalog].compactMap(\.self) + installed.map(\.catalog))
        photos = SpeciesPhotos(library)
    }

    /// One progress report, ignored once the download it belongs to is over —
    /// a report can arrive after the call that produced it has returned, and
    /// it must not put a finished pack back on the progress line.
    private func note(_ done: Int, of total: Int, for packID: String) {
        guard downloading[packID] != nil, total > 0 else { return }
        downloading[packID] = min(1, Double(done) / Double(total))
    }
}

private extension Logger {
    /// Opening, downloading and deleting species packs.
    static let packs = Logger(subsystem: "com.schnaq.zilpzalp", category: "packs")
}
