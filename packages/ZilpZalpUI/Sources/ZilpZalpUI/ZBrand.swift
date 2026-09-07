/// The brand's own words — the one place in this package that spells them out.
///
/// A wordmark *is* its string: a ``Wordmark`` that took its text from a
/// parameter would no longer be a wordmark, and "ZilpZalp" is a proper noun
/// rather than product copy. Every other visible string in a component stays a
/// parameter, so the only String Catalog remains the app target's.
public enum ZBrand {
    /// The full name, as VoiceOver announces the mark and the lockup.
    public static let name = leadingHalf + trailingHalf

    /// The first half of the wordmark, set in olive.
    static let leadingHalf = "Zilp"
    /// The second half, set in the hoopoe orange.
    static let trailingHalf = "Zalp"
}
