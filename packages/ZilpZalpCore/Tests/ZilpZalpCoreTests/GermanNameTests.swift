import Testing
import ZilpZalpCore

@Test(
    "A name takes an s, unless it already ends in one",
    arguments: [
        ("Johanna", "Johannas"),
        ("Mia", "Mias"),
        ("Hans", "Hans\u{2019}"),
        ("Mats", "Mats\u{2019}"),
        ("Max", "Max\u{2019}"),
        ("Felix", "Felix\u{2019}"),
        ("Fritz", "Fritz\u{2019}"),
        ("Weiß", "Weiß\u{2019}"),
        // A name a grown-up typed in capitals is still a name.
        ("MAX", "MAX\u{2019}"),
        ("LARA", "LARAs"),
    ],
)
func possessiveOfAName(name: String, expected: String) {
    #expect(GermanName.possessive(of: name) == expected)
}

@Test("An empty name stays empty rather than becoming an s")
func possessiveOfNothing() {
    // The creation screen trims and refuses a blank, so no profile the app
    // writes gets here. A hand-edited file should not put a lone "s" on the
    // album's headline either.
    #expect(GermanName.possessive(of: "") == "")
}
