/// How good a voice sounds, in the three tiers the system offers.
///
/// The raw values are the ones `AVSpeechSynthesisVoiceQuality` uses, so the
/// app's mapping is a rename and nothing else. ``standard`` is that enum's
/// `.default`: the compact voice every device carries out of the box, and the
/// only tier a simulator ever has. The other two are downloads a grown-up
/// makes in Settings — an app cannot fetch them.
public enum SpeechVoiceQuality: Int, CaseIterable, Comparable, Sendable {
    /// The compact voice that ships with the system.
    case standard = 1
    /// Downloaded, noticeably smoother than ``standard``.
    case enhanced = 2
    /// Downloaded, the best the system has. iOS 16 and up.
    case premium = 3

    public static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// A voice the device offers, as the chooser sees it.
///
/// Core owns no data model — the app maps `AVSpeechSynthesisVoice` onto this
/// type, exactly as it maps its birds onto ``QuizSpecies``. That is what keeps
/// AVFoundation out of this module, and it is the only way the ranking can be
/// tested at all: a simulator carries compact voices only, so a premium voice,
/// an Austrian voice and a novelty voice can never be observed on the machine
/// that runs the tests.
public struct SpeechVoiceDescription: Hashable, Sendable {
    /// The system's identifier, e.g. `"com.apple.voice.compact.de-DE.Anna"`.
    /// Unique per voice, and what the app looks the winner back up by.
    public let identifier: String

    /// What a grown-up sees in Settings, e.g. `"Anna"`.
    public let name: String

    /// BCP-47 language tag, e.g. `"de-DE"`.
    public let language: String

    public let quality: SpeechVoiceQuality

    /// A character voice — the system's "Bahh", "Trinoids" and their like.
    /// Funny once, wrong for a question a child has to understand.
    public let isNovelty: Bool

    /// A voice the user recorded of themselves (iOS 17+). Never chosen here:
    /// reading one needs authorisation the app does not ask for yet, and an
    /// unauthorised device does not list them anyway.
    public let isPersonal: Bool

    public init(
        identifier: String,
        name: String,
        language: String,
        quality: SpeechVoiceQuality,
        isNovelty: Bool = false,
        isPersonal: Bool = false,
    ) {
        self.identifier = identifier
        self.name = name
        self.language = language
        self.quality = quality
        self.isNovelty = isNovelty
        self.isPersonal = isPersonal
    }
}

/// Picks the German voice the app speaks with.
///
/// The system's own `AVSpeechSynthesisVoice(language:)` answers this question
/// too, but only halfway: it returns an enhanced voice where one exists and
/// the compact one otherwise, and it never returns a premium voice at all. It
/// also says nothing about which voice it picked, so a grown-up who downloads
/// one cannot tell whether it took. This picks deliberately and the app logs
/// the result.
public enum SpeechVoiceChoice {
    /// The region the app is written for. Every other German-speaking region
    /// is a fallback — see ``best(from:)``.
    public static let preferredLanguage = "de-DE"

    /// The best German voice among `voices`, or `nil` when there is none.
    ///
    /// Novelty and personal voices are dropped, then what is left is ordered
    /// by three keys:
    ///
    /// 1. ``preferredLanguage`` before every other `de-*`. Region beats
    ///    quality on purpose: a premium `de-AT` would read the bird names in
    ///    an accent this app never wrote, and the app ships in Germany. Other
    ///    regions are kept as a fallback rather than dropped, because a device
    ///    with only `de-AT` should still speak German.
    /// 2. ``SpeechVoiceQuality/premium`` before ``SpeechVoiceQuality/enhanced``
    ///    before ``SpeechVoiceQuality/standard``.
    /// 3. Name, then identifier. Nothing here reads the order the system
    ///    handed the voices over in, and identifiers are unique, so two
    ///    launches of the same app on the same device always choose the same
    ///    voice — a question that changes voice between launches would be a
    ///    bug nobody could reproduce.
    public static func best(from voices: [SpeechVoiceDescription]) -> SpeechVoiceDescription? {
        voices
            .filter { isGerman($0.language) && !$0.isNovelty && !$0.isPersonal }
            .min { rank(of: $0) < rank(of: $1) }
    }

    /// The three keys of ``best(from:)``, smallest first. A type of its own
    /// rather than a `Comparable` conformance on ``SpeechVoiceDescription``:
    /// this is one module's opinion about voices, not a property of a voice.
    private struct Rank: Comparable {
        /// 0 for ``preferredLanguage``, 1 for every other German region.
        let region: Int
        /// Negated, so that the best quality is the smallest number.
        let quality: Int
        let name: String
        /// Unique, which is what makes the whole order total.
        let identifier: String

        static func < (lhs: Self, rhs: Self) -> Bool {
            if lhs.region != rhs.region {
                return lhs.region < rhs.region
            }
            if lhs.quality != rhs.quality {
                return lhs.quality < rhs.quality
            }
            if lhs.name != rhs.name {
                return lhs.name < rhs.name
            }
            return lhs.identifier < rhs.identifier
        }
    }

    private static func rank(of voice: SpeechVoiceDescription) -> Rank {
        Rank(
            region: normalized(voice.language) == normalized(preferredLanguage) ? 0 : 1,
            quality: -voice.quality.rawValue,
            name: voice.name,
            identifier: voice.identifier,
        )
    }

    /// Whether the tag names German, in any region.
    ///
    /// `"de"` alone counts — a tag without a region is still German.
    private static func isGerman(_ language: String) -> Bool {
        let tag = normalized(language)
        return tag == "de" || tag.hasPrefix("de-")
    }

    /// Case and separator folded away. BCP-47 says a tag is case-insensitive,
    /// and the underscore turns up wherever a POSIX locale leaks into one.
    ///
    /// Spelled out rather than `replacingOccurrences(of:with:)`, which would
    /// pull Foundation into a module that has done without it so far.
    private static func normalized(_ language: String) -> String {
        String(language.lowercased().map { $0 == "_" ? "-" : $0 })
    }
}
