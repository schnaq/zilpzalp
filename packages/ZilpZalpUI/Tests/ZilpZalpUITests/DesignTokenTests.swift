import SwiftUI
import Testing
import ZilpZalpUI

// Structural invariants of the design tokens. These do not re-state every hex
// value from `design/tokens/*.css` — a reviewer diffs those against the doc
// comments. They guard the properties that a careless edit would break
// silently: completeness, ordering, and the two didactic feedback colours.

@Test("colors.css defines ten rubric colours and they are all different")
func rubricColoursAreTenAndDistinct() {
    #expect(ZColor.Rubric.allCases.count == 10)
    #expect(Set(ZColor.Rubric.allCases.map(\.color)).count == 10)
    #expect(Set(ZColor.Rubric.allCases.map(\.id)).count == 10)
}

@Test("Two tokens built from the same hex collapse into one colour")
func equalHexValuesCompareEqual() {
    // Control for the distinctness check above: `--white` and `--cream-50`
    // are both `#FFFCF3` but are built by two separate calls, so this proves
    // `Color` compares by value here rather than by identity.
    #expect(Set([ZColor.white, ZColor.cream50]).count == 1)
}

@Test("Feedback is olive for correct and sun for retry — never red")
func feedbackColoursStayFriendly() {
    #expect(ZColor.correct == ZColor.olive500)
    #expect(ZColor.correctSoft == ZColor.olive200)
    #expect(ZColor.retry == ZColor.sun400)
    #expect(ZColor.retrySoft == ZColor.sun100)
}

@Test("Motion durations grow strictly from instant to celebrate")
func motionDurationsAreStrictlyAscending() {
    #expect(ZMotion.durations.count == 5)
    #expect(isStrictlyAscending(ZMotion.durations))
    #expect(ZMotion.instant == 0.09)
    #expect(ZMotion.celebrate == 0.9)
}

@Test("Easing curves carry the CSS control points in order")
func easingCurvesMatchTheCSSControlPoints() {
    // One ordered comparison per curve, so a swap between the two control
    // points fails. Not a `Curve == Curve` comparison: the memberwise
    // initialiser of `ZMotion.Curve` is internal, so the expected value
    // cannot be built from outside the module.
    #expect(controlPoints(ZMotion.easeOut) == [0.22, 0.61, 0.36, 1])
    #expect(controlPoints(ZMotion.easeInOut) == [0.45, 0.05, 0.55, 0.95])
    #expect(controlPoints(ZMotion.easeBounce) == [0.34, 1.56, 0.64, 1])
    #expect(controlPoints(ZMotion.easeSquish) == [0.5, -0.4, 0.5, 1.4])
}

@Test("The type scale shrinks strictly from hero to caption")
func typeScaleIsStrictlyDescending() {
    let sizes = ZType.Step.allCases.map(\.size)

    #expect(sizes.count == 9)
    #expect(sizes.first == 88)
    #expect(sizes.last == 16)
    #expect(isStrictlyDescending(sizes))
}

@Test("Only the grown-up caption drops below the kid-facing floor of 20 pt")
func onlyTheCaptionIsSmallerThanTwentyPoints() {
    let kidFacing = ZType.Step.allCases.filter { $0 != .caption }

    #expect(kidFacing.allSatisfy { $0.size >= 20 })
    #expect(ZType.Step.caption.size == 16)
}

@Test("The four weights are the CSS numeric weights")
func weightsMatchTheCSSNumbers() {
    #expect(ZType.Weight.allCases.map(\.rawValue) == [400, 600, 700, 800])
}

@Test("Both typography entry points build the same fixed-size font")
func zFontAndTypeStepAgree() {
    // Fails as soon as one of them goes back to the Dynamic-Type-scaling
    // `Font.custom(_:size:)`.
    let viaZFont = ZFont.font(.display, weight: .bold, size: ZType.Step.body.size)
    let viaStep = ZType.Step.body.font(.display, weight: .bold)

    #expect(viaZFont == viaStep)
}

@Test("Tracking resolves from em to points, so it scales with the step size")
func trackingScalesWithTheStepSize() {
    let caps = ZType.Tracking.capsEm

    #expect(ZType.Step.hero.tracking(caps) > ZType.Step.caption.tracking(caps))
    #expect(ZType.Step.hero.tracking(caps) > caps)
    #expect(ZType.Step.hero.tracking(ZType.Tracking.tightEm) < 0)
    #expect(ZType.Step.body.tracking(ZType.Tracking.normalEm) == 0)
}

@Test("The spacing scale grows strictly from 4 to 128 pt")
func spacingScaleIsStrictlyAscending() {
    #expect(ZSpacing.scale.count == 10)
    #expect(ZSpacing.scale.first == 4)
    #expect(ZSpacing.scale.last == 128)
    #expect(isStrictlyAscending(ZSpacing.scale))
}

@Test("Touch targets never fall below 64 pt and grow strictly")
func touchTargetsRespectTheChildFloor() {
    let targets = [ZSpacing.touchMinimum, ZSpacing.touchComfortable, ZSpacing.touchHero]

    #expect(ZSpacing.touchMinimum == 64)
    #expect(targets.allSatisfy { $0 >= 64 })
    #expect(isStrictlyAscending(targets))
}

@Test("The radius scale grows strictly from 12 pt to the pill")
func radiusScaleIsStrictlyAscending() {
    #expect(ZRadius.scale == [12, 20, 28, 40, 56, 999])
    #expect(isStrictlyAscending(ZRadius.scale))
    #expect(ZRadius.card == ZRadius.large)
    #expect(ZRadius.tile == ZRadius.extraLarge)
    #expect(ZRadius.button == ZRadius.pill)
}

@Test("Both outline widths are chunky enough to read from arm's length")
func borderWidthsAreChunky() {
    #expect(ZBorder.width == 3)
    #expect(ZBorder.widthThick == 5)
}

@Test("Shadow geometry matches the CSS, with the ambient blur halved")
func shadowGeometryMatchesTheCSS() {
    // `--shadow-sm/md/lg: 0 {2,8,18}px {6,20,40}px` — CSS states a blur
    // diameter, SwiftUI a Gaussian radius.
    let ambient = [ZShadow.small, ZShadow.medium, ZShadow.large]

    #expect(ambient.map(\.radius) == [3, 10, 20])
    #expect(ambient.map(\.offsetY) == [2, 8, 18])
    #expect(ambient.allSatisfy { $0.offsetX == 0 })
    #expect(ZShadow.ledgeOffset == 6) // --ledge: 0 6px 0
    #expect(ZShadow.ledgeLargeOffset == 10) // --ledge-lg: 0 10px 0
    #expect(ZShadow.insetSoftOffset == -4) // --inset-soft: inset 0 -4px 0
    #expect(ZShadow.focusRingWidth == 5) // --ring-focus: 0 0 0 5px
}

private func controlPoints(_ curve: ZMotion.Curve) -> [Double] {
    [curve.p1x, curve.p1y, curve.p2x, curve.p2y]
}

private func isStrictlyAscending(_ values: [some Comparable]) -> Bool {
    zip(values, values.dropFirst()).allSatisfy { $0 < $1 }
}

private func isStrictlyDescending(_ values: [some Comparable]) -> Bool {
    zip(values, values.dropFirst()).allSatisfy { $0 > $1 }
}
