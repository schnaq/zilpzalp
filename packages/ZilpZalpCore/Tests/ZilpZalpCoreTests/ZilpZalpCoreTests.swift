import Testing

import ZilpZalpCore

@Test("The module version is a semantic versioning triple")
func versionIsSemanticVersioningTriple() {
    let components = ZilpZalpCore.version.split(separator: ".")

    #expect(components.count == 3)
    #expect(components.allSatisfy { Int($0) != nil })
}
