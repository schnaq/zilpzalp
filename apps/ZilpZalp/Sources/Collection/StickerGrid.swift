import SwiftUI
import ZilpZalpUI

/// How wide a round photo is drawn and how far apart they stand: four across
/// on an iPad, three on a phone.
///
/// Two screens lay out the same grid of stickers — the album
/// (``CollectionScreen``) and the collection picker (``CollectionPicker``) —
/// and a child should recognise the second as the same kind of page as the
/// first. Two copies of four numbers would have drifted apart on the first
/// change to either screen.
enum StickerGrid {
    /// The sticker's disc.
    static func size(compact: Bool) -> CGFloat {
        compact ? 80 : 128
    }

    /// How wide a column may get before another sticker fits beside it.
    static func column(compact: Bool) -> CGFloat {
        compact ? 88 : 168
    }

    /// Three stickers across on a 375 pt phone rather than two, which is what
    /// the design's grid reads as. The gap gives way before the sticker does.
    static func spacing(compact: Bool) -> CGFloat {
        compact ? ZSpacing.step3 : ZSpacing.gapTiles
    }
}
