import Foundation
import Testing
@testable import ZilpZalpUI

// The brand components: the vendored mark, the wordmark's size floor and the
// tone mapping ported from `design/components/brand/Wordmark.jsx`.
//
// The catalog checks read the source tree rather than `Bundle.module`, for the
// reason spelled out in `IconAssetCatalogTests`: `swift test` copies
// `.xcassets` verbatim instead of compiling them with `actool`, so an image
// lookup here cannot tell a real asset from a typo.

@Suite("Brand asset catalog")
struct BrandAssetCatalogTests {
    private static let packageRoot = URL(fileURLWithPath: #filePath)
        .deletingLastPathComponent() // ZilpZalpUITests
        .deletingLastPathComponent() // Tests
        .deletingLastPathComponent() // package root
    private static let imageset = packageRoot
        .appending(path: "Sources/ZilpZalpUI/Resources/Brand.xcassets")
        .appending(path: "\(BrandMark.assetName).imageset")

    @Test("the mark resolves to a complete imageset that keeps its own colours")
    func markResolvesAsset() throws {
        let data = try Data(contentsOf: Self.imageset.appending(path: "Contents.json"))
        let contents = try JSONDecoder().decode(ImagesetContents.self, from: data)
        let filenames = contents.images.compactMap(\.filename)

        #expect(filenames.count == 1, "the mark is one universal vector, not a set of scales")
        for filename in filenames {
            #expect(
                FileManager.default
                    .fileExists(atPath: Self.imageset.appending(path: filename).path),
                "\(BrandMark.assetName).imageset is missing \(filename)",
            )
        }

        // The inverse of the icon catalog's expectation. A template-rendered
        // mark would collapse the hoopoe's four brand colours and its crest
        // gradient into a single tint, and nothing at compile time says so.
        #expect(
            contents.properties?.templateRenderingIntent == "original",
            "the mark must not be template-rendered — it carries its own colours",
        )
        #expect(
            contents.properties?.preservesVectorRepresentation == true,
            "the mark does not preserve vector data, so it won't scale cleanly",
        )
    }

    @Test("the vendored mark is assets/logo.svg with only its intrinsic size changed")
    func vendoredMarkMatchesTheSourceArtwork() throws {
        let repositoryRoot = Self.packageRoot
            .deletingLastPathComponent() // packages
            .deletingLastPathComponent() // repository root
        let source = try String(
            contentsOf: repositoryRoot.appending(path: "assets/logo.svg"),
            encoding: .utf8,
        )
        let vendored = try String(
            contentsOf: Self.imageset.appending(path: "\(BrandMark.assetName).svg"),
            encoding: .utf8,
        )

        // The intrinsic size is the one permitted difference, so both files are
        // compared with it stripped out — the drawing itself has to stay
        // identical, or the app and the App Icon would show two different
        // birds. Matching the attributes rather than their values also keeps
        // this test from having to be edited whenever the size is retuned.
        //
        // Why the copy differs at all: `assets/logo.svg` declares
        // `width="100%" height="100%"`, which leaves actool no intrinsic size.
        // It falls back to the 3417-unit viewBox and bakes 2.4 MB of raster
        // fallbacks into the catalog for a mark that never renders above a few
        // hundred points. Pinning the size to 256 leaves 137 kB, and the
        // preserved vector keeps the mark sharp at any size regardless.
        #expect(
            Self.withoutIntrinsicSize(vendored) == Self.withoutIntrinsicSize(source),
            "the vendored mark has drifted from assets/logo.svg — copy it again",
        )
    }

    /// The SVG with the root element's `width`/`height` attributes removed.
    ///
    /// Anchored on `<svg`, because the artwork's own `<rect>` carries a
    /// `width`/`height` pair too and would otherwise be the match if the root
    /// element's attributes were ever reordered.
    private static func withoutIntrinsicSize(_ svg: String) -> String {
        svg.replacing(#/<svg width="[^"]*" height="[^"]*"/#, with: "<svg", maxReplacements: 1)
    }
}

/// `@MainActor`, because `View` conformance carries that isolation and these
/// tests build the views rather than only reading their tone mapping.
@Suite("Brand components")
@MainActor
struct BrandComponentTests {
    @Test("the design's 40 pt floor holds, and above it the size is the caller's")
    func sizeIsClampedToTheFloor() {
        #expect(Wordmark.minimumSize == 40)
        #expect(Wordmark(size: 0).size == 40)
        // `RewardScreen.jsx` asks for 34 — the floor wins.
        #expect(Wordmark(size: 34).size == 40)
        #expect(Wordmark(size: 40).size == 40)
        // `HomeScreen.jsx`, in the top bar.
        #expect(Wordmark(size: 44).size == 44)
        #expect(Wordmark(size: 88).size == 88)
        #expect(Wordmark().size == 64, "the design's own default")
    }

    @Test("the lockup inherits the floor from the wordmark it holds")
    func lockupInheritsTheFloor() {
        #expect(BrandLockup(size: 34).wordmark.size == 40)
        #expect(BrandLockup().wordmark.size == 64)
    }

    @Test("duo sets Zilp in olive and Zalp in the hoopoe orange")
    func duoToneUsesBothBrandColours() {
        #expect(Wordmark.Tone.duo.leadingColor == ZColor.primary)
        #expect(Wordmark.Tone.duo.trailingColor == ZColor.accent)
        // #48 names the ramp entries; these are what the semantic aliases are.
        #expect(Wordmark.Tone.duo.leadingColor == ZColor.olive500)
        #expect(Wordmark.Tone.duo.trailingColor == ZColor.orange500)
    }

    @Test("both mono tones set the whole mark in a single colour")
    func monoTonesAreSingleColour() {
        #expect(Wordmark.Tone.monoLight.leadingColor == ZColor.white)
        #expect(Wordmark.Tone.monoLight.trailingColor == ZColor.white)
        #expect(Wordmark.Tone.monoDark.leadingColor == ZColor.textStrong)
        #expect(Wordmark.Tone.monoDark.trailingColor == ZColor.textStrong)
    }

    @Test("the announced name is the two halves the wordmark draws")
    func nameIsTheDrawnWord() {
        #expect(ZBrand.name == "ZilpZalp")
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
