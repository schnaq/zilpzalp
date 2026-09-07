import Testing
@testable import ZilpZalpUI

// The base components carry no logic worth testing beyond their token
// mapping, and rendering is not tested here — that is what the previews are
// for. What these tests guard are the rules a careless edit would break
// silently: the ledge is always the tone's own dark shade, no touch target
// ever drops below 64 pt, and every tint keeps enough contrast to be seen.
//
// Two of the task's requirements need no test because the compiler already
// enforces them: `IconButton.init` has no default for `label`, so a wordless
// button without a VoiceOver name does not compile, and `Badge` is a plain
// `View` with no action parameter, so it cannot be tapped.

@Test("Every ledge on either pressable is the tone's own dark shade")
func ledgesAreTheDarkShadeOfTheirTone() {
    #expect(ZButton.Tone.primary.palette.ledge == ZColor.olive700)
    #expect(ZButton.Tone.accent.palette.ledge == ZColor.orange700)
    // Sun yellow has no 700 shade in `colors.css`; 600 is its darkest.
    #expect(ZButton.Tone.reward.palette.ledge == ZColor.sun600)
    #expect(ZButton.Tone.quiet.palette.ledge == ZColor.sand300)
    // `clay` is the one tone only the icon button has.
    #expect(IconButton.Tone.clay.palette.ledge == ZColor.clay700)
}

@Test("The four button tones are told apart by face and ledge alike")
func buttonTonesAreDistinct() {
    let palettes = ZButton.Tone.allCases.map(\.palette)

    #expect(Set(palettes.map(\.face)).count == 4)
    #expect(Set(palettes.map(\.ledge)).count == 4)
    #expect(palettes.allSatisfy { $0.face != $0.ledge })
}

@Test("Pressing changes the face colour, not just the position")
func pressedFaceDiffersFromTheRestingFace() {
    #expect(ZButton.Tone.allCases.allSatisfy { $0.palette.face != $0.palette.pressedFace })
    #expect(IconButton.Tone.allCases.allSatisfy { $0.palette.face != $0.palette.pressedFace })
}

@Test("Only the quiet tone is outlined — it is the only one on cream")
func quietIsTheOnlyOutlinedTone() {
    #expect(ZButton.Tone.allCases.filter(\.palette.isOutlined) == [.quiet])
    #expect(IconButton.Tone.allCases.filter(\.palette.isOutlined) == [.quiet])
}

@Test("Sun yellow carries dark ink, the coloured tones carry cream")
func labelColoursFollowTheirBackground() {
    #expect(ZButton.Tone.reward.palette.foreground == ZColor.textOnReward)
    #expect(ZButton.Tone.primary.palette.foreground == ZColor.textOnColor)
    #expect(ZButton.Tone.quiet.palette.foreground == ZColor.textStrong)
}

@Test("Button heights are 64 / 96 / 120 and never below the touch minimum")
func buttonHeightsGrowFromTheTouchMinimum() {
    let heights = ZButton.Size.allCases.map(\.height)

    #expect(heights == [64, 96, 120])
    #expect(heights.allSatisfy { $0 >= ZSpacing.touchMinimum })
    #expect(ZButton.Size.medium.height == ZSpacing.touchMinimum)
    #expect(ZButton.Size.large.height == ZSpacing.touchComfortable)
}

@Test("Bigger buttons get bigger padding, type and glyphs")
func buttonSizesScaleTogether() {
    let sizes = ZButton.Size.allCases

    #expect(sizes.map(\.horizontalPadding) == [ZSpacing.step5, ZSpacing.step6, ZSpacing.step7])
    #expect(sizes.map(\.step) == [.label, .headline, .title])
    #expect(sizes.map(\.glyph) == [.small, .standard, .large])
    // The label of every size stays at or above the kid-facing 20 pt floor.
    #expect(sizes.allSatisfy { $0.step.size >= ZType.Step.body.size })
}

@Test("Ledge depths come from the two shadow tokens and outlast the press")
func ledgeDepthsAreTokensDeeperThanTheTravel() {
    #expect(ZButton.Size.medium.ledgeDepth == ZShadow.ledgeOffset)
    #expect(ZButton.Size.large.ledgeDepth == ZShadow.ledgeLargeOffset)
    #expect(ZButton.Size.extraLarge.ledgeDepth == ZShadow.ledgeLargeOffset)
    // 4 pt down in 90 ms, and the ledge is never fully swallowed by it. Pinned
    // to the literal from #10, not to `ZSpacing.step1` — `travel` is defined as
    // that token, so comparing the two could never fail.
    #expect(LedgeButtonStyle.travel == 4)
    #expect(ZButton.Size.allCases.allSatisfy { $0.ledgeDepth > LedgeButtonStyle.travel })
}

/// `@MainActor` because `View` carries that isolation and this is the one test
/// that builds a component rather than reading a mapping off its type.
@MainActor
@Test("An icon button can be asked for less than 64 pt but never drawn smaller")
func iconButtonDiameterIsClampedToTheTouchMinimum() {
    // The design's own screens ask for 56, 64, 72 and 96 — a continuum, so the
    // diameter is a number and not a step scale. Only the floor is fixed.
    // `touchMinimum - 1` also types the whole literal as `CGFloat`.
    for requested in [0, 24, 56, ZSpacing.touchMinimum - 1] {
        let clamped = IconButton(.house, label: "home", diameter: requested) {}
        #expect(clamped.diameter == ZSpacing.touchMinimum)
    }

    #expect(IconButton(.house, label: "home", diameter: 72) {}.diameter == 72)
    #expect(IconButton(.house, label: "home") {}.diameter == ZSpacing.touchComfortable)
}

@Test("Every card tint keeps its outline visible against its own fill")
func cardOutlinesDifferFromTheirFill() {
    let tones = ZCardTone.allCases

    #expect(tones.count == 5)
    #expect(tones.allSatisfy { $0.fill != $0.outline })
    #expect(Set(tones.map(\.fill)).count == 5)
}

@Test("Every badge tint pairs a soft fill with a dark text colour")
func badgeForegroundsDifferFromTheirFill() {
    let tones = Badge.Tone.allCases

    #expect(tones.count == 6)
    #expect(tones.allSatisfy { $0.fill != $0.foreground })
    #expect(Set(tones.map(\.fill)).count == 6)
    #expect(Set(tones.map(\.foreground)).count == 6)
}
