import SwiftUI
import ZilpZalpCore
import ZilpZalpUI

/// One rung of the bird ladder: the rank's bird, its name, and the stars it
/// takes to stand on it.
///
/// Drawn the same on the ladder itself and on the three-rung path of the
/// ascent, so a child meets one picture of a rank rather than two.
///
/// A rung not yet reached is a locked ``RewardSticker`` — grey, straight, with
/// a padlock, and **keeping its photo**. What is still out there is what makes
/// the next one worth climbing to, so it is never a blank.
struct RankRung: View {
    let rank: Rank
    /// The rank's bird from the pack, `nil` when the pack has no such species
    /// — the sticker then draws its glyph.
    let photo: Image?
    /// The child has this many stars or more.
    let reached: Bool
    /// This is the rung the child stands on. The card turns sun-yellow; there
    /// is exactly one of these on a ladder.
    let current: Bool
    /// Diameter of the sticker's disc.
    let size: CGFloat

    var body: some View {
        ZCard(tone: tone, padding: ZSpacing.step3) {
            VStack(spacing: ZSpacing.step2) {
                StickerCaption(caption: rank.displayName, earned: reached) {
                    RewardSticker(image: photo, icon: .bird, locked: !reached, size: size)
                }

                Badge(threshold, tone: reached ? .sun : .sand)
            }
            .frame(maxWidth: .infinity)
        }
        .accessibilityElement(children: .combine)
    }

    /// Sun for the rung the child is on, paper for the ones behind it, sand
    /// for the ones ahead — the same "not yet" grey a locked sticker wears.
    private var tone: ZCardTone {
        if current {
            return .sun
        }
        return reached ? .paper : .sand
    }

    /// "Start" for the first rung, "ab 25" for every other. A threshold of
    /// zero is not a price, and printing it as one would put a number in front
    /// of a child who has just begun.
    private var threshold: String {
        guard rank.threshold > 0 else { return String(localized: "rank.ladder.start") }
        return String(format: String(localized: "rank.ladder.threshold"), rank.threshold)
    }
}
