import SwiftUI
import Testing
@testable import ZilpZalpUI

// What the quiz components decide before they draw anything: which colours and
// glyphs a state resolves to, which sizes survive a careless caller, and what a
// locked sticker keeps. Rendering is not tested — that is what the `#Preview`
// blocks and the screenshot in the pull request are for.
//
// `DesignTokenTests` already pins that `ZColor.correct` is olive and
// `ZColor.retry` is sun. The tests here pin the other half of that promise:
// that the components reach for those two semantic tokens rather than
// inventing a colour of their own, and that no third, punishing state exists.
//
// Some of the task's requirements need no test because the compiler enforces
// them: `ChoiceTile.init` and `SoundButton.init` have no default for `label`,
// so a wordless control without a VoiceOver name does not compile, and
// `RewardSticker` is a plain `View` with no action, so it cannot be tapped.

@MainActor
@Suite("Quiz components")
struct QuizComponentTests {
    // MARK: - ChoiceTile

    @Test("A resolved tile marks itself olive with a check or sun with a rotate")
    func tileBadgesAreOliveCheckAndSunRotate() throws {
        let correct = try #require(ChoiceTile.Phase.correct.badge)
        let retry = try #require(ChoiceTile.Phase.retry.badge)

        #expect(correct.icon == .check)
        #expect(correct.fill == ZColor.correct)
        #expect(correct.foreground == ZColor.white)
        #expect(retry.icon == .rotateCcw)
        #expect(retry.fill == ZColor.retry)
        // Sun yellow needs dark ink on it, as everywhere else in the system.
        #expect(retry.foreground == ZColor.bark700)
    }

    @Test("There is no third badge, and neither of the two is an X")
    func onlyTwoBadgesExistAndNeitherIsAnX() {
        let badges = ChoiceTile.Phase.allCases.compactMap(\.badge)

        // An unresolved tile carries no marker at all.
        #expect(ChoiceTile.Phase.idle.badge == nil)
        #expect(ChoiceTile.Phase.chosen.badge == nil)
        // Two markers, and these two only: a check and a "go round again".
        // There is no third phase for a cross to grow on.
        #expect(badges.map(\.icon) == [.check, .rotateCcw])
    }

    @Test("An idle tile is dressed by its rubric; a touched one is dressed by its phase")
    func idleTakesItsColoursFromTheToneAndTheRestFromThePhase() {
        let idle = ChoiceTile.Phase.idle.palette(on: .beeren)

        #expect(idle.border == ChoiceTile.Tone.beeren.edge)
        #expect(idle.ledge == ChoiceTile.Tone.beeren.edge)
        // No halo on an untouched tile: four haloed tiles would say nothing.
        #expect(idle.ring == nil)

        // The rubric is overruled the moment a finger lands, whatever it was.
        for tone in ChoiceTile.Tone.allCases {
            #expect(ChoiceTile.Phase.correct.palette(on: tone).border == ZColor.correct)
            #expect(ChoiceTile.Phase.retry.palette(on: tone).border == ZColor.retry)
            #expect(ChoiceTile.Phase.chosen.palette(on: tone).border == ZColor.accent)
        }
    }

    @Test("Every touched phase gets a halo, and only the idle one goes without")
    func onlyIdleHasNoHalo() {
        let haloed = ChoiceTile.Phase.allCases.filter {
            $0.palette(on: .papier).ring != nil
        }

        #expect(haloed == [.chosen, .correct, .retry])
    }

    @Test("The nine rubrics are nine different tiles")
    func rubricTonesAreDistinct() {
        let tones = ChoiceTile.Tone.allCases

        #expect(tones.count == 9)
        #expect(Set(tones.map(\.edge)).count == 9)
        #expect(Set(tones.map(\.field)).count == 9)
        // The field is the lightest tint and the edge the deepest shade; a
        // tone that painted both the same would lose its outline.
        #expect(tones.allSatisfy { $0.field != $0.edge })
    }

