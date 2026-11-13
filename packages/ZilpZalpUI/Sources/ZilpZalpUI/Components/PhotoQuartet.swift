import SwiftUI

/// One bird photo, or four in a two-by-two: the picture that stands for a
/// difficulty level.
///
/// One picture in two styles. ``Style/tile`` is a rung of the picker: the
/// photos on ``ChoiceTile``'s papier tone — sand field, 5 pt sand rim, sand
/// ledge — with each photo's outer corner following the tile's curve.
/// ``Style/mosaic`` is the home screen's pill: the bare photos with hairline
/// gutters and no frame, because inside a capsule a second frame reads as a
/// second button.
///
/// Every level is drawn in the same neutral sand. Sun means reward and "try
/// again", clay is info, bark is a rubric — none of them may mean a level, and
/// olive is kept for one thing only: ``chosen``.
///
/// A missing photo (`nil`) draws a bird glyph on the sand field, so a level
/// never shows an empty hole. Not a control; the picker wraps it in its own
/// `Button` and labels it, which is why the picture hides itself from
/// accessibility.
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

    private let photos: [Image?]
    private let size: CGFloat
    private let style: Style
    private let chosen: Bool

    /// - Parameters:
    ///   - photos: Already resolved by the app. One fills the square; any
    ///     other count lays out four cells, padding with the placeholder.
    ///   - size: Edge length of the square, rim included and ledge not.
    ///   - style: See ``Style``.
    ///   - chosen: This level is the picked one. The rim turns olive at the
    ///     same 5 pt — nothing shifts — the ledge turns the darker olive, and
    ///     the check ``RewardSticker`` uses joins the corner: a colour *and* a
    ///     shape, so a child who tells no olive from sand still sees which one
    ///     is picked. Ignored by ``Style/mosaic``, which has no rim to turn.
    public init(photos: [Image?], size: CGFloat, style: Style = .tile, chosen: Bool = false) {
        self.photos = photos
        self.size = size
        self.style = style
        self.chosen = chosen
    }

    /// How many columns and cells the photos fill: one photo takes the whole
    /// square, every other count a two-by-two.
    public static func layout(photoCount: Int) -> (columns: Int, cells: Int) {
        photoCount == 1 ? (1, 1) : (2, 4)
    }

    private var metrics: PhotoQuartetMetrics {
        PhotoQuartetMetrics(style: style, size: size)
    }

    public var body: some View {
        Group {
            switch style {
            case .tile: tile
            case .mosaic: grid.frame(width: size, height: size)
            }
        }
        .accessibilityHidden(true)
    }

    private var tile: some View {
        let shape = RoundedRectangle(cornerRadius: metrics.radius, style: .continuous)

        return grid
            .frame(width: size, height: size)
            .background(shape.fill(ZColor.sand200))
            .overlay {
                shape.strokeBorder(chosen ? ZColor.primary : ZColor.sand400, lineWidth: metrics.rim)
            }
            .background(
                shape
                    .fill(chosen ? ZColor.primaryShadow : ZColor.sand400)
                    .offset(y: metrics.ledge),
            )
            .overlay(alignment: .bottomTrailing) {
                if chosen {
                    ChosenCheck(compact: size < PhotoQuartetMetrics.largeTile)
                }
            }
    }

    private var grid: some View {
        let layout = Self.layout(photoCount: photos.count)
        let side = size - 2 * metrics.inset
        let gutter = layout.columns == 1 ? 0 : metrics.gutter
        let cell = (side - gutter * CGFloat(layout.columns - 1)) / CGFloat(layout.columns)

        return VStack(spacing: gutter) {
            ForEach(0 ..< layout.cells / layout.columns, id: \.self) { row in
                HStack(spacing: gutter) {
                    ForEach(0 ..< layout.columns, id: \.self) { column in
                        let index = row * layout.columns + column
                        photo(
                            index < photos.count ? photos[index] : nil,
                            side: cell,
                            corners: corners(of: index, columns: layout.columns),
                        )
                    }
                }
            }
        }
    }

    /// The outer corner where a photo meets the square's edge, a small one
    /// where it meets another photo — and all four the same on a photo that
    /// fills the square alone.
    private func corners(of index: Int, columns: Int) -> UnevenRoundedRectangle {
        guard columns == 2 else {
            let solo = metrics.soloCorner
            return UnevenRoundedRectangle(
                topLeadingRadius: solo,
                bottomLeadingRadius: solo,
                bottomTrailingRadius: solo,
                topTrailingRadius: solo,
                style: .continuous,
            )
        }

        let outer = metrics.outerCorner
        let inner = metrics.innerCorner
        return UnevenRoundedRectangle(
            topLeadingRadius: index == 0 ? outer : inner,
            bottomLeadingRadius: index == 2 ? outer : inner,
            bottomTrailingRadius: index == 3 ? outer : inner,
            topTrailingRadius: index == 1 ? outer : inner,
            style: .continuous,
        )
    }

    private func photo(
        _ image: Image?,
        side: CGFloat,
        corners: UnevenRoundedRectangle,
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
            .clipShape(corners)
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
    private let compact: Bool

    /// - Parameter compact: The phone's 32 pt check rather than the iPad's
    ///   44 pt one.
    public init(compact: Bool) {
        self.compact = compact
    }

    public var body: some View {
        let check = PhotoQuartetMetrics.check(compact: compact)
        let colours = RewardStickerPalette.checked

        Icon(
            .check,
            size: .custom((check.diameter * RewardStickerMetrics.badgeGlyphRatio).rounded()),
        )
        .foregroundStyle(colours.foreground)
        .frame(width: check.diameter, height: check.diameter)
        .background(Circle().fill(colours.background))
        .overlay { Circle().strokeBorder(colours.edge, lineWidth: ZBorder.width) }
        .offset(x: check.overhang, y: check.overhang)
        // The control it sits on says "selected"; the check would say it twice.
        .accessibilityHidden(true)
    }
}

