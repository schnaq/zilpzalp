import Foundation

/// Which recording says one sentence — the pack's, the fixed set's, or none at
/// all.
///
/// The whole of "clip or synthesiser": everything the app says out loud asks
/// this one question, and the answer is a file or `nil`. `nil` is not a
/// failure, it is the ordinary case for a species nobody has recorded yet — the
/// caller then speaks the sentence with `AVSpeechSynthesizer` (#151), silently
/// and per sentence.
///
/// Here rather than beside the announcer in the app target for one reason: the
/// app has no tests that run without a simulator, and this is the branch that
/// has to be right. Both sides can be missing — a build whose bundled pack did
/// not open leaves an empty library, and the fixed set stays `nil` until the
/// sentences have been recorded.
public struct SpeechClips: Sendable {
    /// The packs the species sentences belong to — every installed one, not
    /// only the bundled pack: a downloaded species is asked for out loud like
    /// any other. ``PackLibrary/empty`` where a screen has no pack at all,
    /// which is every screen that only says fixed sentences.
    private let library: PackLibrary

    /// The sentences that belong to no species, shipped inside the app.
    private let fixed: SpeechCatalog?

    public init(library: PackLibrary, fixed: SpeechCatalog?) {
        self.library = library
        self.fixed = fixed
    }

    /// The clip that says `sentence`, `nil` when no file on disk does.
    ///
    /// One catalog is asked, never both: a sentence about a species is its
    /// pack's — "Wo ist die Amsel?" is recorded once per bird and travels with
    /// the birds — and a sentence about none is the fixed set's. The two key
    /// sets are disjoint by construction (`tools/fetch_media/speech`), so a
    /// second lookup could only ever find the wrong recording.
    ///
    /// - Parameters:
    ///   - sentence: The sentence key, as it stands under `speech` in a
    ///     manifest and in the String Catalog.
    ///   - bird: The species the sentence is about, `nil` for a sentence that
    ///     belongs to none.
    public func url(for sentence: String, about bird: Bird?) -> URL? {
        guard let bird else { return fixed?.url(for: sentence) }
        return library.speechURL(for: bird, sentence: sentence)
    }
}