    @Test(
        "A tile is never smaller than 168 pt, whatever it is asked for",
        arguments: [
            (CGFloat(0), CGFloat(168)),
            (-40, 168),
            (64, 168),
            (167, 168),
            // What a phone measures, drawn as measured rather than scaled
            // down from 220 (#104).
            (168, 168),
            (169, 169),
            (220, 220),
            (260, 260),
        ],
    )
    func tileSizesAreClampedUpToTheFloor(given: CGFloat, expected: CGFloat) {
        #expect(ChoiceTile(label: "Amsel", size: given).size == expected)
    }

    @Test("The tile floor clears the touch minimum several times over")
    func theTileFloorIsFarAboveTheTouchMinimum() {
        #expect(ChoiceTile.minimumSize > 2 * ZSpacing.touchMinimum)
        #expect(ChoiceTile.defaultSize >= ChoiceTile.minimumSize)
    }

    @Test("The floor is where the credit strip stops fitting")
    func theTileFloorFollowsTheCreditStrip() {
        // The floor is derived from ``PhotoCreditMetrics``, so this pins both
        // ends: the number it comes out at today, and the three values it is
        // derived from. A credit that had to shrink or lose its licence to fit
        // is the defect #104 set out to remove.
        #expect(ChoiceTile.minimumSize == 168)
        #expect(PhotoCreditMetrics.minimumColumn == 115.3)
        #expect(PhotoCreditMetrics.size == 13)
        #expect(PhotoCreditMetrics.lineLimit == 2)
    }

    @Test("A dimmed tile is faded, not switched off")
    func dimmingIsOpacityOnly() {
        // The only thing `dimmed` may do. There is no `disabled` on this
        // control at all: a wrong tap must never feel like a locked door.
        #expect(ChoiceTileMetrics.dimmedOpacity > 0)
        #expect(ChoiceTileMetrics.dimmedOpacity < 1)
    }

    // MARK: - SoundButton

    @Test("The glyph says whether a call is sounding")
    func soundButtonSwapsItsGlyphWhilePlaying() {
        #expect(SoundButton(isPlaying: true, label: "Ruf anhören").glyph == .volume2)
        #expect(SoundButton(isPlaying: false, label: "Ruf anhören").glyph == .play)
    }

