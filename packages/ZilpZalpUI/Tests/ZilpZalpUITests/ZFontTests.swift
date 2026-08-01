import Testing
import ZilpZalpUI

// These tests only guard the mapping against accidental edits — they assert
// the same literals `postScriptName` returns, so they can't catch e.g. a
// typo shared between the switch and the fixture below. The authoritative
// check is that these exact PostScript names resolve to the real bundled
// font on-device (not the system-font fallback); see the PR for #8 for the
// on-device `UIFont(name:)` enumeration that verified this.

@Test(
    "Display weights resolve to the Baloo 2 named instances shipped in the bundled variable font",
    arguments: [
        (ZFont.Weight.regular, "Baloo2-Regular"),
        (ZFont.Weight.semibold, "Baloo2-SemiBold"),
        (ZFont.Weight.bold, "Baloo2-Bold"),
        (ZFont.Weight.extraBold, "Baloo2-ExtraBold"),
    ],
)
func displayPostScriptNamesMatchBundledNamedInstances(weight: ZFont.Weight, name: String) {
    #expect(ZFont.postScriptName(.display, weight: weight) == name)
}

@Test(
    "Body weights resolve to the Nunito named instances shipped in the bundled variable font",
    arguments: [
        (ZFont.Weight.regular, "Nunito-Regular"),
        (ZFont.Weight.semibold, "Nunito-SemiBold"),
        (ZFont.Weight.bold, "Nunito-Bold"),
        (ZFont.Weight.extraBold, "Nunito-ExtraBold"),
    ],
)
func bodyPostScriptNamesMatchBundledNamedInstances(weight: ZFont.Weight, name: String) {
    #expect(ZFont.postScriptName(.body, weight: weight) == name)
}
