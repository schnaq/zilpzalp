import SwiftUI
import ZilpZalpUI

/// One answer, at whatever edge length the grid worked out.
///
/// At or above ``ChoiceTile/minimumSize`` — 168 pt since #104 — the measured
/// edge goes straight through and the component draws every part of the tile
/// at its design size, credit included. An iPhone 17 measures 169 and an iPad
/// 190 to 260, so that is the ordinary case.
///
/// Below the floor the tile is drawn at the floor and scaled down to the edge,
/// which is what this file did for every phone before #104. `scaleEffect`
/// transforms hit testing along with the drawing, so the target stays the
/// whole face and is still far above 64 pt; the frame says what the transform
/// leaves behind, or the grid's arithmetic stops matching the drawing.
///
/// What that costs depends entirely on how far below the floor a screen is,
/// and the two that are below it are not alike:
///
/// - **iPhone 17e**, 390×844, measures 162 — a scale of 0.96. The credit
///   comes out at 12.5 pt against the design's 13, on the same two lines,
///   with the licence whole. Nothing about that is worth a second thought.
/// - **iPhone SE**, 375×667, measures 81 — a scale of 0.48, because its
///   feedback band wraps to two lines at that width and takes 122 pt of the
///   481 the quiz has. The credit lands near 6 pt. That screen cannot have
///   both: 13 pt of credit over two lines is more than twice as wide as an
///   81 pt tile, and the floor is derived from exactly that width.
///
/// The SE therefore keeps the layout it has always had and pays in the credit.
/// Not a stopgap that wants quietly removing: #135 holds the measurements and
/// the three ways out, and the one that ends this branch is a narrower credit
/// strip (#111, #122), because the floor follows `PhotoCreditMetrics` down.
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
