import SwiftUI
import ZilpZalpUI

/// Where the question stands, how big the answers come out, and the few
/// measurements that follow from both.
///
/// One rule, no cases, and the same one ``HomeScreen`` already uses for its
/// two tiles: measure both arrangements the design draws against the room
/// actually left over, and keep whichever puts the bigger photo in front of
/// the child. A size class is a category rather than a measurement, and
/// keying the arrangement on it is what gave an iPad in portrait the
/// landscape arrangement and left two thirds of the screen empty (#118).
///
/// The shape of the grid is not one of the choices — it is 2×2 everywhere.
/// Spec §4 fixes that for the iPad, and a single row loses the measurement
/// everywhere else too: four tiles across an iPhone in portrait are 74 pt
/// where two are 170.
///
/// The size class still settles how big the parts *around* the answers are
/// drawn: an iPad in portrait gets the question above the grid, but at the
/// iPad's type step, sound button and margins.
///
/// Main actor because the component floors it measures against —
/// `ChoiceTile.defaultSize`, `SoundButton.minimumDiameter` — are, and it is
/// only ever built from a view body.
@MainActor
struct QuizLayout {
    /// Where the question stands in relation to the answers.
    enum Arrangement {
        /// In a column to the left of the grid — the design's iPad screen
        /// (1194×834, screens 1c and 3a).
        case beside
        /// In a row above the grid — the design's iPhone screen (390×844,
        /// screen 1j).
        case above
    }

    /// The tile edge the design draws on iPad, and the ceiling everywhere. A
    /// photo bigger than this does not make the question easier to answer.
    private static let maximumTile = ChoiceTile.defaultSize

    /// The column the question stands in beside the answers. Wide enough for
    /// the 160 pt sound button and for the longest bird name in the base pack
    /// to wrap into two lines at 36 pt.
    static let promptColumn: CGFloat = 320

    /// The least room the feedback band gets, whether or not there is
    /// anything to say — the 100 px the design reserves, and the tighter
    /// figure the phone screen draws. Both are a floor rather than the whole
    /// answer: what the band ends up at is measured, because a sentence long
    /// enough to wrap needs more than either (#116).
    private static let regularSlot: CGFloat = 100
    private static let compactSlot: CGFloat = 76

    let arrangement: Arrangement
    /// The edge length one answer tile is drawn at.
    let tile: CGFloat
    /// The gap between question, answers and the feedback band.
    let stackGap: CGFloat
    let soundDiameter: CGFloat
    let feedbackSlot: CGFloat

    /// - Parameters:
    ///   - area: What is left for question, answers and feedback once the top
    ///     bar, the leaf row and the screen margins have had their share.
    ///   - isCompact: A phone, or an iPad sharing its screen.
    ///   - feedbackBand: What the banner sentences actually measured at this
    ///     width, zero until the first layout pass has reported it. The
    ///     design's reserve is the floor: a band that needs less keeps the
    ///     100 pt the design draws, a sentence that has to wrap gets the room
    ///     it needs rather than being truncated (#116).
    init(area: CGSize, isCompact: Bool, feedbackBand: CGFloat) {
        let gap = isCompact ? ZSpacing.step4 : ZSpacing.step5
        let sound = isCompact ? SoundButton.minimumDiameter : ZSpacing.touchHero
        let slot = max(isCompact ? Self.compactSlot : Self.regularSlot, feedbackBand)

        let beside = Self.tileEdge(
            across: area.width - Self.promptColumn - ZSpacing.step7 - ZSpacing.gapTiles,
            down: area.height - slot - gap - ZSpacing.gapTiles - ZShadow.ledgeLargeOffset,
        )
        let above = Self.tileEdge(
            across: area.width - ZSpacing.gapTiles,
            down: area.height - sound - slot - 2 * gap - ZSpacing.gapTiles
                - 2 * ZShadow.ledgeLargeOffset,
        )

        stackGap = gap
        soundDiameter = sound
        feedbackSlot = slot
        // A tie goes to the row above: both arrangements are then at the
        // design's 260 pt ceiling, and the row keeps question and answers on
        // the screen's midline instead of pushing the grid into one half.
        arrangement = beside > above ? .beside : .above
        tile = max(beside, above)
    }

    /// Half of whichever of the two runs out first — the tiles are square and
    /// there are two of them each way — never above the design's tile, and
    /// never below the touch floor.
    ///
    /// The floor is a guard, not a layout: it can only bite where the room
    /// left is smaller than two touch targets, and since #117 locked the
    /// iPhone to portrait no supported geometry gets near it. The shortest
    /// screen the app supports — an iPhone SE, 343×481 pt of room — works out
    /// at 104 pt, and every other one is larger.
    private static func tileEdge(across: CGFloat, down: CGFloat) -> CGFloat {
        max(ZSpacing.touchMinimum, min(maximumTile, min(across, down) / 2).rounded(.down))
    }
}
