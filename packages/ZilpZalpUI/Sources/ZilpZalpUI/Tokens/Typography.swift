import SwiftUI

// Type tokens from `design/tokens/typography.css`.
//
// The scale is kid-facing: nothing a child reads goes below 20 pt, and
// ``ZType/Step/caption`` (16 pt) is reserved for the grown-up area. CSS pixels
// are taken as points 1:1 — both are the design's logical unit.

/// The ZilpZalp type tokens.
public enum ZType {
    /// The two families, `--font-display` and `--font-body`.
    public enum Family: Sendable, Hashable, CaseIterable {
        /// `--font-display: "Baloo 2"` — headings and every interactive label.
        case display
        /// `--font-body: "Nunito"` — body copy and the grown-up area.
        case body

        /// The line box the bundled face itself asks for, as a multiple of
        /// the point size.
        ///
        /// Read from the `hhea` table of the two variable fonts under
        /// `apps/ZilpZalp/Resources/Fonts` — `(ascender − descender +
        /// lineGap) ÷ unitsPerEm`:
        ///
        /// | Face | ascender | descender | lineGap | unitsPerEm | natural |
        /// |---|---|---|---|---|---|
        /// | Baloo 2 | 1078 | −524 | 0 | 1000 | 1.602 |
        /// | Nunito | 1011 | −353 | 0 | 1000 | 1.364 |
        ///
        /// Both fonts set `USE_TYPO_METRICS` and carry the same values in
        /// `OS/2`, so every renderer agrees. Neither ships an `MVAR` table,
        /// so the numbers hold for all named instances of the weight axis —
        /// one constant per family is enough.
        ///
        /// This is the floor SwiftUI cannot go below. A browser shrinks the
        /// line box to `line-height`; SwiftUI lays every line out in the
        /// face's own box and `.lineSpacing(_:)` only ever adds to it. Baloo
        /// 2 is the reason the difference is visible: at 1.602 its box is
        /// half again as tall as the 1.0–1.2 the display roles ask for.
        public var naturalLineHeight: CGFloat {
            switch self {
            case .display: 1.602
            case .body: 1.364
            }
        }
    }

    /// The four weights the design uses, `--weight-regular` through
    /// `--weight-black`. The raw value is the CSS numeric weight.
    public enum Weight: Int, Sendable, Hashable, CaseIterable {
        /// `--weight-regular: 400`.
        case regular = 400
        /// `--weight-semibold: 600`.
        case semibold = 600
        /// `--weight-bold: 700`.
        case bold = 700
        /// `--weight-black: 800`. Spelled `extraBold`, not `black`: 800 is
        /// the ExtraBold instance of both families, and Nunito separately
        /// ships a real Black at 900. Matches `ZFont.Weight` from #66.
        case extraBold = 800
    }

    /// Letter spacing, `--tracking-*`.
    ///
    /// The CSS values are in `em`, so they depend on the type size. Resolve
    /// them through ``ZType/Step/tracking(_:)`` before handing them to
    /// SwiftUI's `.tracking(_:)`, which takes points.
    public enum Tracking {
        /// `--tracking-tight: -0.01em`.
        public static let tightEm: CGFloat = -0.01
        /// `--tracking-normal: 0`.
        public static let normalEm: CGFloat = 0
        /// `--tracking-loose: 0.02em`.
        public static let looseEm: CGFloat = 0.02
        /// `--tracking-caps: 0.08em`.
        public static let capsEm: CGFloat = 0.08
    }

    /// One step of the type scale: a `--text-*` size with its `--lh-*` line
    /// height. Weight and family are chosen per use, exactly as in CSS.
    public struct Step: Sendable, Hashable, Identifiable, CaseIterable {
        /// The token name without the `--text-` prefix, e.g. `display-1`.
        public let id: String
        /// `--text-…` in points.
        public let size: CGFloat
        /// `--lh-…` as a multiple of ``size``.
        public let lineHeight: CGFloat

