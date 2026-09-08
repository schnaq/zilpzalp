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
    /// The credits screen renders the same two values in a list rather than in
    /// this sentence, so it uses ``License/shortName`` directly, not this.
    var creditLine: String {
        String(
            format: String(localized: "quiz.photo.credit"),
            photo.attribution,
            photo.license.shortName,
        )
    }
}
