import Foundation
import Testing
import ZilpZalpUI

/// `swift test` (what `mise run check` runs) copies `.xcassets` bundles
/// verbatim instead of compiling them with `actool` — that compilation step
/// only happens when Xcode drives the build, as it does for Previews and for
/// `mise run build`. So `Bundle.module` image lookups can't tell a real icon
/// from a typo under this test runner; reading the catalog straight from the
/// source tree can, and still fails loudly if a `ZIcon` case has no matching,
/// complete imageset — the missing-asset fallback this test exists to catch.
@Suite("Icon asset catalog")
struct IconAssetCatalogTests {
    private static let catalog = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // ZilpZalpUITests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // package root
        .appendingPathComponent("Sources/ZilpZalpUI/Resources/Icons.xcassets")

    @Test("every ZIcon case resolves to a complete imageset", arguments: ZIcon.allCases)
    func resolvesAsset(_ icon: ZIcon) throws {
        let imageset = Self.catalog.appendingPathComponent("\(icon.rawValue).imageset")
        let contentsURL = imageset.appendingPathComponent("Contents.json")

        let data = try Data(contentsOf: contentsURL)
        let contents = try JSONDecoder().decode(ImagesetContents.self, from: data)
        let filenames = contents.images.compactMap(\.filename)

        #expect(!filenames.isEmpty, "\(icon.rawValue).imageset/Contents.json names no image")
        for filename in filenames {
            let assetURL = imageset.appendingPathComponent(filename)
            #expect(
                FileManager.default.fileExists(atPath: assetURL.path),
                "\(icon.rawValue).imageset is missing \(filename)",
            )
        }
    }
}

private struct ImagesetContents: Decodable {
    struct Image: Decodable {
        let filename: String?
    }

    let images: [Image]
}