        /// `--text-hero: 88px` / `--lh-hero: 1.0`.
        public static let hero = Step(id: "hero", size: 88, lineHeight: 1.0)
        /// `--text-display-1: 64px` / `--lh-display-1: 1.05`.
        public static let display1 = Step(id: "display-1", size: 64, lineHeight: 1.05)
        /// `--text-display-2: 48px` / `--lh-display-2: 1.1`.
        public static let display2 = Step(id: "display-2", size: 48, lineHeight: 1.1)
        /// `--text-title: 36px` / `--lh-title: 1.15`.
        public static let title = Step(id: "title", size: 36, lineHeight: 1.15)
        /// `--text-headline: 28px` / `--lh-headline: 1.2`.
        public static let headline = Step(id: "headline", size: 28, lineHeight: 1.2)
        /// `--text-body-lg: 24px` / `--lh-body-lg: 1.45`.
        public static let bodyLarge = Step(id: "body-lg", size: 24, lineHeight: 1.45)
        /// `--text-label: 22px` / `--lh-label: 1.1` — button and tile labels.
        public static let label = Step(id: "label", size: 22, lineHeight: 1.1)
        /// `--text-body: 20px` / `--lh-body: 1.5` — the smallest kid-facing size.
        public static let body = Step(id: "body", size: 20, lineHeight: 1.5)
        /// `--text-caption: 16px` / `--lh-caption: 1.4` — GROWN-UP AREA ONLY.
        public static let caption = Step(id: "caption", size: 16, lineHeight: 1.4)

        /// Every step, largest first.
        ///
        /// Sorted by size rather than by CSS declaration order — the only
        /// difference is `label` (22 pt), which `typography.css` declares
        /// after `body` (20 pt) because it groups labels with body copy.
        public static let allCases: [Step] = [
            hero,
            display1,
            display2,
            title,
            headline,
            bodyLarge,
            label,
            body,
            caption,
        ]

        /// The font for this step in `family` at `weight`.
        ///
        /// The raw face. Components reach for
        /// `View.typeStyle(_:_:weight:tracking:singleLine:)` instead, which
        /// adds the tracking and the line spacing that belong with it.
        ///
        /// Fixed size on purpose: `Font.custom(_:size:)` would scale the step
        /// with Dynamic Type, relative to `.body` and without a cap, so the
        /// 88 pt hero would render near 270 pt at AX5. The design's geometry
        /// is fixed — answer tiles are 220 pt with a 22 pt label, touch
        /// targets 64/96/160 — and the scale is already generous, with 20 pt
        /// the floor for anything a child reads.
        ///
        /// The grown-ups' screens do follow Dynamic Type, and they do it by
        /// resolving a step at the size the system asks for and handing
        /// *that* step here — see ``SwiftUI/View/grownUpDynamicType()``. The
        /// face stays fixed either way; nothing in this type scales itself.
        public func font(_ family: Family, weight: Weight) -> Font {
            .custom(TokenFontFace.postScriptName(family, weight), fixedSize: size)
        }

        /// The system text style this step follows where Dynamic Type is let
        /// in — the `relativeTo:` of `@ScaledMetric`.
        ///
        /// Not `.body` for all nine. `UIFontMetrics` scales the small styles
        /// hardest, by design: at AX3 `.body` takes 17 pt to 40 (2.35×) while
        /// `.largeTitle` takes 34 to 60 (1.76×). Anchored to `.body`
        /// throughout, the gate's 36 pt question would land near 85 pt and no
        /// phone would hold it. Each step follows the style of its own rank
        /// instead, so the scale keeps its shape as it grows.
        var dynamicTypeAnchor: Font.TextStyle {
            switch self {
            case .hero, .display1, .display2, .title: .largeTitle
            case .headline: .title2
            case .caption: .footnote
            default: .body
            }
        }

        /// Converts an em value from ``ZType/Tracking`` into the points that
        /// SwiftUI's `.tracking(_:)` expects.
        public func tracking(_ trackingEm: CGFloat) -> CGFloat {
            size * trackingEm
        }

        /// The box the design asks for: `size × lineHeight`, the CSS line
        /// box. No face enters into it — that is
        /// ``naturalBoxHeight(for:)``, and the gap between the two is the
        /// whole problem this type solves.
        public var lineBoxHeight: CGFloat {
            size * lineHeight
        }

        /// The box the bundled face lays a line out in: `size ×`
        /// ``ZType/Family/naturalLineHeight``.
        public func naturalBoxHeight(for family: Family) -> CGFloat {
            size * family.naturalLineHeight
        }

