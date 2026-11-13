import SwiftUI

/// One bird photo, or four in a two-by-two: the picture that stands for a
/// difficulty level.
///
/// ``Style/tile`` is a rung of the picker, on ``ChoiceTile``'s papier tone
/// with each photo's outer corner following the tile's curve.
/// ``Style/mosaic`` is the home screen's pill: bare photos and no frame,
/// because inside a capsule a second frame reads as a second button.
///
/// Every level is drawn in the same neutral sand. Sun means reward and "try
/// again", clay is info, bark is a rubric — none of them may mean a level, and
/// olive is kept for one thing only: ``chosen``.
///
/// A missing photo (`nil`) draws a bird glyph, so a level never shows an empty
/// hole. Hidden from accessibility: the picker wraps it in a `Button` of its
/// own and labels that.
///
/// ```swift
/// PhotoQuartet(photos: [a, b, c, d], size: 200, chosen: true)
/// PhotoQuartet(photos: [a, b, c, d], size: 48, style: .mosaic)
/// ```
public struct PhotoQuartet: View {
    /// How the photos are framed.
    public enum Style: Sendable {
        /// A rung of the level picker: papier field, rim and ledge.
        case tile
        /// The level on the home screen's pill: bare photos, no field, rim or
        /// ledge.
        case mosaic
    }

    /// From this edge length up a tile is the iPad's — radius 40, the 10 pt
    /// ledge, wider gutters, the bigger check. The phone's rung is about
    /// 96 pt, the iPad's 200.
    ///
    /// `nonisolated`: `View` carries main actor isolation, and
    /// ``PhotoQuartetMetrics`` reads this plain constant outside it.
    public nonisolated static let largeTile: CGFloat = 160

    private let photos: [Image?]
    private let size: CGFloat
    private let style: Style
    private let chosen: Bool

    /// - Parameters:
    ///   - photos: Already resolved by the app. One fills the square; any
    ///     other count lays out four cells, padding with the placeholder.
    ///   - size: Edge length of the square, rim included and ledge not.
    ///   - style: See ``Style``.
    ///   - chosen: This level is the picked one: rim and ledge turn olive at
    ///     the same width, so nothing shifts, and ``ChosenCheck`` joins the
    ///     corner — a shape as well as a colour, for a child who tells no
    ///     olive from sand. Ignored by ``Style/mosaic``.
    public init(photos: [Image?], size: CGFloat, style: Style = .tile, chosen: Bool = false) {
        self.photos = photos
        self.size = size
        self.style = style
        self.chosen = chosen
    }

    /// How many columns the photos fill, as many rows as that: one photo takes
    /// the whole square, every other count a two-by-two.
    public static func columns(photoCount: Int) -> Int {
        photoCount == 1 ? 1 : 2
    }

    private var metrics: PhotoQuartetMetrics {
        PhotoQuartetMetrics(style: style, size: size)
    }

    public var body: some View {
        Group {
            switch style {
            case .tile: tile
            case .mosaic: grid
            }
        }
        .accessibilityHidden(true)
    }

    private var tile: some View {
        grid
            .papierSurface(
                RoundedRectangle(cornerRadius: metrics.radius, style: .continuous),
                chosen: chosen,
                ledge: metrics.ledge,
            )
            .overlay(alignment: .bottomTrailing) {
                if chosen {
                    ChosenCheck(tileSize: size)
                }
            }
    }

    private var grid: some View {
        let columns = Self.columns(photoCount: photos.count)
        let side = size - 2 * metrics.inset
        let gutter = columns == 1 ? 0 : metrics.gutter
        let cell = (side - gutter * CGFloat(columns - 1)) / CGFloat(columns)

        return VStack(spacing: gutter) {
            ForEach(0 ..< columns, id: \.self) { row in
                HStack(spacing: gutter) {
                    ForEach(0 ..< columns, id: \.self) { column in
                        let index = row * columns + column
                        photo(
                            index < photos.count ? photos[index] : nil,
                            side: cell,
                            corners: corners(of: index, columns: columns),
                        )
                    }
                }
            }
        }
        .frame(width: size, height: size)
    }

    /// The outer corner where a photo meets the square's edge, a small one
    /// where it meets another photo — and all four the same on a photo that
    /// fills the square alone.
    private func corners(of index: Int, columns: Int) -> RectangleCornerRadii {
        let alone = columns == 1
        let outer = alone ? metrics.soloCorner : metrics.outerCorner
        let inner = metrics.innerCorner

        /// The corner of the square that lies in `cell`, counted as the grid
        /// counts: the outer curve on that photo, a small one on the others.
        func radius(_ cell: Int) -> CGFloat {
            alone || index == cell ? outer : inner
        }

        return RectangleCornerRadii(
            topLeading: radius(0),
            bottomLeading: radius(2),
            bottomTrailing: radius(3),
            topTrailing: radius(1),
        )
    }

    private func photo(
        _ image: Image?,
        side: CGFloat,
        corners: RectangleCornerRadii,
    ) -> some View {
        Rectangle()
            .fill(ZColor.sand200)
            .overlay {
                if let image {
                    image
                        .resizable()
                        .scaledToFill()
                } else {
                    Icon(
                        .bird,
                        size: .custom((side * PhotoQuartetMetrics.placeholderRatio).rounded()),
                    )
                    .foregroundStyle(ZColor.bark500)
                }
            }
            .frame(width: side, height: side)
            .clipShape(UnevenRoundedRectangle(cornerRadii: corners, style: .continuous))
    }
}

