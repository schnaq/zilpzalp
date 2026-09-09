import SwiftUI
import ZilpZalpCore
import ZilpZalpUI

/// The three stars at the head of ``RoundEndScreen``, bobbing: the earned ones
/// filled, the rest hollow (#149).
///
/// A type of its own rather than a property on the screen, which sits on
/// SwiftLint's 400-line ceiling: the bob is the one part of that file nothing
/// else on it reads.
struct RoundEndStars: View {
    /// How far a star rises, from `zz-bob` in `design/guidelines/motion.css`.
    private static let bobHeight: CGFloat = 8

    /// One bob, out and back. No `ZMotion` duration covers it — the tokens
    /// stop at 900 ms because they time reactions, and this is idle life — so
    /// it is the 1.4 s of screen 1d. Halved where it is used: SwiftUI counts
    /// one leg, the autoreverse gives back the other.
    private static let bobPeriod: TimeInterval = 1.4

    /// How far apart the three stars start bobbing, again from screen 1d.
    /// Together they read as a wave rather than as one blinking row.
    private static let bobStagger: TimeInterval = 0.15

    /// A star that has not been earned: hollow, and olive rather than sun —
    /// dark enough against the forest ground to stay unlit, light enough to
    /// stay a star. What is missing is shown, as a locked ``RewardSticker`` is.
    private static let unlitStar = ZColor.olive600

    /// How many of the three are filled.
    let earned: Int

    /// The edge length of one star, which the screen picks by size class.
    let size: CGFloat

    /// The screen has settled, so the stars may take off. Never enough on its
    /// own — see ``bobbing``.
    let raised: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// True while the stars are up. Never true with Reduce Motion on, so they
    /// rest where they are drawn rather than 8 pt above it.
    private var bobbing: Bool {
        raised && !reduceMotion
    }

    /// Hidden from VoiceOver because the praise says the same right underneath.
    var body: some View {
        HStack(spacing: ZSpacing.step3) {
            ForEach(0 ..< Scoring.maximumStars, id: \.self) { position in
                Icon(position < earned ? .starFilled : .star, size: .custom(size))
                    .foregroundStyle(position < earned ? ZColor.reward : Self.unlitStar)
                    .offset(y: bobbing ? -Self.bobHeight : 0)
                    .animation(bob(delayedBy: Double(position) * Self.bobStagger), value: bobbing)
            }
        }
        .accessibilityHidden(true)
    }

    /// One bob, forever, offset so the three stars travel as a wave. Reduce
    /// Motion gets no animation, and without one nothing moves.
    private func bob(delayedBy delay: TimeInterval) -> Animation? {
        guard !reduceMotion else { return nil }
        return ZMotion.easeInOut.animation(duration: Self.bobPeriod / 2)
            .repeatForever(autoreverses: true)
            .delay(delay)
    }
}