        /// The value for SwiftUI's `.lineSpacing(_:)` — the distance still
        /// missing between two lines once the face's own box is counted.
        ///
        /// SwiftUI adds `.lineSpacing(_:)` on top of the natural box rather
        /// than on top of the point size, so the CSS `size × (lineHeight −
        /// 1)` overshot every role. Subtracting the natural box lands the
        /// line pitch exactly on the CSS one wherever the face is small
        /// enough to allow it: Nunito's 1.364 leaves body 20 pt a 2.7 pt
        /// correction, caption 16 pt 0.6 pt, body-lg 24 pt 2.1 pt.
        ///
        /// Every Baloo 2 role clamps to zero. Its 1.602 box is already
        /// taller than the 1.0–1.2 the display roles ask for, and nothing in
        /// SwiftUI shrinks a line box. For a single line the fix is
        /// ``lineBoxHeight`` as an explicit frame — see
        /// `View.typeStyle(_:_:weight:tracking:singleLine:)`.
        public func lineSpacing(for family: Family) -> CGFloat {
            max(0, lineBoxHeight - naturalBoxHeight(for: family))
        }
    }
}

public extension View {
    /// Sets one step of the type scale: the face, the tracking and the line
    /// spacing that belong together.
    ///
    /// The one place components reach for type. Applying the three
    /// separately is how they drifted apart, and `.lineSpacing(_:)` in
    /// particular is only correct once the face's own line box is subtracted
    /// — see ``ZType/Step/lineSpacing(for:)``.
    ///
    /// Works on a `Text` and equally on a container: SwiftUI carries font,
    /// tracking and line spacing down through the environment.
    ///
    /// Fixed size unless the subtree asked for Dynamic Type through
    /// ``SwiftUI/View/grownUpDynamicType()``, which the grown-ups' screens do
    /// and no screen a child sees does. Where it is on, the step is resolved
    /// at the scaled size first and everything below it — tracking, line
    /// spacing, the single-line box — follows from that one number.
    ///
    /// - Parameters:
    ///   - step: The size and line height, from ``ZType/Step``.
    ///   - family: Display or body. Also picks the natural line box.
    ///   - weight: One of the four shipped weights.
    ///   - tracking: An em value from ``ZType/Tracking``, resolved to points
    ///     against ``ZType/Step/size``.
    ///   - singleLine: For a label that is one line by design — a button, a
    ///     badge, a row title. It stops the text wrapping and gives it the
    ///     design's box instead of the face's, which is the only way a Baloo
    ///     2 label occupies the 24 pt the design draws rather than 35 pt.
    ///     The glyphs overhang that frame, exactly as they overhang a CSS
    ///     line box tighter than 1 em; SwiftUI does not clip without
    ///     `.clipped()`, so they stay whole. Leave it off for anything that
    ///     may wrap.
    ///
    ///     **Not on its own under a `minimumScaleFactor`.** A scale factor
    ///     shrinks to fit the whole proposal, and the design's box is tighter
    ///     than the face's, so the pair alone draws the label a step or more
    ///     below the one it was given — 18 pt for a 28 pt headline. A
    ///     `.fixedSize(horizontal: false, vertical: true)` between the two
    ///     sizes the text against its own box first; ``TopBarTitle`` and
    ///     `HomeTile`'s label do it that way since #229, and the screens that
    ///     still pair the two without it are a fix of their own.
    ///
    /// Left off, the modifier touches neither the line limit nor the height:
    /// `.lineLimit(nil)` would clear a limit an ancestor had set, so a caller
    /// wrapping a card in `.lineLimit(2)` would silently lose it.
    func typeStyle(
        _ step: ZType.Step,
        _ family: ZType.Family,
        weight: ZType.Weight,
        tracking: CGFloat = ZType.Tracking.normalEm,
        singleLine: Bool = false,
    ) -> some View {
        modifier(TypeStyle(spec: TypeSpec(
            step: step,
            family: family,
            weight: weight,
            trackingEm: tracking,
            singleLine: singleLine,
        )))
    }
}

/// The bundled faces behind `--font-display` (Baloo 2) and `--font-body`
/// (Nunito), addressed by PostScript name.
///
/// Deliberately the only place in the token layer that spells out a font name.
/// ``ZFont`` carries the same family/weight vocabulary and the same PostScript
/// names, and the case names already match. Unifying the two is still more
/// than a typealias: ``ZType/Weight`` is `Int`-backed and `CaseIterable`,
/// ``ZFont/Weight`` is neither, so it would have to grow both — plus the call
/// sites and tests that go with it. A refactor of its own, not a drive-by.
private enum TokenFontFace {
    static func postScriptName(_ family: ZType.Family, _ weight: ZType.Weight) -> String {
        let familyName = switch family {
        case .display: "Baloo2"
        case .body: "Nunito"
        }
        let weightName = switch weight {
        case .regular: "Regular"
        case .semibold: "SemiBold"
        case .bold: "Bold"
        case .extraBold: "ExtraBold"
        }
        return "\(familyName)-\(weightName)"
    }
}