/// The olive check on the corner of a chosen ``PhotoQuartet`` tile — the one a
/// chosen ``RewardSticker`` carries, sized to the tile.
///
/// Public for the one chosen thing the app lays out itself, the level
/// picker's Klassisch row, so that its check *is* this one rather than a copy
/// that drifts. Put it in a `.bottomTrailing` overlay: it hangs past the
/// corner by itself, as far as the tile's own does.
public struct ChosenCheck: View {
    private let tileSize: CGFloat

    /// - Parameter tileSize: The edge of the tile it goes with. From
    ///   ``PhotoQuartet/largeTile`` up it is the iPad's 44 pt check, 9 pt past
    ///   the corner; below, the phone's 32 pt, 5 pt past.
    public init(tileSize: CGFloat) {
        self.tileSize = tileSize
    }

    public var body: some View {
        let large = tileSize >= PhotoQuartet.largeTile
        let diameter: CGFloat = large ? 44 : 32
        let overhang: CGFloat = large ? 9 : 5
        let colours = RewardStickerPalette.checked

        Icon(
            .check,
            size: .custom((diameter * RewardStickerMetrics.badgeGlyphRatio).rounded()),
        )
        .foregroundStyle(colours.foreground)
        .frame(width: diameter, height: diameter)
        .background(Circle().fill(colours.background))
        .overlay { Circle().strokeBorder(colours.edge, lineWidth: ZBorder.width) }
        .offset(x: overhang, y: overhang)
        // The control it sits on says "selected"; the check would say it twice.
        .accessibilityHidden(true)
    }
}

public extension View {
    /// ``ChoiceTile``'s papier tone behind and around this view: the sand
    /// field, the 5 pt rim and, `ledge` below, the ledge — rim and ledge in
    /// the two olives while `chosen`.
    ///
    /// Public for the level picker's Klassisch row, which is no quartet but
    /// stands under the rungs and must be the same surface.
    func papierSurface(
        _ shape: some InsettableShape,
        chosen: Bool,
        ledge: CGFloat,
    ) -> some View {
        let papier = ChoiceTile.Tone.papier

        return background(shape.fill(papier.field))
            .overlay {
                shape.strokeBorder(
                    chosen ? ZColor.primary : papier.edge,
                    lineWidth: ZBorder.widthThick,
                )
            }
            .background(
                shape
                    .fill(chosen ? ZColor.primaryShadow : papier.edge)
                    .offset(y: ledge),
            )
    }
}

/// A quartet's numbers for one style at one size, in one place so the tests
/// can read them. The values without a token are the reviewed mockup's.
struct PhotoQuartetMetrics {
    /// The bird glyph in a cell without a photo, as a share of the cell.
    static let placeholderRatio: CGFloat = 0.45

    /// The corner of the square: the tile's own, or the mosaic's silhouette.
    let radius: CGFloat
    /// The ledge under the tile, zero for the mosaic.
    let ledge: CGFloat
    /// From the square's outer edge to the photos: the tile's rim and the sand
    /// between it and the photos.
    let inset: CGFloat
    /// Between two photos.
    let gutter: CGFloat
    /// A photo's corner where it meets another photo.
    let innerCorner: CGFloat
    /// The corner of a photo that fills the square alone.
    let soloCorner: CGFloat

    /// A photo's corner on the square's edge: concentric with the square, so
    /// the photos follow its curve instead of cutting across it.
    var outerCorner: CGFloat {
        radius - inset
    }

    init(style: PhotoQuartet.Style, size: CGFloat) {
        switch style {
        case .tile:
            let large = size >= PhotoQuartet.largeTile
            radius = large ? ZRadius.tile : ZRadius.large
            ledge = large ? ZShadow.ledgeLargeOffset : ZShadow.ledgeOffset
            inset = ZBorder.widthThick + (large ? 10 : 5)
            gutter = large ? 6 : 4
            innerCorner = large ? 10 : 6
            soloCorner = radius - inset
        case .mosaic:
            // 20 keeps the corner photos 3 pt clear of the pill's inner curve;
            // 14 left less than one.
            radius = ZRadius.medium
            ledge = 0
            inset = 0
            gutter = 2
            innerCorner = 3
            // At the mosaic's 20 a lone photo reads as a disc — a second
            // collection sticker beside the collection pill.
            soloCorner = 16
        }
    }
}

#Preview("Tiles: one, four, missing, chosen; mosaics") {
    let four = (0 ..< 4).map { _ in previewPhoto() }

    VStack(spacing: ZSpacing.step7) {
        HStack(alignment: .top, spacing: ZSpacing.step5) {
            PhotoQuartet(photos: four, size: 200)
            PhotoQuartet(photos: [previewPhoto(), nil, previewPhoto(), nil], size: 200)
            PhotoQuartet(photos: [previewPhoto()], size: 200)
            PhotoQuartet(photos: four, size: 200, chosen: true)
        }
        HStack(alignment: .top, spacing: ZSpacing.step3) {
            PhotoQuartet(photos: four, size: 96)
            PhotoQuartet(photos: [nil], size: 96)
            PhotoQuartet(photos: four, size: 96, chosen: true)
        }
        // On the pill's own card colour.
        HStack(spacing: ZSpacing.step5) {
            PhotoQuartet(photos: four, size: 48, style: .mosaic)
            PhotoQuartet(photos: [previewPhoto()], size: 48, style: .mosaic)
            PhotoQuartet(photos: [nil, nil, nil, nil], size: 48, style: .mosaic)
            PhotoQuartet(photos: [previewPhoto()], size: 72, style: .mosaic)
        }
        .padding(ZSpacing.step5)
        .background(ZColor.surfaceCard)
    }
    .padding(ZSpacing.step7)
    .background(ZColor.surfacePage)
}
