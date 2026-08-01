import Foundation
import SwiftUI

// Motion tokens from `design/tokens/motion.css`. CSS states milliseconds,
// SwiftUI wants seconds, so the durations below are the CSS values divided by
// a thousand.

/// The ZilpZalp motion tokens.
public enum ZMotion {
    // MARK: - Durations

    /// `--dur-instant: 90ms` — press feedback, nothing else.
    public static let instant: TimeInterval = 0.09
    /// `--dur-fast: 160ms`.
    public static let fast: TimeInterval = 0.16
    /// `--dur-normal: 260ms`.
    public static let normal: TimeInterval = 0.26
    /// `--dur-slow: 420ms`.
    public static let slow: TimeInterval = 0.42
    /// `--dur-celebrate: 900ms` — rewards and stickers.
    public static let celebrate: TimeInterval = 0.9

    /// Every duration, shortest first — for galleries and for the ordering
    /// test.
    public static let durations: [TimeInterval] = [instant, fast, normal, slow, celebrate]

    // MARK: - Easing

    /// A cubic Bézier timing curve, given as the two control points CSS's
    /// `cubic-bezier()` and SwiftUI's `Animation.timingCurve` both take.
    public struct Curve: Sendable, Hashable {
        public let p1x: Double
        public let p1y: Double
        public let p2x: Double
        public let p2y: Double

        /// The animation this curve describes, run over `duration`.
        public func animation(duration: TimeInterval) -> Animation {
            .timingCurve(p1x, p1y, p2x, p2y, duration: duration)
        }
    }

    /// `--ease-out: cubic-bezier(.22,.61,.36,1)`.
    public static let easeOut = Curve(p1x: 0.22, p1y: 0.61, p2x: 0.36, p2y: 1)
    /// `--ease-in-out: cubic-bezier(.45,.05,.55,.95)`.
    public static let easeInOut = Curve(p1x: 0.45, p1y: 0.05, p2x: 0.55, p2y: 0.95)
    /// `--ease-bounce: cubic-bezier(.34,1.56,.64,1)` — the default for
    /// anything appearing.
    public static let easeBounce = Curve(p1x: 0.34, p1y: 1.56, p2x: 0.64, p2y: 1)
    /// `--ease-squish: cubic-bezier(.5,-0.4,.5,1.4)`.
    public static let easeSquish = Curve(p1x: 0.5, p1y: -0.4, p2x: 0.5, p2y: 1.4)
}
