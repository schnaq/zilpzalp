import Testing

import ZilpZalpCore

@Test("Die Modulversion ist ein Semantic-Versioning-Tripel")
func versionIsSemanticVersioningTriple() {
    let components = ZilpZalpCore.version.split(separator: ".")

    #expect(components.count == 3)
    #expect(components.allSatisfy { Int($0) != nil })
}
