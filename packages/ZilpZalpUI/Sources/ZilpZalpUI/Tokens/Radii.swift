import SwiftUI

// Corner radii and outline widths from `design/tokens/radii.css`. Both live in
// that one CSS file, so both live in this one Swift file — as two namespaces,
// because a border width is not a radius.

/// The ZilpZalp corner radii.
public enum ZRadius {
    /// `--radius-sm: 12px`.
    public static let small: CGFloat = 12
    /// `--radius-md: 20px`.
    public static let medium: CGFloat = 20
    /// `--radius-lg: 28px`.
    public static let large: CGFloat = 28
    /// `--radius-xl: 40px`.
    public static let extraLarge: CGFloat = 40
    /// `--radius-2xl: 56px`.
    public static let extraExtraLarge: CGFloat = 56
    /// `--radius-pill: 999px` — clamp to half the height for a true pill.
    public static let pill: CGFloat = 999

    /// `--radius-card` → `--radius-lg`.
    public static let card = large
    /// `--radius-tile` → `--radius-xl`.
    public static let tile = extraLarge
    /// `--radius-button` → `--radius-pill`.
    public static let button = pill

    /// The named radii, smallest first — for galleries and for the ordering
    /// test. The three aliases above are omitted; they repeat these values.
    public static let scale: [CGFloat] = [small, medium, large, extraLarge, extraExtraLarge, pill]
}

/// The ZilpZalp outline widths, from `design/tokens/radii.css`.
public enum ZBorder {
    /// `--border-width: 3px` — the chunky default outline.
    public static let width: CGFloat = 3
    /// `--border-width-thick: 5px` — answer tiles and other big surfaces.
    public static let widthThick: CGFloat = 5
}
