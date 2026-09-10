import Foundation

/// Every pack the app plays from at once: the one that ships inside it, and
/// each one a grown-up has downloaded.
///
/// The app asks this rather than a single ``PackCatalog``, because a child does
/// not know about packs. New species simply appear in the games, in the album
/// and in the credits, and the four questions a screen asks — which birds are
/// there, where is a photo, a call, a recorded sentence — are answered for all
/// of them together.
///
/// A value type over the opened packs, so a library is a snapshot: whoever
/// downloads or deletes a pack builds a new one. That is what lets the shell
/// hand the same answer to a view and to a round without either of them
/// noticing that `Packs/` changed underneath.
public struct PackLibrary: Sendable {
    /// No packs at all — a broken build, and the state the screens draw
    /// `app.pack.failed` for.
    public static let empty = PackLibrary([])

    /// The packs, in the order they were handed in. The app puts the bundled
    /// one first; see ``birds``.
    private let catalogs: [PackCatalog]

    /// Which pack a species belongs to, by index into ``catalogs``.
    private let owners: [String: Int]

    /// Every species, each one once, in pack order and within a pack in
    /// manifest order.
    ///
    /// **A species id that turns up twice is kept once, and the first pack
    /// wins.** Ids are unique across packs by curation rule, but a downloaded
    /// manifest is a document somebody else wrote — and both ``SpeciesPhotos``
    /// and the round builder key dictionaries by species id, which traps on a
    /// duplicate. So this is a crash guard rather than a tidiness rule, and the
    /// pack that ships with the app is the one that keeps its bird.
    public let birds: [Bird]

    /// - Parameter catalogs: the opened packs, most authoritative first.
    public init(_ catalogs: [PackCatalog]) {
        self.catalogs = catalogs

        var owners: [String: Int] = [:]
        var birds: [Bird] = []
        for (index, catalog) in catalogs.enumerated() {
            for bird in catalog.pack.birds where owners[bird.id] == nil {
                owners[bird.id] = index
                birds.append(bird)
            }
        }
        self.owners = owners
        self.birds = birds
    }

    /// Only the pack that ships inside the app — the library every launch
    /// starts with, before anything below `Packs/` has been opened.
    ///
    /// - Throws: what ``PackCatalog/bundled()`` throws.
    public static func bundled() throws -> PackLibrary {
        try PackLibrary([PackCatalog.bundled()])
    }

    /// The packs behind the species, in the same order — what the credits and
    /// the grown-ups' area name.
    public var packs: [Pack] {
        catalogs.map(\.pack)
    }

    /// Whether there is anything to play with.
    public var isEmpty: Bool {
        birds.isEmpty
    }

    /// The photo file of `bird`, `nil` when no pack here holds the species or
    /// the file is not on disk.
    public func photoURL(for bird: Bird) -> URL? {
        catalog(for: bird)?.photoURL(for: bird)
    }

    /// The recording of `bird`'s call, `nil` when the species carries none or
    /// the file is not there.
    public func callURL(for bird: Bird) -> URL? {
        catalog(for: bird)?.callURL(for: bird)
    }

    /// The recorded clip for `sentence` about `bird`, `nil` when the pack
    /// declares none or the file is not there — the app then speaks the
    /// sentence with `AVSpeechSynthesizer` (#151).
    public func speechURL(for bird: Bird, sentence: String) -> URL? {
        catalog(for: bird)?.speechURL(for: bird, sentence: sentence)
    }

    /// The pack `bird` came from.
    ///
    /// By id rather than by the value handed in: a screen keeps a `Bird` it
    /// read out of ``birds``, and the pack it belongs to is the one that put it
    /// there — never a later pack that declares the same species differently.
    private func catalog(for bird: Bird) -> PackCatalog? {
        owners[bird.id].map { catalogs[$0] }
    }
}
