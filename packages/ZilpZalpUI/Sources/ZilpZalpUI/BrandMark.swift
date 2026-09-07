import SwiftUI

/// The drawn ZilpZalp mark: a hoopoe with a raised crest in front of an open
/// olive ring.
///
/// The artwork is `assets/logo.svg`, vendored into `Resources/Brand.xcassets`
/// with its vector representation preserved so it stays sharp at every size.
/// Deliberately *not* a template image, unlike ``Icon``: the mark carries four
/// brand colours plus the crest's orange gradient, and template rendering would
/// flatten all of them into a single tint.
public struct BrandMark: View {
    /// The imageset in `Brand.xcassets` holding the artwork. Shared with the
    /// test that checks the catalog is complete.
    nonisolated static let assetName = "BrandMark"

    private let size: CGFloat
    private let accessibilityLabel: String

    /// - Parameters:
    ///   - size: Edge length in points. The artwork is square and centred in
    ///     it, with about a tenth of the frame left as margin on each side.
    ///   - accessibilityLabel: What VoiceOver announces. ``ZBrand/name`` by
    ///     default; callers showing the mark as decoration next to a label of
    ///     their own hide it with `.accessibilityHidden(true)` instead.
    public init(size: CGFloat, accessibilityLabel: String = ZBrand.name) {
        self.size = size
        self.accessibilityLabel = accessibilityLabel
    }

    public var body: some View {
        Image(Self.assetName, bundle: .module)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: size, height: size)
            .accessibilityLabel(accessibilityLabel)
    }
}

// Both grounds in one canvas, because the mark keeps its own colours on either
// one: on the forest ground its olive ring sits close to `--surface-forest`,
// and the design has not said how the mark should behave on a dark ground.
#Preview("Brand mark") {
    VStack(spacing: 0) {
        ForEach([ZColor.surfacePage, ZColor.surfaceForest], id: \.self) { ground in
            HStack(alignment: .bottom, spacing: ZSpacing.step5) {
                BrandMark(size: 44)
                BrandMark(size: 96)
                BrandMark(size: 160)
            }
            .frame(maxWidth: .infinity)
            .padding(ZSpacing.step6)
            .background(ground)
        }
    }
}
