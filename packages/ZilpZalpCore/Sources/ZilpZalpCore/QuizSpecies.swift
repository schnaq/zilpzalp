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

    /// Whether a question may ask for this species. One that may not still
    /// stands among the choices as a distractor.
    ///
    /// What makes a species unaskable is the app's business and never the
    /// engine's: game 2 asks its question with a recorded call, so a species
    /// without one cannot be the answer there — while its photo is a perfectly
    /// good wrong answer (#31). In game 1 every species can be asked for,
    /// which is why this defaults to true.
    public let canBeAsked: Bool

    public init(id: String, genus: String, canBeAsked: Bool = true) {
        self.id = id
        self.genus = genus
        self.canBeAsked = canBeAsked
    }
}
