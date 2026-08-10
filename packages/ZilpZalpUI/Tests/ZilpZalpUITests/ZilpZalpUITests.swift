import Testing
import ZilpZalpUI

@Test("The module version is a semantic versioning triple")
func versionIsSemanticVersioningTriple() {
    let components = ZilpZalpUI.version.split(separator: ".")

    #expect(components.count == 3)
    #expect(components.allSatisfy { Int($0) != nil })
}
