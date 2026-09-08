import SwiftUI
import ZilpZalpUI

/// One answer, at whatever edge length the grid worked out.
///
/// Above ``ChoiceTile/minimumSize`` — 168 pt since #104 — this hands the
/// measured edge straight through and the component draws it as measured.
/// That is every screen the app is drawn for: an iPhone 17 measures 169, an
/// iPhone 17e 162 (six points the component clamps and the margins absorb),
/// an iPad 190 to 260.
///
/// Below the floor the tile is drawn at the floor and scaled down to the edge,
/// which is what this file did for every phone before #104. `scaleEffect`
/// transforms hit testing along with the drawing, so the target stays the
/// whole face and is still far above 64 pt; the frame says what the transform
/// leaves behind, or the grid's arithmetic stops matching the drawing.
///
/// **One known device takes that branch: the iPhone SE**, 375×667 pt, which
/// measures 81 — its feedback band wraps to two lines at that width and takes
/// 122 pt of the 481 the quiz has. It cannot have both: 13 pt of credit over
/// two lines is more than twice as wide as an 81 pt tile, and the floor is
/// derived from exactly that. So the SE keeps the layout it has always had
/// and pays for it in the credit, which lands near 6 pt rather than the
/// design's 13. Not a stopgap that wants quietly removing: #135 holds the
/// three ways out and the measurements behind them, and the one that ends
/// this branch is a narrower credit strip (#111, #122), because the floor
/// follows `PhotoCreditMetrics` down.
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

#Preview("Every edge the quiz measures, and the one below the floor") {
    // 260 and 190 are iPads, 169 an iPhone 17, 168 the floor itself, and 81
    // the iPhone SE — the only measured edge that still has to be scaled.
    HStack(alignment: .top, spacing: ZSpacing.gapTiles) {
        ForEach([260, 190, 169, ChoiceTile.minimumSize, 81], id: \.self) { edge in
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
