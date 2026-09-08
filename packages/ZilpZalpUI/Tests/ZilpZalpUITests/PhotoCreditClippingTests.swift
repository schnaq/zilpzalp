import SwiftUI
import Testing
@testable import ZilpZalpUI

// The one thing about the credit strip that arithmetic keeps getting wrong.
//
// `PhotoCredit` is drawn inside the host's shape and clipped to it, and
// `ChoiceTile` strokes its 5 pt border inside that same shape and on top of
// the strip. Whether a glyph survives that is a question about pixels, and it
// has now been answered wrongly twice from geometry alone: #103 cut the first
// glyph off, and the inset it added left the trailing corner cutting the last
// one whenever a credit was short enough to stay on a single line (#111).
//
// So this asks the renderer instead. Every case draws the tile twice — once as
// the tile draws it, once with neither the clip nor the border — and counts the
// glyph pixels the first one lost. Both renders happen in the same process with
// the same font and the same text layout, so a difference is the shape eating
// type and nothing else. It is not a golden image: it compares two live
// renders, and it fails only when a glyph is actually cut.

/// The three credits that press hardest on the corners.
///
/// The first is the case #111 is about: short enough to stay on one line, so it
/// runs the full width of the line that sits deepest in the curve. The second
/// is the longest attribution the base pack produces, which wraps onto that
/// line instead. The third starts on a narrow glyph, where a clip on the
/// leading side is easiest to misread as kerning.
private let creditsUnderPressure = [
    "Foto: Dmitry Ivanov (CC BY)",
    "Foto: Alexis Tinker-Tsavalas (CC BY)",
    "Jane Ivanović-Tremayne (CC BY-SA 4.0)",
]

@MainActor
@Suite("The photo credit against its host's corners")
struct PhotoCreditClippingTests {
    @Test(
        "No attribution loses a glyph to the tile's corner or its border",
        arguments: creditsUnderPressure,
    )
    func nothingIsCut(credit: String) throws {
        #expect(BundledFonts.registered)
        // The floor, the 220 pt of #11, and the design's own tile. Read in the
        // test body rather than passed as a second argument set: ``ChoiceTile``
        // is a `View`, so its statics are main-actor isolated, and the `@Test`
        // macro evaluates its arguments outside the actor.
        for size in [ChoiceTile.minimumSize, 220, ChoiceTile.defaultSize] {
            #expect(try lostInk(credit: credit, size: size) == 0, "at \(size) pt")
        }
    }

    /// How many pixels of credit the tile's shape and border take off the
    /// strip, at `size`.
    private func lostInk(credit: String, size: CGFloat) throws -> Int {
        // A black photo, so the cream credit is the only bright thing in the
        // square and a luminance threshold is enough to find it. The tone's
        // own field is a pale tint and would not be.
        let photo = try #require(blackPhoto())
        let scale: CGFloat = 3
        let drawn = try #require(rasterise(
            ChoiceTile(image: photo, label: "Amsel", credit: credit, tone: .beeren, size: size),
            scale: scale,
        ))
        let unclipped = try #require(rasterise(
            Rectangle()
                .fill(Color.black)
                .overlay { photo.resizable().scaledToFill() }
                .overlay(alignment: .bottom) { PhotoCredit(text: credit) }
                .frame(width: size, height: size),
            scale: scale,
        ))
        // The button style seats the tile on a ledge below it, so the face is
        // the top `size` square of what was drawn. Everything below is ledge.
        let side = Int(size * scale)
        var lost = 0
        for row in 0 ..< side {
            for column in 0 ..< side {
                let ink = luminance(unclipped, column: column, row: row) > 0.55
                if ink, luminance(drawn, column: column, row: row) < 0.35 {
                    lost += 1
                }
            }
        }
        return lost
    }

    private struct Raster {
        let width: Int
        let pixels: [UInt8]
    }

    private func rasterise(_ view: some View, scale: CGFloat) -> Raster? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
        guard let image = renderer.cgImage,
              let context = CGContext(
                  data: nil,
                  width: image.width,
                  height: image.height,
                  bitsPerComponent: 8,
                  bytesPerRow: image.width * 4,
                  space: CGColorSpaceCreateDeviceRGB(),
                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
              )
        else { return nil }
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let data = context.data else { return nil }
        let bytes = data.bindMemory(to: UInt8.self, capacity: image.width * image.height * 4)
        return Raster(
            width: image.width,
            pixels: Array(UnsafeBufferPointer(start: bytes, count: image.width * image.height * 4)),
        )
    }

    private func luminance(_ raster: Raster, column: Int, row: Int) -> Double {
        let offset = (row * raster.width + column) * 4
        let red = Double(raster.pixels[offset]) / 255
        let green = Double(raster.pixels[offset + 1]) / 255
        let blue = Double(raster.pixels[offset + 2]) / 255
        let alpha = Double(raster.pixels[offset + 3]) / 255
        return alpha * (0.2126 * red + 0.7152 * green + 0.0722 * blue)
    }

    /// One black pixel, which `ChoiceTile` stretches over the whole square.
    private func blackPhoto() -> Image? {
        guard let context = CGContext(
            data: nil,
            width: 1,
            height: 1,
            bitsPerComponent: 8,
            bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue,
        ) else { return nil }
        context.setFillColor(gray: 0, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        return context.makeImage().map { Image(decorative: $0, scale: 1) }
    }
}
