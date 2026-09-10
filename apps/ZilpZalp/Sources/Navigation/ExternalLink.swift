import Foundation
import SwiftUI
import ZilpZalpUI

/// A URL on its way out of the app, waiting behind the adult-level task.
///
/// A wrapper rather than the bare `URL` because `.sheet(item:)` needs an
/// `Identifiable`, and the URL is its own identity: two rows pointing at the
/// same page are the same pending link.
struct ExternalLink: Identifiable {
    let url: URL

    var id: URL {
        url
    }
}

extension View {
    /// Puts ``ParentalGate`` between this screen and everywhere it leads out
    /// of the app.
    ///
    /// **The app's only `openURL` call site.** Two screens lead out — the
    /// public screen about the app and the credits pushed from it — and both
    /// come through here, so there is one place where a link can leave and
    /// one place the gate can be forgotten in. Guideline 1.3 asks for an
    /// adult-level task in front of every one of them, and a screen that
    /// wanted to skip it would have to write the call itself.
    ///
    /// A row does not open anything; it sets the binding, and that is what
    /// puts the gate up. `nil` whenever no gate is up.
    func opensExternalLinks(_ link: Binding<ExternalLink?>) -> some View {
        modifier(ExternalLinkGate(link: link))
    }
}

// MARK: - The gate

private struct ExternalLinkGate: ViewModifier {
    @Binding var link: ExternalLink?

    @Environment(\.openURL) private var openURL

    func body(content: Content) -> some View {
        // The gate, undressed: it brings its own gutter and scrolls itself, so
        // the sheet only has to give it the page colour. Swiping it down is
        // the way out — there is nothing to confirm and nothing to save.
        content.sheet(item: $link) { pending in
            ParentalGate(reason: String(localized: "link.gate.reason")) {
                // Down first, then out: the sheet is gone before the browser
                // comes up, so coming back lands on the screen the link was
                // tapped on and not on a solved task.
                link = nil
                openURL(pending.url)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ZColor.surfacePage)
            // A page, not the default form sheet. Measured on an iPad Pro
            // 13-inch the form sheet is about 620 pt tall and cut the bottom
            // row of answer pills in half — the gate scrolls, so nothing was
            // unreachable, but a task whose answers are sliced through reads
            // as broken rather than as "there is more below". On a phone a
            // sheet is full width either way and this changes nothing.
            .presentationSizing(.page)
        }
    }
}
