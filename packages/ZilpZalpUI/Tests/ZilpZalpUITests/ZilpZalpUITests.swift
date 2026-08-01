import Testing
import ZilpZalpUI

@Test("Die Modulversion ist ein Semantic-Versioning-Tripel")
func versionIsSemanticVersioningTriple() {
    let components = ZilpZalpUI.version.split(separator: ".")

    #expect(components.count == 3)
    #expect(components.allSatisfy { Int($0) != nil })
}
