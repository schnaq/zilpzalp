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
    /// What is happening to one pack.
    enum Download {
        /// Being fetched, 0 to 1 of the way there.
        case running(Double)
        /// The last attempt did not finish. One line under the row, and the
        /// next tap tries again — resuming, since the files that were verified
        /// are still there.
        case failed
    }

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
    private(set) var library = PackLibrary.empty

    /// Their photos, opened once per change rather than per layout pass. Here
    /// beside the library because the two must never disagree: a pack deleted
    /// while the album is open would otherwise leave its stickers on screen.
    private(set) var photos = SpeciesPhotos(.empty)

    /// The downloaded packs with their size on disk, for the grown-ups' rows.
    private(set) var installed: [PackInstallation] = []

    private(set) var available: Available = .loading

    /// What is happening to a pack right now, by pack id — nothing at all for
    /// every pack not in here.
    ///
    /// One dictionary rather than a set of running downloads beside a set of
    /// failed ones: the two states rule each other out, and two collections
    /// kept in step by hand would eventually disagree.
    private(set) var downloads: [String: Download] = [:]

    /// How many species carry a recording on disk, across every open pack.
    ///
    /// Counted when the library changes rather than when it is asked for: the
    /// home screen asks on every layout pass whether game 2 is worth offering,
    /// and the answer costs one `fileExists` per species — ten of them for the
    /// bundled pack alone, and a hundred more with every pack downloaded.
    private(set) var speciesWithCalls = 0

    private let bundledCatalog: PackCatalog?
    private let downloader: PackDownloader

    /// How often `Packs/` has been read. See ``readInstalled()``.
    private var reads = 0

    /// The pack that ships inside the app, `nil` only in a broken build.
    /// Listed like the others and deletable by nobody, so the app can never
    /// end up with no birds in it (spec §3).
    var bundled: Pack? {
        bundledCatalog?.pack
    }

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
        downloader = PackDownloader(baseURL: Self.bucket, directory: directory)
        rebuild()
    }

    /// The open packs, in the order they answer for a species: the one that
    /// ships inside the app, then what has been downloaded. Said once, because
    /// it is the rule the whole library rests on.
    private var catalogs: [PackCatalog] {
        [bundledCatalog].compactMap(\.self) + installed.map(\.catalog)
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
        } catch is CancellationError {
            // A grown-up who left the screen while the list was on its way.
            // SwiftUI cancels the `.task` that started this, and that is not a
            // failed fetch — saying it was would leave "ließ sich nicht laden"
            // standing behind a list that is simply not being waited for. The
            // section asks again when it comes back.
        } catch {
            available = .failed
            let reason = String(describing: error)
            Logger.packs.error("Pack index did not load: \(reason, privacy: .public)")
        }
    }

    /// Downloads a pack and makes its species part of the games.
    ///
    /// Returns at once; the row follows ``downloads``. A second tap while one
    /// is running is ignored rather than starting a second fetch into the same
    /// directory.
    func download(_ entry: PackIndex.Entry) {
        if case .running = downloads[entry.id] {
            return
        }
        downloads[entry.id] = .running(0)

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
                downloads[entry.id] = .failed
                let reason = String(describing: error)
                Logger.packs.error("Pack did not download: \(reason, privacy: .public)")
                return
            }

            // Installed first, and only then no longer a download: in between
            // the pack belongs to neither list, and the row would offer it for
            // download all over again.
            await readInstalled()
            downloads[entry.id] = nil
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
        // Two reads can be in flight at once — a download finishing while a
        // deletion is under way — and no rule says the first one back is the
        // older one. Only the newest read may be believed; the same reason
        // `ParentalSettingsModel` chains its writes.
        reads += 1
        let mine = reads

        let opened = await downloader.installations()
        guard mine == reads else { return }

        for failure in opened.failures {
            let reason = String(describing: failure)
            Logger.packs.error("Installed pack did not open: \(reason, privacy: .public)")
        }

        installed = opened.installed
        rebuild()
    }

    /// Puts the open packs together again. The one place ``library``,
    /// ``photos`` and ``speciesWithCalls`` change, so they cannot disagree
    /// about which packs are there.
    private func rebuild() {
        let library = PackLibrary(catalogs)
        self.library = library
        photos = SpeciesPhotos(library)
        speciesWithCalls = library.birds.count { library.callURL(for: $0) != nil }
    }

    /// One progress report, ignored once the download it belongs to is over —
    /// a report can arrive after the call that produced it has returned, and
    /// it must not put a finished pack back on the progress line.
    private func note(_ done: Int, of total: Int, for packID: String) {
        guard case .running = downloads[packID], total > 0 else { return }
        downloads[packID] = .running(min(1, Double(done) / Double(total)))
    }
}

extension PackModel.Download? {
    /// Whether a pack is being fetched right now. On the optional, because
    /// "no download at all" is the answer for most packs most of the time.
    var isRunning: Bool {
        if case .running = self {
            return true
        }
        return false
    }
}

private extension Logger {
    /// Opening, downloading and deleting species packs.
    static let packs = Logger(subsystem: "com.schnaq.zilpzalp", category: "packs")
}
