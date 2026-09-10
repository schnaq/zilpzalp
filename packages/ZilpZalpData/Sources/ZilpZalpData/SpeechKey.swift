/// The sentence keys that more than one side of the project has to spell the
/// same way.
///
/// A pack records a sentence under a key, the render tool writes that key into
/// the manifest, and the app looks a clip up by it — three places, one string.
/// Most keys need no constant: they are String Catalog keys, and a screen
/// that says a sentence already names it once. This one is different. It is
/// not in the catalog at all — the sentence *is* the bird's name, so there is
/// nothing to translate — and since #220 two screens say it, which makes a
/// literal in the app target a rule kept in two places.
///
/// In `ZilpZalpData` rather than beside ``SpokenLine`` in the app target
/// because this is where the manifests are read, and because the app has no
/// tests that run without a simulator.
public enum SpeechKey {
    /// The clip that is nothing but a bird's name — "Amsel".
    ///
    /// Recorded once per species and travelling in its pack, said when a
    /// sticker in the album is tapped and asked as the question of game 1
    /// (#220). `collection.name` because the album was the first screen to
    /// say it; the string cannot change without the recordings changing with
    /// it, since `tools/fetch_media/speech` renders every clip into
    /// `speech/collection.name/<species>.m4a` and every manifest declares it
    /// under this key (#221).
    public static let speciesName = "collection.name"
}
