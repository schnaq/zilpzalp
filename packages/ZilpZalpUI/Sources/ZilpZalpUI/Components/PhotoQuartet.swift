import SwiftUI

/// One bird photo, or four in a two-by-two, on a toy-ledged square: the tile
/// that stands for a difficulty level in the picker.
///
/// A missing photo (`nil`) draws a bird glyph on the tone's field colour, so a
/// level never shows an empty hole. Not a control; the picker wraps it in its
/// own `Button` and labels it.
///
/// ``chosen`` turns the rim and the ledge olive and adds the check badge
/// ``RewardSticker`` uses — a colour and a shape, so a child who tells no olive
/// from sand still sees which one is picked. That is why no ``Tone`` is olive.
///
/// ```swift
/// PhotoQuartet(photos: [a, b, c, d], tone: .sun, size: 160, chosen: true)
/// ```
public struct PhotoQuartet: View {
    /// The four level tints. Never olive: olive means "chosen".
    public enum Tone: CaseIterable, Sendable {
        case sun
        case clay
        case bark
        case sand

        /// The field behind a missing photo, and the edge and ledge around the
        /// tile.
        var palette: (field: Color, edge: Color) {
            switch self {
            case .sun: (ZColor.sun200, ZColor.sun400)
            case .clay: (ZColor.clay100, ZColor.clay300)
            case .bark: (ZColor.bark100, ZColor.bark300)
            case .sand: (ZColor.sand200, ZColor.sand400)
            }
        }
    }

    private let photos: [Image?]
    private let tone: Tone
    private let size: CGFloat
    private let chosen: Bool

    /// - Parameters:
    ///   - photos: Already resolved by the app. One fills the square; any
    ///     other count lays out four cells, padding with the placeholder.
    ///   - tone: See ``Tone``.
    ///   - size: Edge length of the square, ledge not included.
    ///   - chosen: This level is the picked one.
    public init(photos: [Image?], tone: Tone, size: CGFloat, chosen: Bool = false) {
        self.photos = photos
        self.tone = tone
        self.size = size
        self.chosen = chosen
    }

    /// How many columns and cells the photos fill: one photo takes the whole
    /// square, every other count a two-by-two.
    public static func layout(photoCount: Int) -> (columns: Int, cells: Int) {
        photoCount == 1 ? (1, 1) : (2, 4)
    }

    private var edge: Color {
        chosen ? ZColor.primary : tone.palette.edge
    }

    private var ledge: Color {
        chosen ? ZColor.primaryShadow : tone.palette.edge
    }

    private var rim: CGFloat {
        chosen ? ZBorder.widthThick : ZBorder.width
    }

    public var body: some View {
        let shape = RoundedRectangle(
            cornerRadius: size * PhotoQuartetMetrics.radiusRatio,
            style: .continuous,
        )

        content(side: size - 2 * size * PhotoQuartetMetrics.paddingRatio)
            .frame(width: size, height: size)
            .background(shape.fill(ZColor.surfaceCard))
            .overlay { shape.strokeBorder(edge, lineWidth: rim) }
            .background(shape.fill(ledge).offset(y: ZShadow.ledgeOffset))
            .overlay(alignment: .topTrailing) { checkBadge }
            .accessibilityElement(children: .ignore)
    }

    private func content(side: CGFloat) -> some View {
        let grid = Self.layout(photoCount: photos.count)
        let gap = grid.columns == 1 ? 0 : size * PhotoQuartetMetrics.gapRatio
        let cell = (side - gap * CGFloat(grid.columns - 1)) / CGFloat(grid.columns)
        let radius = size * PhotoQuartetMetrics.innerRadiusRatio

        return VStack(spacing: gap) {
            ForEach(0 ..< grid.cells / grid.columns, id: \.self) { row in
                HStack(spacing: gap) {
                    ForEach(0 ..< grid.columns, id: \.self) { column in
                        let index = row * grid.columns + column
                        tile(index < photos.count ? photos[index] : nil, side: cell, radius: radius)
                    }
                }
            }
        }
    }

    private func tile(_ photo: Image?, side: CGFloat, radius: CGFloat) -> some View {
        Rectangle()
            .fill(tone.palette.field)
            .overlay {
                if let photo {
                    photo
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
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// The olive check of a chosen ``RewardSticker``, in the same corner.
    @ViewBuilder private var checkBadge: some View {
        if chosen {
            let diameter = (size * RewardStickerMetrics.badgeRatio).rounded()
            let colours = RewardStickerPalette.checked

            Icon(
                .check,
                size: .custom((diameter * RewardStickerMetrics.badgeGlyphRatio).rounded()),
            )
            .foregroundStyle(colours.foreground)
            .frame(width: diameter, height: diameter)
            .background(Circle().fill(colours.background))
            .overlay { Circle().strokeBorder(colours.edge, lineWidth: ZBorder.width) }
        }
    }
}

enum PhotoQuartetMetrics {
    static let radiusRatio: CGFloat = 0.2
    static let innerRadiusRatio: CGFloat = 0.11
    static let paddingRatio: CGFloat = 0.07
    static let gapRatio: CGFloat = 0.04
    /// The placeholder glyph inside one cell.
    static let placeholderRatio: CGFloat = 0.45
}

#Preview("One, four, missing, chosen") {
    HStack(alignment: .top, spacing: ZSpacing.step7) {
        PhotoQuartet(photos: [previewPhoto()], tone: .sun, size: 160)
        PhotoQuartet(photos: (0 ..< 4).map { _ in previewPhoto() }, tone: .clay, size: 160)
        PhotoQuartet(photos: [previewPhoto(), nil, previewPhoto(), nil], tone: .bark, size: 160)
        PhotoQuartet(photos: [nil], tone: .sand, size: 160)
        PhotoQuartet(
            photos: (0 ..< 4).map { _ in previewPhoto() },
            tone: .sun,
            size: 160,
            chosen: true,
        )
    }
    .padding(ZSpacing.step7)
    .background(ZColor.surfacePage)
}
