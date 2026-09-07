import SwiftUI

/// A stand-in for a bird photo, for previews only.
///
/// The package ships no photography — the app resolves the real `Image` and
/// hands it to ``ChoiceTile`` or ``RewardSticker`` — so the previews mount a
/// warm gradient where a photo will be. That is enough to see the square crop,
/// the rounded clip and the credit strip sitting on top of it.
///
/// It is `internal` rather than `private` only because two files' previews
/// need it. Nothing outside a `#Preview` body calls it, so it is never on a
/// render path and never reaches a device screen.
///
/// - Parameter size: Edge length of the rendered square. Only the aspect ratio
///   matters to the components; they scale it to fill.
@MainActor
func previewPhoto(size: CGFloat = 300) -> Image {
    let renderer = ImageRenderer(
        content: LinearGradient(
            colors: [ZColor.bark300, ZColor.olive500, ZColor.olive800],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        )
        .frame(width: size, height: size),
    )
    #if canImport(UIKit)
        return Image(uiImage: renderer.uiImage ?? UIImage())
    #else
        return Image(nsImage: renderer.nsImage ?? NSImage())
    #endif
}
