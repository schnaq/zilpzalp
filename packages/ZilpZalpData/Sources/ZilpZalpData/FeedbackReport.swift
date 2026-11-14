import Foundation

/// What was on screen when a grown-up took a screenshot in a round: enough to
/// find the exact file in `data/packs/`, and nothing about the child.
///
/// There is deliberately no field for a profile name, stars or stickers, so a
/// report cannot carry them. Game and difficulty arrive as strings because this
/// package does not know `ZilpZalpCore`'s types.
public struct FeedbackSnapshot: Hashable, Sendable {
    /// One tile of the grid, as it looked at that moment.
    public struct Tile: Hashable, Sendable {
        /// The species id, for instance `amsel`.
        public let species: String
        /// The name the tile showed, for instance `Amsel`.
        public let name: String
        /// The pack the shown copy came from, `nil` when no pack claims it.
        public let pack: String?
        /// The file the tile showed, `nil` when none opened.
        public let photo: MediaAsset?

        public init(species: String, name: String, pack: String?, photo: MediaAsset?) {
            self.species = species
            self.name = name
            self.pack = pack
            self.photo = photo
        }
    }

    /// `names` or `calls`.
    public let game: String
    /// The difficulty's raw value.
    public let difficulty: String
    /// The question on screen, counted from 1.
    public let question: Int
    public let questionCount: Int
    /// The tiles in grid order.
    public let tiles: [Tile]
    /// The species the question asked for.
    public let answer: String?
    /// The call the question plays; `nil` in game 1.
    public let call: MediaAsset?
    /// Version and build, for instance `1.3.0 (231)`.
    public let app: String
    /// For instance `iOS 27.1`.
    public let system: String
    /// The model identifier, for instance `iPhone17,3`.
    public let device: String

    public init(
        game: String,
        difficulty: String,
        question: Int,
        questionCount: Int,
        tiles: [Tile],
        answer: String?,
        call: MediaAsset?,
        app: String,
        system: String,
        device: String,
    ) {
        self.game = game
        self.difficulty = difficulty
        self.question = question
        self.questionCount = questionCount
        self.tiles = tiles
        self.answer = answer
        self.call = call
        self.app = app
        self.system = system
        self.device = device
    }
}

/// What the grown-up says the report is about.
public enum FeedbackTarget: Hashable, Sendable {
    /// The tile of that species.
    case tile(String)
    /// The call the question played.
    case call
    case other
}

/// What is wrong, as the context block spells it for us.
public enum FeedbackReason: String, CaseIterable, Sendable {
    case blurry, crop, wrongBird = "wrong-bird", call, name, other
}

/// A grown-up's feedback on one moment of a round, as the mail body we read.
///
/// The subject is German copy and therefore built in the app, from
/// ``birdName``.
public struct FeedbackReport: Hashable, Sendable {
    /// Where every report goes.
    public static let recipient = "zilpzalp-app@posteo.net"

    private let snapshot: FeedbackSnapshot
    private let target: FeedbackTarget
    private let reason: FeedbackReason
    private let note: String

    public init(
        snapshot: FeedbackSnapshot,
        target: FeedbackTarget,
        reason: FeedbackReason,
        note: String,
    ) {
        self.snapshot = snapshot
        self.target = target
        self.reason = reason
        self.note = note
    }

    /// The bird the report is about: the picked tile's, the asked-for bird's
    /// for the call, `nil` for something else.
    public var birdName: String? {
        switch target {
        case let .tile(species): tile(species)?.name
        case .call: snapshot.answer.flatMap(tile)?.name
        case .other: nil
        }
    }

    /// The lines that tell us which file to fix and where it showed.
    public var context: String {
        [
            "reason: \(reason.rawValue)",
            assetLine,
            "game: \(snapshot.game) · difficulty: \(snapshot.difficulty) · screen: question \(snapshot.question) of \(snapshot.questionCount)",
            "tiles: \(snapshot.tiles.map(\.species).joined(separator: ", "))",
            "app: \(snapshot.app) · \(snapshot.system) · \(snapshot.device)",
        ]
        .compactMap(\.self)
        .joined(separator: "\n")
    }

    /// The mail body: the grown-up's note, then the context.
    ///
    /// - Parameter recipient: written on top for the share sheet, which cannot
    ///   preset one.
    public func body(recipient: String? = nil) -> String {
        [recipient, note.trimmingCharacters(in: .whitespacesAndNewlines), context]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: "\n\n")
    }

    private var assetLine: String? {
        switch target {
        case let .tile(species):
            let tile = tile(species)
            return "pack: \(tile?.pack ?? "none") · bird: \(species) · photo: \(describe(tile?.photo))"
        case .call:
            let answer = snapshot.answer ?? "none"
            let pack = snapshot.answer.flatMap(tile)?.pack ?? "none"
            return "pack: \(pack) · bird: \(answer) · call: \(describe(snapshot.call))"
        case .other:
            return nil
        }
    }

    private func tile(_ species: String) -> FeedbackSnapshot.Tile? {
        snapshot.tiles.first { $0.species == species }
    }

    private func describe(_ asset: MediaAsset?) -> String {
        asset.map { "\($0.file) (sha256 \($0.sha256.prefix(12)))" } ?? "none"
    }
}
