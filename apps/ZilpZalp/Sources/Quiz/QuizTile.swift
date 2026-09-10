import SwiftUI
import ZilpZalpUI

/// One answer, at whatever edge length the grid worked out.
///
/// At or above ``ChoiceTile/minimumSize`` — the design's 160 pt hero touch
/// target since #200 — the measured edge goes straight through and the
/// component draws every part of the tile at its design size. An iPhone 17
/// measures 169, an iPhone 17e 162 and an iPad 190 to 260, so that is the
/// ordinary case on every screen but one.
///
/// Below the floor the tile is drawn at the floor and scaled down to the edge,
/// which is what this file did for every phone before #104. `scaleEffect`
/// transforms hit testing along with the drawing, so the target stays the
/// whole face and is still far above 64 pt; the frame says what the transform
/// leaves behind, or the grid's arithmetic stops matching the drawing.
///
/// The one screen below the floor is the **iPhone SE**, 375×667, which
/// measures 81 — a scale of 0.51, because its feedback band wraps to two
/// lines at that width and takes 122 pt of the 481 the quiz has. Scaling
/// rather than drawing at 81 pt is what keeps the badge, its glyph and the
/// border in proportion to the photo instead of covering it: they are drawn
/// at one size whatever the square is.
struct QuizTile: View {
    let image: Image?
    let label: String
    let tone: ChoiceTile.Tone
    let phase: ChoiceTile.Phase
    let dimmed: Bool
    let edge: CGFloat
    let action: () -> Void

    var body: some View {
        if edge >= ChoiceTile.minimumSize {
            tile(size: edge)
        } else {
            let scale = edge / ChoiceTile.minimumSize
            tile(size: ChoiceTile.minimumSize)
                .scaleEffect(scale)
                // The component's own height is its size plus the ledge the
                // button style seats it on; both scale, and the frame has to
                // say so or the grid's arithmetic stops matching the drawing.
                .frame(
                    width: edge,
                    height: (ChoiceTile.minimumSize + ZShadow.ledgeLargeOffset) * scale,
                )
        }
    }

    private func tile(size: CGFloat) -> some View {
        ChoiceTile(
            image: image,
            label: label,
            tone: tone,
            phase: phase,
            dimmed: dimmed,
            size: size,
            action: action,
        )
    }
}

#Preview("Every edge the quiz measures, and the one below the floor") {
    // 260 and 190 are iPads, 169 an iPhone 17, 162 an iPhone 17e, 160 the
    // floor itself, and 81 the iPhone SE — the only measured edge that still
    // has to be scaled.
    HStack(alignment: .top, spacing: ZSpacing.gapTiles) {
        ForEach([260, 190, 169, 162, ChoiceTile.minimumSize, 81], id: \.self) { edge in
            QuizTile(
                image: nil,
                label: "Vogelfoto 1",
                tone: .beeren,
                phase: .idle,
                dimmed: false,
                edge: edge,
                action: {},
            )
        }
    }
    .padding(ZSpacing.step6)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(ZColor.surfacePage)
}
