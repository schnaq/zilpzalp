import Testing

import ZilpZalpData

@Test("The module version is a semantic versioning triple")
func versionIsSemanticVersioningTriple() {
    let components = ZilpZalpData.version.split(separator: ".")

    #expect(components.count == 3)
    #expect(components.allSatisfy { Int($0) != nil })
}
