import SwiftUI
import ZilpZalpUI

/// The grown-ups' side of a feedback report, behind ``ParentalGate``.
struct FeedbackSheet: View {
    let capture: FeedbackCapture
    /// Closes the sheet; the round carries on from its `onDismiss`.
    let onDone: () -> Void

    var body: some View {
        ParentalGate(reason: String(localized: "feedback.gate.reason")) { onDone() }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ZColor.surfacePage)
            // A page, as in front of a link — see `ExternalLinkGate`.
            .presentationSizing(.page)
    }
}
