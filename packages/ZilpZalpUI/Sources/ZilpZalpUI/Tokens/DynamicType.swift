import SwiftUI

// How far the type scale follows the system's text size — the grown-ups'
// screens all the way to ``ZType/dynamicTypeCap``, the child's screens not at
// all. `View.typeStyle(_:_:weight:tracking:singleLine:)` in `Typography.swift`
// is the one caller.

public extension View {
    /// Lets the type in this subtree follow the system's text size, capped at
    /// ``ZType/dynamicTypeCap``.
    ///
    /// The grown-ups' surface and nothing else: the settings, the screen
    /// about the app, the credits, the parental gate. Dynamic Type stays
    /// fixed everywhere a child looks, because that geometry cannot scale —
    /// 220 pt answer tiles, 64/96/160 pt touch targets, a scale whose floor
    /// is already 20 pt (spec decision 2026-09-07). None of it is on these
    /// four screens, which are prose and rows in a scroll view, read by the
    /// people most likely to have turned the system text up (2026-09-11,
    /// #239).
    ///
    /// Applied to a screen's content rather than to the whole screen, so the
    /// ``TopBar`` above it keeps the fixed 60 pt bar #93 and #232 measured. A
    /// title there answers to the width left by two 64 pt buttons and already
    /// shrinks to fit it; scaling it would buy height and no legibility. The
    /// other fixed shape is ``ZButton``, which stands inside this subtree and
    /// opts out where it is built.
    ///
    /// It never shrinks. Below the system's default the metrics run down to
    /// 0.82×, which would take the caption step under the 16 pt the type
    /// scale calls its floor — so every size up to `.large` renders exactly
    /// as it does today and this switch is purely additive.
    func grownUpDynamicType() -> some View {
        environment(\.scalesTypeWithDynamicType, true)
            .dynamicTypeSize(...ZType.dynamicTypeCap)
    }
}

public extension ZType {
    /// How far the grown-ups' screens follow the system text size.
    ///
    /// AX3 is where their rows still lay out. Measured at the cap on an
    /// iPhone 17 Pro Max, the time budget's row is the stacked
    /// ``SettingRowLayout``: its title over two lines, its hint over three,
    /// and „Kein Limit" on a line of its own along the trailing edge — tall,
    /// but whole, and the screens scroll. Above the cap the type keeps
    /// growing while the screen does not, so the two larger sizes buy a
    /// little type for a lot of scrolling.
    static let dynamicTypeCap: DynamicTypeSize = .accessibility3
}

extension EnvironmentValues {
    /// Whether ``SwiftUI/View/typeStyle(_:_:weight:tracking:singleLine:)``
    /// resolves its step against the system text size in this subtree.
    ///
    /// Off everywhere but under ``SwiftUI/View/grownUpDynamicType()``.
    @Entry var scalesTypeWithDynamicType: Bool = false
}

extension ZType.Step {
    /// This step at the size the system asked for — never below the design's
    /// own.
    ///
    /// The `max` is what leaves every text size up to `.large` exactly as it
    /// is today: below the default the metrics run down to 0.82×, which would
    /// take the caption step under the 16 pt the scale calls its floor. The
    /// arithmetic is here rather than inside ``ScaledTypeStyle`` so that it
    /// can be tested without a `@ScaledMetric`, which does not scale under a
    /// headless `swift test`.
    func scaled(to scaledSize: CGFloat) -> Self {
        Self(id: id, size: max(size, scaledSize), lineHeight: lineHeight)
    }
}

/// What one call to `typeStyle` asked for, and how it reaches a view once the
/// step is settled.
///
/// The one place the face, the tracking, the line spacing and the single-line
/// box are applied, whichever of the two modifiers below chose the step.
struct TypeSpec {
    let step: ZType.Step
    let family: ZType.Family
    let weight: ZType.Weight
    let trackingEm: CGFloat
    let singleLine: Bool

    @MainActor
    @ViewBuilder
    func applied(to content: some View, at step: ZType.Step) -> some View {
        let styled = content
            .font(step.font(family, weight: weight))
            .tracking(step.tracking(trackingEm))
            .lineSpacing(step.lineSpacing(for: family))

        if singleLine {
            styled
                .lineLimit(1)
                .frame(height: step.lineBoxHeight)
        } else {
            styled
        }
    }
}

/// The switch between the design's fixed size and the scaled one.
///
/// The scaled branch needs `@ScaledMetric`, and a property wrapper needs
/// somewhere to live. It lives one level down, in ``ScaledTypeStyle``: a
/// `@ScaledMetric` subscribes its node to the system text size, and the
/// child's screens have no business being re-laid-out by a setting they do
/// not follow. So the branch is taken here, on an `@Environment` read of a
/// value that never changes outside the grown-ups' screens, and every text a
/// child sees keeps exactly the three modifiers it had.
struct TypeStyle: ViewModifier {
    let spec: TypeSpec

    @Environment(\.scalesTypeWithDynamicType) private var scales

    func body(content: Content) -> some View {
        if scales {
            content.modifier(ScaledTypeStyle(spec: spec))
        } else {
            spec.applied(to: content, at: spec.step)
        }
    }
}

/// The same step, resolved against the system text size first.
///
/// What is scaled is the step's *size*; the resolved step then answers for
/// the tracking, the line spacing and the single-line box, so those cannot
/// disagree about the size they were computed at.
///
/// The step reaches `@ScaledMetric` as its initial value, so a call site that
/// handed the same tree position two different steps across a re-render would
/// be relying on how that wrapper treats a second initialisation. No call
/// site does — every `typeStyle` in the grown-ups' screens names a literal
/// step — and one that wanted to would be the day to measure it.
private struct ScaledTypeStyle: ViewModifier {
    let spec: TypeSpec

    @ScaledMetric private var scaledSize: CGFloat

    init(spec: TypeSpec) {
        self.spec = spec
        _scaledSize = ScaledMetric(
            wrappedValue: spec.step.size,
            relativeTo: spec.step.dynamicTypeAnchor,
        )
    }

    func body(content: Content) -> some View {
        spec.applied(to: content, at: spec.step.scaled(to: scaledSize))
    }
}
