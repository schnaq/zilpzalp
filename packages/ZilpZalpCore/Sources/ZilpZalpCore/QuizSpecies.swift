/// A species as the round engine sees it.
///
/// Core owns no data model — the app maps its birds onto this type. `genus` is
/// the only measure of similarity the engine has: two species of the same
/// genus look so alike that three of them beside the answer would turn the
/// question into a coin toss.
public struct QuizSpecies: Hashable, Sendable {
    /// Identifier of the species, unique within a pool.
    public let id: String

    /// Genus of the species — the first word of the scientific name,
    /// `"Turdus"` for `"Turdus merula"`.
    public let genus: String

    public init(id: String, genus: String) {
        self.id = id
        self.genus = genus
    }
}
