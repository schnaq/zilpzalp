import SwiftUI
import ZilpZalpUI

/// One answer, at whatever edge length the grid worked out.
///
/// ``ChoiceTile`` clamps its `size` up to `ChoiceTile.minimumSize` — 220 pt —
/// and two of those with the gap between them need 464 pt, which is wider than
/// any iPhone. Above the floor this passes the size straight through; below
/// it, the tile is drawn at the floor and the result is scaled. `scaleEffect`
/// transforms hit testing along with the drawing, so the target stays the
/// whole face, and at the sizes an iPhone works out that is still well over
/// 64 pt.
///
/// A stopgap, and a narrow one: the credit strip scales with everything else,
/// so a CC BY photo on iPhone carries its attribution at about 10 pt instead
/// of the design's 13. The fix is a compact size in the component — a
/// follow-up on #11 rather than something to reach into the package for here.
struct QuizTile: View {
    let image: Image?
    let label: String
    let credit: String
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
            credit: credit,
            tone: tone,
            phase: phase,
            dimmed: dimmed,
            size: size,
            action: action,
        )
    }
}

#Preview("Above the component's floor, and below it") {
    HStack(alignment: .top, spacing: ZSpacing.gapTiles) {
        ForEach([260, 220, 165, 120], id: \.self) { edge in
            QuizTile(
                image: nil,
                label: "Vogelfoto 1",
                credit: "Foto: Alexis Tinker-Tsavalas (CC BY)",
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
