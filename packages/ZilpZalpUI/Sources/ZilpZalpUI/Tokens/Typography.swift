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
        /// Fixed size on purpose: `Font.custom(_:size:)` would scale the step
        /// with Dynamic Type, relative to `.body` and without a cap, so the
        /// 88 pt hero would render near 270 pt at AX5. The design's geometry
        /// is fixed — answer tiles are 220 pt with a 22 pt label, touch
        /// targets 64/96/160 — and the scale is already generous, with 20 pt
        /// the floor for anything a child reads. Adding Dynamic Type later
        /// means clamping it here, once, for the whole system.
        public func font(_ family: Family, weight: Weight) -> Font {
            .custom(TokenFontFace.postScriptName(family, weight), fixedSize: size)
        }

        /// Converts an em value from ``ZType/Tracking`` into the points that
        /// SwiftUI's `.tracking(_:)` expects.
        public func tracking(_ trackingEm: CGFloat) -> CGFloat {
            size * trackingEm
        }

        /// The value for SwiftUI's `.lineSpacing(_:)`, derived from the CSS
        /// line box: `size × (lineHeight − 1)`.
        ///
        /// - Note: An approximation. SwiftUI adds this on top of the font's
        ///   natural line height (roughly `1.2 × size`), not on top of the
        ///   point size, so the rendered line box comes out taller than the
        ///   CSS one. Fine for this generous scale; tune per component where
        ///   the difference shows.
        public var lineSpacing: CGFloat {
            size * (lineHeight - 1)
        }
    }
}

/// The bundled faces behind `--font-display` (Baloo 2) and `--font-body`
/// (Nunito), addressed by PostScript name.
///
/// Deliberately the only place in the token layer that spells out a font name.
/// PR #66 adds a `ZFont` namespace to this module with the same family/weight
/// vocabulary and the same PostScript names. Unifying the two once #66 lands
/// is three lines: make ``ZType/Family`` and ``ZType/Weight`` typealiases for
/// `ZFont.Family` and `ZFont.Weight` — the case names already match — and let
/// the body below call `ZFont.postScriptName(_:weight:)`.
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
