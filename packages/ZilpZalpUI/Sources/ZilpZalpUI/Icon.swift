import SwiftUI

/// Renders one vendored icon glyph as a template image, sized for its
/// context rather than to an arbitrary pixel value.
///
/// Icons are decorative on their own — a kid-facing control always pairs a
/// glyph with a word, a photo, or an accessibility label owned by the
/// surrounding component (a `Button`, an `IconButton`...), never with the
/// icon itself. `Icon` reflects that by hiding itself from accessibility;
/// callers that need a label attach it to the control they build, not here.
public struct Icon: View {
    /// Point size for the glyph. The presets cover the range actually used
    /// across the design — inline with text or in compact rows (`.small`),
    /// `Icon`'s own default (`.standard`), and inside the larger buttons
    /// (`.large`) — so most call sites never need `.custom`.
    public enum Size: Sendable, Equatable {
        case small
        case standard
        case large
        case custom(CGFloat)

        var points: CGFloat {
            switch self {
            case .small: 24
            case .standard: 32
            case .large: 44
            case let .custom(value): value
            }
        }
    }

    private let icon: ZIcon
    private let size: Size

    public init(_ icon: ZIcon, size: Size = .standard) {
        self.icon = icon
        self.size = size
    }

    public var body: some View {
        Image(icon.rawValue, bundle: .module)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size.points, height: size.points)
            .accessibilityHidden(true)
    }
}

#Preview("All icons") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))], spacing: 16) {
            ForEach(ZIcon.allCases, id: \.self) { icon in
                VStack(spacing: 6) {
                    Icon(icon, size: .large)
                    Text(icon.rawValue)
                        .font(.caption2)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
            }
        }
        .padding()
    }
}

#Preview("Sizes") {
    HStack(alignment: .bottom, spacing: 16) {
        Icon(.volume2, size: .small)
        Icon(.volume2, size: .standard)
        Icon(.volume2, size: .large)
        Icon(.volume2, size: .custom(64))
    }
    .padding()
}
