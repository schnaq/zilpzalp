import SwiftUI
import Testing
@testable import ZilpZalpUI

/// A line of grown-up copy, long enough that a point of growth would be
/// visible in the width it takes.
private let sample = "Danach schlafen die Vögel"

/// The width one line takes with nothing squeezing it — the only handle a
/// headless render has on the size a `Text` was actually drawn at, and the
/// reason it goes through ``looseSize(of:)`` rather than
/// ``renderedSize(_:width:)``: a frame is what a wider line would be measured
/// against instead of itself.
@MainActor
private func lineWidth(at typeSize: DynamicTypeSize, scaling: Bool) -> CGFloat {
    looseSize(
        of: Text(verbatim: sample)
            .typeStyle(.body, .body, weight: .bold)
            .environment(\.scalesTypeWithDynamicType, scaling)
            .dynamicTypeSize(typeSize),
    ).width
}

/// Dynamic Type on the grown-ups' screens, and nowhere else (#239).
///
/// **How far a headless render can follow this.** `@ScaledMetric` reads the
/// system's type metrics, and there are none in a `swift test` on macOS: the
/// same view renders at the same size at every ``DynamicTypeSize``. So what
/// the type *grows to* is a simulator question and the screenshots in the
/// pull request answer it — at the default, at xxxLarge, at AX1 and at AX5,
/// where the cap has to be the same picture as AX3.
///
/// What this suite holds is the half that is decidable here: that nothing
/// scales where the switch is off — the promise the child's screens rest on —
/// and the two pure rules beside it, which step follows which text style and
/// what a row does once the type is large.
@MainActor
@Suite("Grown-up Dynamic Type")
struct GrownUpTypeTests {
    // MARK: - The child's screens

    @Test("Type stays fixed wherever the switch is off", arguments: [
        DynamicTypeSize.xSmall,
        .large,
        .xxxLarge,
        .accessibility5,
    ])
    func typeStaysFixedWithoutTheSwitch(at typeSize: DynamicTypeSize) throws {
        try #require(BundledFonts.registered)

        let fixed = lineWidth(at: typeSize, scaling: false)
        let reference = lineWidth(at: .large, scaling: false)

        #expect(
            abs(fixed - reference) < 0.5,
            "\(typeSize) drew \(fixed) pt of line against \(reference) at the default",
        )
    }

    // MARK: - Which style a step follows

    @Test("The display steps follow a display style, not the body")
    func theDisplayStepsFollowADisplayStyle() {
        // The reason each step carries an anchor at all: `.body` grows 2.35×
        // by AX3 and `.largeTitle` 1.76×, so the gate's 36 pt question on
        // `.body` would land near 85 pt.
        for step in [ZType.Step.hero, .display1, .display2, .title] {
            #expect(step.dynamicTypeAnchor == .largeTitle, "\(step.id) follows .body")
        }
        #expect(ZType.Step.headline.dynamicTypeAnchor == .title2)
    }

    @Test("The grown-up caption follows a caption-sized style")
    func theCaptionFollowsASmallStyle() {
        #expect(ZType.Step.caption.dynamicTypeAnchor == .footnote)
        #expect(ZType.Step.body.dynamicTypeAnchor == .body)
        #expect(ZType.Step.label.dynamicTypeAnchor == .body)
        #expect(ZType.Step.bodyLarge.dynamicTypeAnchor == .body)
    }

    // MARK: - What the rows do about it

    @Test("An accessibility size stacks the row whatever the size class is")
    func anAccessibilitySizeStacksTheRow() {
        #expect(SettingRowLayout.choose(
            sizeClass: .regular,
            typeSize: .accessibility1,
            textWidth: 600,
            titleWidth: 200,
            trailingWidth: 120,
            spacing: ZSpacing.step4,
        ) == .rows)
    }

    @Test("Below it a regular width keeps the design's three columns")
    func belowItTheColumnsStand() {
        #expect(SettingRowLayout.choose(
            sizeClass: .regular,
            typeSize: .xxxLarge,
            textWidth: 600,
            titleWidth: 200,
            trailingWidth: 120,
            spacing: ZSpacing.step4,
        ) == .columns)
    }

    @Test("A wide title at an accessibility size takes the trailing line")
    func aWideTitleTakesTheTrailingLine() {
        #expect(SettingRowLayout.choose(
            sizeClass: .regular,
            typeSize: ZType.dynamicTypeCap,
            textWidth: 300,
            titleWidth: 260,
            trailingWidth: 120,
            spacing: ZSpacing.step4,
        ) == .rowsWithTrailingLine)
    }
}
