import SwiftUI

/// Encapsulates the family and weight of the bundled Baloo 2 and Nunito
/// fonts so components never scatter font-name string literals.
///
/// Both fonts are registered from the app bundle via `UIAppFonts`
/// (`apps/ZilpZalp/project.yml`) as variable fonts. The weights below
/// address their named instances by PostScript name — confirmed on-device
/// to resolve to the real font rather than silently falling back to the
/// system font.
public enum ZFont {
    /// The two type families used across ZilpZalp.
    public enum Family: Sendable {
        /// Baloo 2 — headings and every interactive label.
        case display
        /// Nunito — body copy and the grown-up area.
        case body
    }

    /// The weights shipped with the app, matching
    /// `design/tokens/typography.css` (400/600/700/800).
    public enum Weight: Sendable {
        case regular
        case semibold
        case bold
        case extraBold
    }

    /// The SwiftUI font for the given family, weight and point size.
    ///
    /// Fixed size, no Dynamic Type scaling — the same decision and the same
    /// rationale as ``ZType/Step/font(_:weight:)``, so both typography entry
    /// points render a given point size identically.
    ///
    /// Components take their sizes from the type scale and set type through
    /// `View.typeStyle(_:_:weight:tracking:singleLine:)`, which also carries
    /// the tracking and the line spacing. This entry point is for a size the
    /// scale does not have.
    public static func font(_ family: Family, weight: Weight, size: CGFloat) -> Font {
        .custom(postScriptName(family, weight: weight), fixedSize: size)
    }

    /// The PostScript name of the named instance backing `family`/`weight`.
    public static func postScriptName(_ family: Family, weight: Weight) -> String {
        switch (family, weight) {
        case (.display, .regular):
            "Baloo2-Regular"
        case (.display, .semibold):
            "Baloo2-SemiBold"
        case (.display, .bold):
            "Baloo2-Bold"
        case (.display, .extraBold):
            "Baloo2-ExtraBold"
        case (.body, .regular):
            "Nunito-Regular"
        case (.body, .semibold):
            "Nunito-SemiBold"
        case (.body, .bold):
            "Nunito-Bold"
        case (.body, .extraBold):
            "Nunito-ExtraBold"
        }
    }
}
