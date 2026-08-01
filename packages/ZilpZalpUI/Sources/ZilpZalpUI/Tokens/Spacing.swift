import SwiftUI

// Spacing, layout and touch tokens from `design/tokens/spacing.css`.
// CSS pixels are taken as points 1:1.

/// The ZilpZalp spacing tokens.
public enum ZSpacing {
    // MARK: - Scale

    // `--space-1` … `--space-10`. `step1` is `--space-1`, and so on.

    public static let step1: CGFloat = 4
    public static let step2: CGFloat = 8
    public static let step3: CGFloat = 12
    public static let step4: CGFloat = 16
    public static let step5: CGFloat = 24
    public static let step6: CGFloat = 32
    public static let step7: CGFloat = 48
    public static let step8: CGFloat = 64
    public static let step9: CGFloat = 96
    public static let step10: CGFloat = 128

    /// The scale, smallest first — for galleries and for the ordering test.
    public static let scale: [CGFloat] = [
        step1,
        step2,
        step3,
        step4,
        step5,
        step6,
        step7,
        step8,
        step9,
        step10,
    ]

    // MARK: - Layout

    /// `--gutter-screen: 48px` — the iPad safe margin.
    public static let gutterScreen: CGFloat = 48
    /// `--gap-tiles: 24px`.
    public static let gapTiles: CGFloat = 24
    /// `--max-content: 960px`.
    public static let maxContent: CGFloat = 960

    // MARK: - Touch targets

    // Sized for four-year-old fingers. Never smaller than ``touchMinimum``.

    /// `--touch-min: 64px` — the floor for anything tappable.
    public static let touchMinimum: CGFloat = 64
    /// `--touch-comfy: 96px`.
    public static let touchComfortable: CGFloat = 96
    /// `--touch-hero: 160px` — answer tiles and the big play button.
    public static let touchHero: CGFloat = 160
}
