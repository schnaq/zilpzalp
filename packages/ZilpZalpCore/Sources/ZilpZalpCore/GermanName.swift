/// A child's name in the genitive, for a headline that says whose album this
/// is (#204).
///
/// German forms the possessive of a name by appending an *s* — „Johannas
/// Sammlung". A name that already ends in an s sound takes an apostrophe
/// instead, because a second s would be unpronounceable: „Hans’ Sammlung",
/// „Max’ Sammlung", „Felix’ Sammlung", „Fritz’ Sammlung".
///
/// Here rather than in the screen, because it is a rule with cases and a rule
/// with cases wants a test. The String Catalog holds the sentence this word
/// goes into, so a language that forms possession some other way can
/// restructure the whole phrase rather than inherit German word order.
public enum GermanName {
    /// The letters that already carry the s sound, so the apostrophe stands
    /// in for the ending rather than doubling it. Duden's list for names.
    private static let sSounds: Set<String> = ["s", "ß", "x", "z"]

    /// The typographic apostrophe U+2019, not the typewriter `'`. It is the
    /// one German sets, and the app's own texts use it throughout.
    private static let apostrophe = "\u{2019}"

    /// `name` in the genitive: „Johanna" becomes „Johannas", „Hans" becomes
    /// „Hans’".
    ///
    /// An empty name comes back empty. `ProfileStore` never stores one — the
    /// creation screen trims and refuses a blank — so this is the answer to a
    /// file edited by hand, not a case any screen has to draw around.
    public static func possessive(of name: String) -> String {
        guard let last = name.last else { return name }
        return sSounds.contains(String(last).lowercased()) ? name + apostrophe : name + "s"
    }
}
