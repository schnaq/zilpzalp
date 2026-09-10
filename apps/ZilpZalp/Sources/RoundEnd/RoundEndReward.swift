import SwiftUI
import ZilpZalpUI

/// The bird this round was about, arriving with `zz-pop` — the middle of
/// ``RoundEndScreen``.
///
/// A type of its own for the reason ``RoundEndStars`` is one: the screen sits
/// on SwiftLint's 400-line ceiling, and the sticker's arrival is a part of it
/// that nothing else on the screen reads.
///
/// Under the name stand the progress markers, so the bird, its name and how
/// far it has come arrive as one block (#177).
///
/// The name is drawn here rather than passed into ``RewardSticker``, which
/// would otherwise set it inside its disc: its caption is `--text-strong` and
/// disappears into the forest ground. That is the component's to fix (#11);
/// until then the round end keeps the name legible on its own.
struct RoundEndReward: View {
    /// Where `zz-pop` starts the sticker: a little under full size rather than
    /// at nothing, so it lands instead of exploding.
    private static let popFromScale: CGFloat = 0.6

    /// The sticker on iPad, the 200 pt of screen 1e and `RewardScreen.jsx`.
    private static let regularSticker: CGFloat = 200

    /// The progress markers under it, sized against the disc they belong to:
    /// five markers and their gaps measure about six markers across.
    private static let regularMarker: CGFloat = 24
    private static let compactMarker: CGFloat = 20

    /// The bird to show, `nil` while it is still being resolved and for a
    /// round without a pack — the sticker then falls back to its star glyph
    /// rather than to a hole.
    let sticker: RoundEndSticker?

    /// Whether the round earned this bird's sticker — its fifth recognition
    /// (#177). Read off the profiles either side of the write, so it is
    /// `false` until the screen has written the round down.
    let earnedSticker: Bool

    /// How often this bird has been recognised now that the round is booked,
    /// for the markers under it. `nil` until then, and for a round that could
    /// not be written down: the screen makes no claim it cannot back up, and a
    /// row that filled in a moment later would be a second, quieter reward.
    let progress: Int?

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

                if let progress {
                    StickerMarkers(
                        count: progress,
                        markerSize: isTight ? Self.compactMarker : Self.regularMarker,
                    )
                }
            }
        }
        .accessibilityElement(children: .combine)
        .scaleEffect(popped ? 1 : Self.popFromScale)
        .opacity(popped ? 1 : 0)
        .animation(pop, value: settled)
        // The sticker lands in the hand as well as on the screen — the one
        // moment in the app that is worth a `success`, and only when the bird
        // is genuinely new. A bird already in the album is simply there, and
        // so is its arrival.
        //
        // On ``settled`` and not on ``popped``, which looks like the thing
        // that moves and is not: `celebrate()` writes `outcome` and `settled`
        // back to back without an `await` between them, so SwiftUI coalesces
        // both into one body pass and ``popped`` goes from `true` to `true`
        // — a trigger that never changes and a haptic that never fires.
        // `settled` turns over once, and `earnedSticker` is already answered
        // by the time it does.
        .sensoryFeedback(trigger: settled) { _, now in
            now && earnedSticker ? .success : nil
        }
    }

    /// The pop belongs to a sticker just earned. A bird whose sticker is
    /// already in the album is simply there: still shown, still named, but the
    /// arrival is the reward for having earned it.
    private var popped: Bool {
        settled || !earnedSticker
    }

    /// `zz-pop`: the sticker bounces in over `--dur-celebrate`. Reduce Motion
    /// gets none, and the sticker is at full size from the first frame.
    private var pop: Animation? {
        reduceMotion ? nil : ZMotion.easeBounce.animation(duration: ZMotion.celebrate)
    }

    /// "Amsel gesammelt" for a sticker just earned, the bare name otherwise.
    private func caption(for sticker: RoundEndSticker) -> String {
        guard earnedSticker else { return sticker.name }
        return String(format: String(localized: "roundEnd.sticker.new"), sticker.name)
    }
}
