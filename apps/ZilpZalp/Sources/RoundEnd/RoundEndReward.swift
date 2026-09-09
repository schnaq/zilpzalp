import SwiftUI
import ZilpZalpUI

/// The bird this round was about, arriving with `zz-pop` — the middle of
/// ``RoundEndScreen``.
///
/// A type of its own for the reason ``RoundEndStars`` is one: the screen sits
/// on SwiftLint's 400-line ceiling, and the sticker's arrival is a part of it
/// that nothing else on the screen reads.
///
/// The name and the credit are drawn here rather than passed into
/// ``RewardSticker``, which would otherwise set both inside its disc: its
/// caption is `--text-strong` and disappears into the forest ground, and its
/// credit strip is clipped away at the left and right of the circle — where a
/// CC BY photographer's name must not be. Both are the component's to fix
/// (#11); until then the round end keeps its attribution whole and legible.
struct RoundEndReward: View {
    /// Where `zz-pop` starts the sticker: a little under full size rather than
    /// at nothing, so it lands instead of exploding.
    private static let popFromScale: CGFloat = 0.6

    /// The sticker on iPad, the 200 pt of screen 1e and `RewardScreen.jsx`.
    private static let regularSticker: CGFloat = 200

    /// The bird to show, `nil` while it is still being resolved and for a
    /// round without a pack — the sticker then falls back to its star glyph
    /// rather than to a hole.
    let sticker: RoundEndSticker?

    /// Whether the round put this bird in the album for the first time. Read
    /// off the profile the round was booked onto, so it is `false` until the
    /// screen has written the round down.
    let isFirstFind: Bool

    /// A phone, or an iPad sharing its screen: the sticker and both lines
    /// under it drop a step there.
    let isTight: Bool

    /// The screen has settled, so the sticker may pop in.
    let settled: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: ZSpacing.step2) {
            RewardSticker(
                image: sticker?.image,
                size: isTight ? RewardSticker.defaultSize : Self.regularSticker,
            )

            if let sticker {
                Text(verbatim: caption(for: sticker))
                    .typeStyle(isTight ? .body : .bodyLarge, .display, weight: .bold)
                    .foregroundStyle(ZColor.white)

                Text(verbatim: sticker.credit)
                    .typeStyle(.caption, .body, weight: .regular)
                    .foregroundStyle(ZColor.textOnColor)
            }
        }
        .accessibilityElement(children: .combine)
        .scaleEffect(popped ? 1 : Self.popFromScale)
        .opacity(popped ? 1 : 0)
        .animation(pop, value: settled)
    }

    /// The pop belongs to a bird met for the first time. One already in the
    /// album is simply there: still shown, still named, but the arrival is
    /// the reward for finding something new.
    private var popped: Bool {
        settled || !isFirstFind
    }

    /// `zz-pop`: the sticker bounces in over `--dur-celebrate`. Reduce Motion
    /// gets none, and the sticker is at full size from the first frame.
    private var pop: Animation? {
        reduceMotion ? nil : ZMotion.easeBounce.animation(duration: ZMotion.celebrate)
    }

    /// "Amsel gesammelt" for a first find, the bare name otherwise.
    private func caption(for sticker: RoundEndSticker) -> String {
        guard isFirstFind else { return sticker.name }
        return String(format: String(localized: "roundEnd.sticker.new"), sticker.name)
    }
}
