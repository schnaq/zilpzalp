import Foundation
import ZilpZalpData

extension Bird {
    /// The credit line drawn with this bird's photo: "Foto: A. Chudý (CC BY)".
    ///
    /// One place, because there is more than one screen showing the same photo
    /// — the quiz tiles and the round end's sticker — and attribution that is
    /// written twice is attribution that can drift from the manifest it comes
    /// from. Every base-pack photo is CC BY, which makes naming the
    /// photographer an obligation and not a courtesy.
    ///
    /// In the app target rather than in `ZilpZalpData` because the sentence
    /// around the two values is product copy and lives in the String Catalog.
    /// The credits screen (#37) renders the same two values in a list rather
    /// than in this sentence, so it wants ``License/shortName`` below, not
    /// this.
    var creditLine: String {
        String(
            format: String(localized: "quiz.photo.credit"),
            photo.attribution,
            photo.license.shortName,
        )
    }
}

private extension License {
    /// How a licence is named in a credit line: the short public name, not the
    /// SPDX identifier the manifest carries. "CC BY" is what the licence deed
    /// itself asks to be called; "CC-BY-4.0" is a filing code.
    ///
    /// Not product copy and therefore not in the String Catalog: these three
    /// names are the same in every language.
    ///
    /// App-private because #25 was not allowed to change `ZilpZalpData`. This
    /// is a fact about `License`, not about a screen, and it belongs beside
    /// the enum — the credits screen (#37) is the change that has a reason to
    /// move it there.
    var shortName: String {
        switch self {
        case .cc0: "CC0"
        case .ccBy: "CC BY"
        case .ccBySa: "CC BY-SA"
        }
    }
}
