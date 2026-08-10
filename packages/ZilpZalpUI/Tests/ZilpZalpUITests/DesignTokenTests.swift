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

private func isStrictlyAscending(_ values: [some Comparable]) -> Bool {
    zip(values, values.dropFirst()).allSatisfy { $0 < $1 }
}

private func isStrictlyDescending(_ values: [some Comparable]) -> Bool {
    zip(values, values.dropFirst()).allSatisfy { $0 > $1 }
}
