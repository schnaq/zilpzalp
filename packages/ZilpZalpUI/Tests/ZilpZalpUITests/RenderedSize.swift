import SwiftUI

/// The size a view lays out to, without drawing it.
///
/// `ImageRenderer` runs the real layout and reports what it would draw, which
/// is the only way a headless test can see a height that padding, a line box
/// or a wrapped paragraph decides. Shared by the suites that measure one —
/// `TopBarTests` and `SettingRowLayoutTests` — so that a change to how the
/// render is driven reaches both.
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