    @Test(
        "The sound button is never smaller than 120 pt",
        arguments: [
            (CGFloat(0), CGFloat(120)),
            (-10, 120),
            (64, 120),
            (119, 120),
            (120, 120),
            (150, 150),
            (160, 160),
        ],
    )
    func soundButtonDiametersAreClampedUpToTheFloor(given: CGFloat, expected: CGFloat) {
        #expect(SoundButton(isPlaying: false, label: "Ruf anhören", diameter: given)
            .diameter == expected)
    }

    @Test("Its floor is well above the touch minimum, and its default above that")
    func theSoundButtonFloorClearsTheTouchMinimum() {
        #expect(SoundButton.minimumDiameter == 120)
        #expect(SoundButton.minimumDiameter > ZSpacing.touchMinimum)
        #expect(SoundButton(isPlaying: false, label: "Ruf anhören").diameter == ZSpacing.touchHero)
    }

    @Test("The rings pulse within the motion budget the guidelines set")
    func ringPulseStaysInsideTheMotionBudget() {
        // `design/readme.md`: nothing exceeds 900 ms. The JSX's own 1.4 s ring
        // breaks that; the port takes the token instead.
        #expect(SoundButtonMetrics.pulse == ZMotion.celebrate)
        #expect(ZMotion.durations.allSatisfy { $0 <= SoundButtonMetrics.pulse })
        // The ring travels outward and fades; it never comes back shrinking.
        #expect(SoundButtonMetrics.ringScale > 1)
        #expect(SoundButtonMetrics.ringOpacity < 1)
    }

    @Test("The reduced-motion ring sits clear of the button, or it is not a ring")
    func theStaticRingClearsTheButtonFace() {
        // A ring that does not travel is only visible if it starts outside the
        // face: at scale 1 it is an accent circle on the accent capsule, the
        // same size — invisible, not subtle. It still has to stop short of
        // where a travelling ring ends, or it would not look like a resting
        // one.
        #expect(SoundButtonMetrics.restingRingScale > 1)
        #expect(SoundButtonMetrics.restingRingScale < SoundButtonMetrics.ringScale)
    }

    // MARK: - QuizProgress

    @Test("One leaf per question, and never more")
    func progressDrawsOneLeafPerQuestion() {
        #expect(QuizProgress(total: 5, completed: 2, label: "").leafStates.count == 5)
        #expect(QuizProgress(total: 3, completed: 0, label: "").leafStates.count == 3)
        #expect(QuizProgress(total: 0, completed: 0, label: "").leafStates.isEmpty)
        // A negative round is read as no round rather than trapping.
        #expect(QuizProgress(total: -4, completed: 2, label: "").leafStates.isEmpty)
    }

    @Test(
        "Answered questions are clamped into the round",
        arguments: [(-3, 0), (0, 0), (2, 2), (5, 5), (9, 5), (Int.max, 5)],
    )
    func completedIsClamped(given: Int, expected: Int) {
        let progress = QuizProgress(total: 5, completed: given, label: "")

        #expect(progress.completed == expected)
        #expect(progress.leafStates.filter { $0 == .done }.count == expected)
    }

    @Test("The leaves read done, current, then upcoming")
    func leavesReadInOrder() {
        let progress = QuizProgress(total: 5, completed: 2, current: 2, label: "")

        #expect(progress.leafStates == [.done, .done, .current, .upcoming, .upcoming])
    }

    @Test("A leaf that is both answered and current stays answered")
    func doneWinsOverCurrent() {
        let progress = QuizProgress(total: 3, completed: 3, current: 1, label: "")

        #expect(progress.leafStates == [.done, .done, .done])
    }

    @Test(
        "A current index outside the round is dropped, not drawn somewhere",
        arguments: [-1, 5, 99, Int.max],
    )
    func strayCurrentIndicesAreDropped(given: Int) {
        let progress = QuizProgress(total: 5, completed: 0, current: given, label: "")

        #expect(progress.current == nil)
        #expect(!progress.leafStates.contains(.current))
    }

    // There is no "renders no digits" test, because there is nothing to assert
    // against: the row builds no `Text` at all. The only String it holds is the
    // accessibility label, which the caller writes and VoiceOver speaks, and
    // `leafStates` above is the complete visible model — three colour states,
    // no counts, no numerals.

    @Test("Only the question in play is outlined and enlarged")
    func onlyTheCurrentLeafStandsOut() {
        #expect(QuizProgress.LeafState.current.outline == ZColor.primary)
        #expect(QuizProgress.LeafState.done.outline == .clear)
        #expect(QuizProgress.LeafState.upcoming.outline == .clear)
        #expect(QuizProgressMetrics.currentScale > 1)
    }

    @Test("A grown leaf is olive; the others are not")
    func doneLeavesAreOlive() {
        #expect(QuizProgress.LeafState.done.fill == ZColor.primary)
        #expect(QuizProgress.LeafState.upcoming.fill == ZColor.surfaceSunken)
        #expect(QuizProgress.LeafState.done.fill != QuizProgress.LeafState.upcoming.fill)
    }

    // MARK: - FeedbackBanner

    @Test("Correct is olive, retry is sun, hint is clay — and none of them is red")
    func bannerKindsUseTheSemanticFeedbackTokens() {
        #expect(FeedbackBanner.Kind.correct.palette.fill == ZColor.correctSoft)
        #expect(FeedbackBanner.Kind.correct.palette.edge == ZColor.correct)
        #expect(FeedbackBanner.Kind.retry.palette.fill == ZColor.retrySoft)
        #expect(FeedbackBanner.Kind.retry.palette.edge == ZColor.retry)
        #expect(FeedbackBanner.Kind.hint.palette.edge == ZColor.clay300)
    }

    @Test("Each kind brings its own glyph, and a caller may override it")
    func bannerGlyphsDefaultPerKindAndCanBeOverridden() {
        #expect(FeedbackBanner("", kind: .correct).displayedIcon == .partyPopper)
        #expect(FeedbackBanner("", kind: .retry).displayedIcon == .handHeart)
        #expect(FeedbackBanner("", kind: .hint).displayedIcon == .lightbulb)

        // The quiz screen may want the banner to echo the tile above it.
        #expect(FeedbackBanner("", kind: .correct, icon: .check).displayedIcon == .check)
        #expect(FeedbackBanner("", kind: .retry, icon: .rotateCcw).displayedIcon == .rotateCcw)
    }

    @Test("The three kinds are told apart by fill and edge alike")
    func bannerKindsAreDistinct() {
        let palettes = FeedbackBanner.Kind.allCases.map(\.palette)

        #expect(palettes.count == 3)
        #expect(Set(palettes.map(\.fill)).count == 3)
        #expect(Set(palettes.map(\.edge)).count == 3)
        #expect(Set(palettes.map(\.icon)).count == 3)
    }

    // MARK: - RewardSticker

    @Test("A locked sticker keeps its photo — greyed, badged, but there")
    func lockedStickersKeepTheirImage() {
        let locked = RewardSticker(image: Image(systemName: "photo"), locked: true)

        #expect(locked.showsImage)
        #expect(locked.palette == RewardStickerPalette.locked)
        // Grey, not gone: the fade is partial by construction.
        #expect(RewardStickerMetrics.lockedPhotoOpacity > 0)
        #expect(RewardStickerMetrics.lockedPhotoOpacity < 1)
    }

    @Test("Without a photo, a locked sticker shows the padlock in its place")
    func lockedStickersWithoutAPhotoShowAPadlock() {
        let locked = RewardSticker(icon: .star, locked: true)

        #expect(!locked.showsImage)
        #expect(locked.displayedIcon == .lock)
    }

    @Test("A chosen sticker keeps its tone, gains an olive rim and a check")
    func chosenStickersAreRingedAndChecked() {
        let chosen = RewardSticker(icon: .bird, tone: .sun, chosen: true)
        let plain = RewardSticker(icon: .bird, tone: .sun)

        // The disc itself does not change — only the ring around it — so the
        // picture stays the thing a child recognises the sticker by.
        #expect(chosen.palette.background == plain.palette.background)
        #expect(chosen.palette.edge != plain.palette.edge)
        // Never colour alone: the check is the shape half of the answer.
        #expect(chosen.badgeIcon == .check)
        #expect(plain.badgeIcon == nil)
    }

    @Test("Nothing a child has not earned is a thing it can choose")
    func lockedStickersAreNeverChosen() {
        let locked = RewardSticker(image: Image(systemName: "photo"), locked: true, chosen: true)

        #expect(locked.palette == RewardStickerPalette.locked)
        // The one badge slot goes to the padlock, and the check stays away.
        #expect(locked.badgeIcon == .lock)
        #expect(RewardSticker(icon: .star, locked: true, chosen: true).badgeIcon == nil)
    }

    @Test("An earned sticker keeps its own glyph, its tone and its tilt")
    func earnedStickersKeepEverything() {
        let earned = RewardSticker(icon: .feather, tone: .hoopoe, rotation: .degrees(-7))

        #expect(earned.displayedIcon == .feather)
        #expect(earned.palette == RewardSticker.Tone.hoopoe.palette)
        #expect(earned.displayedRotation == .degrees(-7))
    }

    @Test("The tilt is the reward: a locked sticker sits straight")
    func lockedStickersSitStraight() {
        let locked = RewardSticker(icon: .star, locked: true, rotation: .degrees(-12))

        #expect(locked.displayedRotation == .zero)
        #expect(RewardSticker.defaultRotation == .degrees(-4))
    }

    @Test("The four sticker tones are four different stickers, none of them locked")
    func stickerTonesAreDistinctAndUnlike() {
        let palettes = RewardSticker.Tone.allCases.map(\.palette)

        #expect(palettes.count == 4)
        #expect(Set(palettes).count == 4)
        #expect(!palettes.contains(RewardStickerPalette.locked))
    }
}
