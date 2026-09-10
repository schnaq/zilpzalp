import SwiftUI
import ZilpZalpUI

/// The size a view lays out to, without drawing it.
///
/// `ImageRenderer` runs the real layout and reports what it would draw, which
/// is the only way a headless test can see a height that padding, a line box
/// or a wrapped paragraph decides. Shared by the suites that measure one —
/// `TopBarTests`, `NavigationComponentTests` and `SettingRowLayoutTests` — so
/// that a change to how the render is driven reaches all of them.
///
/// - Parameter width: Roomy by default, so that nothing in a height test is
///   decided by a squeeze. Pass a narrow one to measure a phone.
@MainActor
func renderedSize(_ view: some View, width: CGFloat = 768) -> CGSize {
    var measured = CGSize.zero
    ImageRenderer(content: view.frame(width: width))
        .render { size, _ in measured = size }
    return measured
}

/// The point size a label was actually drawn at.
///
/// What a `Text` was scaled to cannot be asked, so it is read back from the
/// width: advances scale with the point size, so the width a render with
/// nothing squeezing it reports, over the width CoreText typesets the same
/// string at `step`, is the size that reached the screen (#229).
///
/// The view is rendered without a frame around it — a shrunken `Text` reports
/// the width it was given, so a measurement inside one would only ever hand
/// back the frame.
///
/// - Parameters:
///   - view: The label as its component builds it, not a bare `Text`: the
///     modifiers around it are what the measurement is about.
///   - text: The string it draws, for the CoreText reference width.
///   - step: The step it is declared at.
@MainActor
func drawnSize(of view: some View, text: String, declaredAt step: ZType.Step) -> CGFloat {
    var loose = CGSize.zero
    ImageRenderer(content: view).render { size, _ in loose = size }
    let natural = BundledFonts.width(of: text, postScriptName: "Baloo2-Bold", size: step.size)
    return step.size * loose.width / natural
}
