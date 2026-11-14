/// The sentence keys that more than one side of the project has to spell the
/// same way.
///
/// A pack records a sentence under a key, the render tool writes that key into
/// the manifest, and the app looks a clip up by it — three places, one string.
/// Most keys need no constant: they are String Catalog keys, and a screen
/// that says a sentence already names it once. These are different: none of
/// them is in the catalog at all — the sentence *is* the bird's name, its
/// fact or the pack's title, all pack data with nothing to translate — and a
/// literal in the app target would be a rule kept apart from the tool that
/// renders it.
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

    /// The clip that is a bird's fact — „Bei der Amsel ist der Papa ganz
    /// schwarz und hat einen gelben Schnabel." — said when a child taps the
    /// lightbulb on a collected sticker. Recorded once per species from
    /// ``Bird/fact`` into `speech/species.fact/<species>.m4a`. Named like
    /// ``packTitle``, after whose data it is and the field it is read from,
    /// rather than after the screen that says it.
    public static let speciesFact = "species.fact"

    /// The clip that is a pack's title — „Vögel Afrikas" — said when a child
    /// taps the pack in the collection picker (#306). Recorded once per pack
    /// and declared under the manifest's own `speech`, beside `birds` rather
    /// than in one of them.
    public static let packTitle = "pack.title"
}
