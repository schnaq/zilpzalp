import Foundation
import ZilpZalpData

/// One thing the app says out loud: which sentence it is, which bird it is
/// about, and the words to fall back on when no recording of it is on the
/// device.
///
/// A string cannot be looked up — a sentence can. Every screen that used to
/// hand ``SpeechAnnouncer`` finished German now names its sentence instead, and
/// the announcer decides between the clip and the synthesiser (#165). What is
/// said does not change either way, which is why no call site can tell.
///
/// In the app target because the String Catalog is: the German a child hears is
/// product copy, and `ZilpZalpData` carries none of it. The keys are the
/// catalog's, verbatim, and they are also the keys a manifest carries under
/// `speech` — `tools/fetch_media/speech/sentences.py` renders exactly these
/// sentences, filled exactly this way. Two of them are not catalog keys: see
/// ``name(_:)`` and ``assembled(_:)``.
struct SpokenLine: Sendable {
    /// The sentence key, `nil` for the one line no single clip can say.
    let key: String?

    /// The species the sentence is about, `nil` where it belongs to none. A
    /// species sentence is recorded once per bird and travels in the pack, so
    /// this is half of what a clip is looked up by.
    let bird: Bird?

    /// What the synthesiser says when there is no clip: the German, localised
    /// and with its placeholders already filled.
    let text: String

    /// "Super gemacht! Amsel gesammelt!" — the praise for a bird the child has
    /// just met for the first time.
    static func firstFind(_ bird: Bird) -> SpokenLine {
        SpokenLine(
            key: "roundEnd.sticker.new.spoken",
            bird: bird,
            text: String(
                format: String(localized: "roundEnd.sticker.new.spoken"),
                spokenName(of: bird),
            ),
        )
    }

    /// "Amsel" — the bare name. The question of game 1, and what a sticker in
    /// the album says when it is tapped.
    ///
    /// One line for both since #220: the game asked "Wo ist die Amsel?" and
    /// now asks the name alone, which is the same words the album already
    /// spoke and therefore the same recording. No article — the template put
    /// one in front of the written name and produced "der Lachender Hans" —
    /// and no sentence around it: a child who is four hears "Amsel" and looks
    /// for the Amsel.
    ///
    /// ``SpeechKey/speciesName`` is the one sentence key that is not a String
    /// Catalog key: the sentence *is* the name, so there is nothing to
    /// translate and nothing to format. The manifests and the render tool
    /// spell it the same way, which is what lets a clip be found for it.
    static func name(_ bird: Bird) -> SpokenLine {
        SpokenLine(
            key: SpeechKey.speciesName,
            bird: bird,
            text: spokenName(of: bird),
        )
    }

    /// A sentence that belongs to no species: the praise, the eight rank
    /// ascents, both profile questions, the gate's hint, the question before a
    /// round is left.
    ///
    /// The key is read at runtime rather than written as a literal, which is
    /// what lets the eight rank sentences share one line of code. Nothing is
    /// lost by it: every entry in `Localizable.xcstrings` is
    /// `extractionState: manual`, so the catalog is maintained by hand and
    /// does not depend on Xcode finding the literal in the source.
    static func fixed(_ key: String) -> SpokenLine {
        SpokenLine(
            key: key,
            bird: nil,
            text: String(localized: String.LocalizationValue(key)),
        )
    }

    /// A line no clip can say, and the reason ``key`` is optional at all.
    ///
    /// Two kinds of sentence end up here. One the app puts together at
    /// runtime: "Zeit fürs Nest! Heute hast du 7 Sterne gesammelt." is two
    /// catalog entries and a number. And a pack's own title — „Vögel Afrikas",
    /// said when its picture is tapped in the collection picker (#187): a pack
    /// records sentences about its species, never its own name, so the words
    /// come from the manifest and the synthesiser says them.
    ///
    /// It carries no key —
    /// the plan's `SpokenLine` has a plain `String` there and no such case.
    /// Decision 4 of the recorded-speech plan is whether the sentence is
    /// reworded so that one clip could say it; until that is answered this line
    /// always lands on the synthesiser, which is exactly where it landed
    /// before.
    static func assembled(_ text: String) -> SpokenLine {
        SpokenLine(key: nil, bird: nil, text: text)
    }

    /// What a bird is called out loud.
    ///
    /// `pronunciation` from the manifest wherever a voice would mangle the
    /// written name — that fix belongs in the pack data, never here — and it
    /// is also the name a clip was rendered from, so the recording and the
    /// synthesiser say the same thing. `spoken_name` in
    /// `tools/fetch_media/speech/sentences.py` is this rule on the other side.
    private static func spokenName(of bird: Bird) -> String {
        bird.pronunciation ?? bird.name
    }
}
