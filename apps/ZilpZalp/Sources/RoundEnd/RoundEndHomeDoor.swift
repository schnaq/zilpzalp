import SwiftUI
import ZilpZalpUI

/// The way out of the celebration: a house in the corner every other screen
/// keeps its back door in (#175).
///
/// Both buttons under the stars lead further into the app, and the swipe from
/// the edge is off here, so until now a child who wanted to stop — or to hand
/// the iPad to a sibling — had to play another round to get anywhere. This is
/// that way out, and it goes all the way home, as "Zeit fürs Nest" does: a
/// finished round is nothing to go back into.
///
/// **Not a back chevron and not a ``TopBar``.** Screen 1d draws neither, and
/// what this does is not "back" — so #150's rule stands untouched: the swipe
/// in from the left goes where a chevron stands, and here none does.
///
/// Wordless, like every other corner control in this app — the back chevron,
/// the grown-ups' cog, the album's door on the home screen. The child this
/// screen is for cannot read the word and knows the house; the grown-up is
/// told by VoiceOver.
struct RoundEndHomeDoor: View {
    /// Whether the round has been answered for: ``RoundEndScreen`` has
    /// awaited `record` and is still on the stack.
    ///
    /// The door stays shut until then, because #175 asks for the way out not
    /// to race the booking. Not because a write is fragile — `ProfileStore` is
    /// an actor and its `record` is synchronous, so leaving cannot interrupt
    /// one already on its way, and where nothing could be written there is
    /// nothing to lose by leaving either. What the wait buys is an exit that
    /// never fires before the screen knows what the round changed, and it
    /// lasts one local file write, which is not a wait a child can notice.
    let isOpen: Bool

    /// Home — the whole stack, not one screen back.
    let goHome: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Where a ``TopBar``'s leading button would stand, measured the way the
    /// bar measures it: the screen gutter to the side, `--space-4` above, and
    /// the narrow phone gutter where 48 pt would eat a quarter of the width
    /// (#93).
    private var gutter: CGFloat {
        horizontalSizeClass == .compact ? ZSpacing.step4 : ZSpacing.gutterScreen
    }

    var body: some View {
        IconButton(
            .house,
            label: String(localized: "roundEnd.home.accessibility"),
            diameter: ZSpacing.touchMinimum,
            action: goHome,
        )
        .disabled(!isOpen)
        .padding(.horizontal, gutter)
        .padding(.vertical, ZSpacing.step4)
    }
}

#Preview("On the forest ground") {
    RoundEndHomeDoor(isOpen: true) {}
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(ZColor.surfaceForest)
}
