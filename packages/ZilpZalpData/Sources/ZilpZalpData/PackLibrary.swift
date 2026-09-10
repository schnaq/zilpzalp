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

    /// The packs behind the species, in the same order — what the credits and
    /// the grown-ups' area name. One pack in a library ``narrowed(toPack:)``
    /// handed back.
    public let packs: [Pack]

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
        packs = catalogs.map(\.pack)
    }

    /// A library that names fewer birds than the packs behind it hold. See
    /// ``narrowed(toPack:)``, the only caller.
    private init(_ catalogs: [PackCatalog], owners: [String: Int], birds: [Bird], packs: [Pack]) {
        self.catalogs = catalogs
        self.owners = owners
        self.birds = birds
        self.packs = packs
    }

    /// Only the pack that ships inside the app — the library every launch
    /// starts with, before anything below `Packs/` has been opened.
    ///
    /// - Throws: what ``PackCatalog/bundled()`` throws.
    public static func bundled() throws -> PackLibrary {
        try PackLibrary([PackCatalog.bundled()])
    }

    /// This library with only one pack's species in it — what a child that
    /// asked for „die Vögel aus Afrika" plays with (#187).
    ///
    /// **Narrowed rather than rebuilt.** `PackLibrary([thatCatalog])` would be
    /// the obvious way and the wrong one: the merge above keeps a species that
    /// two manifests declare in the first pack that declared it, and a library
    /// built from one catalog alone would answer for such a bird with media
    /// the album and the round end — which read the merged library — do not
    /// use. So the packs and the ownership stay exactly as they are, and only
    /// the list of birds gets shorter. A bird `id` names is therefore the copy
    /// of it this library already had, whichever pack that came from.
    ///
    /// - Parameter id: the pack, as its manifest spells its `id`.
    /// - Returns: the narrowed library, `nil` when no pack here carries that
    ///   id — a pack a grown-up has deleted since a child chose it.
    public func narrowed(toPack id: String) -> PackLibrary? {
        guard let index = catalogs.firstIndex(where: { $0.pack.id == id }) else { return nil }

        let declared = Set(catalogs[index].pack.birds.map(\.id))
        return PackLibrary(
            catalogs,
            owners: owners,
            birds: birds.filter { declared.contains($0.id) },
            packs: [catalogs[index].pack],
        )
    }

    /// Whether there is anything to play with.
    public var isEmpty: Bool {
        birds.isEmpty
    }

    /// One photo file of `bird`, `nil` when no pack here holds the species, the
    /// species has no such photo, or the file is not on disk.
    ///
    /// - Parameter index: which of ``Bird/photos``; the default is the curated
    ///   portrait. See ``PackCatalog/photoURL(for:at:)``.
    public func photoURL(for bird: Bird, at index: Int = 0) -> URL? {
        catalog(for: bird)?.photoURL(for: bird, at: index)
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
