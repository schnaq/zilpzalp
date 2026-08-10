import Foundation
import Testing
import ZilpZalpUI

/// `swift test` (what `mise run check` runs) copies `.xcassets` bundles
/// verbatim instead of compiling them with `actool` — that compilation step
/// only happens when Xcode drives the build, as it does for Previews and for
/// `mise run build`. So `Bundle.module` image lookups can't tell a real icon
/// from a typo under this test runner; reading the catalog straight from the
/// source tree can. This still fails loudly on: a `ZIcon` case with no
/// matching imageset, an imageset with no matching `ZIcon` case (orphaned —
/// e.g. a case got renamed and the old imageset was never deleted), and an
/// imageset that exists but isn't actually tintable or scalable.
@Suite("Icon asset catalog")
struct IconAssetCatalogTests {
    private static let catalog = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // ZilpZalpUITests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // package root
        .appendingPathComponent("Sources/ZilpZalpUI/Resources/Icons.xcassets")

    @Test("every ZIcon case resolves to a complete, tintable imageset", arguments: ZIcon.allCases)
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

        // Without these two properties the glyph either ignores `.foregroundStyle`
        // (no template rendering) or blurs when resized (no vector data) — both
        // are silent at compile time, so a copy-pasted incomplete Contents.json
        // would otherwise stay green forever.
        #expect(
            contents.properties?.templateRenderingIntent == "template",
            "\(icon.rawValue).imageset is not template-rendered, so it won't tint",
        )
        #expect(
            contents.properties?.preservesVectorRepresentation == true,
            "\(icon.rawValue).imageset does not preserve vector data, so it won't scale cleanly",
        )
    }

    @Test("the catalog and ZIcon.allCases name exactly the same icons")
    func catalogMatchesAllCases() throws {
        let entries = try FileManager.default.contentsOfDirectory(atPath: Self.catalog.path)
        let imagesetNames = Set(
            entries.filter { $0.hasSuffix(".imageset") }
                .map { String($0.dropLast(".imageset".count)) },
        )
        let iconNames = Set(ZIcon.allCases.map(\.rawValue))

        #expect(imagesetNames.subtracting(iconNames).isEmpty, "imageset(s) with no ZIcon case")
        #expect(iconNames.subtracting(imagesetNames).isEmpty, "ZIcon case(s) with no imageset")
    }
}

private struct ImagesetContents: Decodable {
    let images: [ImagesetImage]
    let properties: ImagesetProperties?
}

private struct ImagesetImage: Decodable {
    let filename: String?
}

private struct ImagesetProperties: Decodable {
    let templateRenderingIntent: String?
    let preservesVectorRepresentation: Bool?

    enum CodingKeys: String, CodingKey {
        case templateRenderingIntent = "template-rendering-intent"
        case preservesVectorRepresentation = "preserves-vector-representation"
    }
}