/// A quartet's numbers for one style at one size, in one place so the tests
/// can read them. The values without a token are the reviewed mockup's.
struct PhotoQuartetMetrics {
    /// From this edge length up a tile is the iPad's — radius 40, the 10 pt
    /// ledge, wider gutters. The phone's rung is about 96 pt, the iPad's 200.
    static let largeTile: CGFloat = 160

    /// The bird glyph in a cell without a photo, as a share of the cell.
    static let placeholderRatio: CGFloat = 0.45

    /// The corner of the square: the tile's own, or the mosaic's silhouette.
    let radius: CGFloat
    /// The tile's rim, zero for the mosaic.
    let rim: CGFloat
    /// The ledge under the tile, zero for the mosaic.
    let ledge: CGFloat
    /// From the square's outer edge to the photos: the rim and the sand
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
            let large = size >= Self.largeTile
            radius = large ? ZRadius.tile : ZRadius.large
            rim = ZBorder.widthThick
            ledge = large ? ZShadow.ledgeLargeOffset : ZShadow.ledgeOffset
            inset = rim + (large ? 10 : 5)
            gutter = large ? 6 : 4
            innerCorner = large ? 10 : 6
            soloCorner = radius - inset
        case .mosaic:
            // 20 keeps the corner photos 3 pt clear of the pill's inner curve;
            // 14 left less than one.
            radius = ZRadius.medium
            rim = 0
            ledge = 0
            inset = 0
            gutter = 2
            innerCorner = 3
            // At the mosaic's 20 a lone photo reads as a disc — a second
            // collection sticker beside the collection pill.
            soloCorner = 16
        }
    }

    /// The check of a chosen tile, and how far it hangs past the tile's
    /// corner: 44 pt and 9 pt on an iPad, 32 pt and 5 pt on a phone.
    static func check(compact: Bool) -> (diameter: CGFloat, overhang: CGFloat) {
        compact ? (32, 5) : (44, 9)
    }
}

#Preview("Tiles: one, four, missing, chosen") {
    VStack(spacing: ZSpacing.step7) {
        HStack(alignment: .top, spacing: ZSpacing.step5) {
            PhotoQuartet(photos: (0 ..< 4).map { _ in previewPhoto() }, size: 200)
            PhotoQuartet(photos: [previewPhoto(), nil, previewPhoto(), nil], size: 200)
            PhotoQuartet(photos: [previewPhoto()], size: 200)
            PhotoQuartet(photos: (0 ..< 4).map { _ in previewPhoto() }, size: 200, chosen: true)
        }
        HStack(alignment: .top, spacing: ZSpacing.step3) {
            PhotoQuartet(photos: (0 ..< 4).map { _ in previewPhoto() }, size: 96)
            PhotoQuartet(photos: [nil], size: 96)
            PhotoQuartet(photos: (0 ..< 4).map { _ in previewPhoto() }, size: 96, chosen: true)
        }
    }
    .padding(ZSpacing.step7)
    .background(ZColor.surfacePage)
}

#Preview("Mosaics") {
    HStack(spacing: ZSpacing.step5) {
        PhotoQuartet(photos: (0 ..< 4).map { _ in previewPhoto() }, size: 48, style: .mosaic)
        PhotoQuartet(photos: [previewPhoto()], size: 48, style: .mosaic)
        PhotoQuartet(photos: [nil, nil, nil, nil], size: 48, style: .mosaic)
        PhotoQuartet(photos: [previewPhoto()], size: 72, style: .mosaic)
    }
    .padding(ZSpacing.step7)
    .background(ZColor.surfaceCard)
}
