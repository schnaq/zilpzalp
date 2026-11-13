import Foundation
import ZilpZalpCore
import ZilpZalpData

extension QuizSpecies {
    /// What Core needs to know of a pack's birds, in manifest order so that a
    /// seeded round is reproducible.
    ///
    /// The genus is the first word of the scientific name, the look-alike
    /// group the pack's own; Core needs nothing else of a bird. "Turdus
    /// merula" is a `Turdus`, and two of those side by side are a coin toss.
    ///
    /// Game 2 puts its question with the recording, so a bird without one
    /// cannot be the answer there — its photo stays in as a distractor (#31).
    static func pool(of birds: [Bird], game: Game, calls: [String: URL]) -> [QuizSpecies] {
        birds.map { bird in
            let genus = bird.scientificName.split(separator: " ").first
            return QuizSpecies(
                id: bird.id,
                genus: String(genus ?? ""),
                lookalike: bird.lookalike,
                canBeAsked: game == .names || calls[bird.id] != nil,
            )
        }
    }
}
