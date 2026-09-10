import SwiftUI
import Testing
import ZilpZalpUI

// WCAG 2.1 contrast for every text/background pair the components draw.
//
// The ratios are computed from the tokens themselves rather than written down:
// a colour is resolved to its sRGB components, each one is linearised with the
// WCAG transfer function, and the relative luminance is the 0.2126/0.7152/
// 0.0722 sum SC 1.4.3 defines. Copying the numbers into the test instead would
// only prove that somebody had copied them.
//
// **The threshold per pair is the smallest type step that pair is drawn at.**
// SC 1.4.3 asks for 4.5:1, and for 3:1 where the text is large — which for a
// bold face is 24 pt here, the reading issue #238 states. So a `HomeTile`
// label, which drops to `body` 20 pt on a phone, is judged at 4.5:1, while a
// `FeedbackBanner` sentence at `headline` 28 pt bold is judged at 3:1. Where a
// tone is never drawn with a label by any screen, the component's own default
// size decides — noted on the pair.
//
// **What is deliberately not in the list**, all of it audited on 2026-09-11:
//
// - `ChoiceTile` and `StickerProgress` draw no text at all. The tile is
//   wordless by design, the row is five circles, and both say what they are
//   through VoiceOver only.
// - Glyphs and outlines are not text. SC 1.4.11 judges them at 3:1, and they
//   are a piece of work of their own: `RewardSticker.Tone.rare` draws its
//   glyph in `white` on `berry300` at 1.99:1 — under even that floor — and no
//   screen uses the tone yet.
// - Locked states are exempt. `HomeTile` and `RewardSticker` draw a locked
//   tile in `ink300` on `sand200`, 2.66:1, and SC 1.4.3 excludes inactive
//   components. A locked `HomeTile` is not on any v1 screen either (spec §3).
//
// `LedgePalette.clay` is the one exception to that second point and is in the
// list anyway, at the graphic threshold — see ``ContrastPair/glyphs``.

/// One text colour on one background, and the ratio SC 1.4.3 asks of them.
struct ContrastPair: Sendable, CustomStringConvertible {
    /// Which component draws it, in words, so a failure names itself.
    let name: String
    let foreground: Color
    let background: Color
    /// ``WCAG/normalText`` or ``WCAG/largeText``, see the file comment.
    /// Defaulted, so that only the pairs judged at the large threshold spell
    /// one out — and every one of those carries the reason beside it.
    var minimum = WCAG.normalText

    var description: String {
        name
    }

    /// The contrast ratio of the two, `(lighter + 0.05) / (darker + 0.05)`.
    @MainActor var ratio: Double {
        let light = max(relativeLuminance(foreground), relativeLuminance(background))
        let dark = min(relativeLuminance(foreground), relativeLuminance(background))
        return (light + 0.05) / (dark + 0.05)
    }
}

/// The two thresholds of SC 1.4.3.
enum WCAG {
    static let normalText = 4.5
    /// Text of at least 24 pt bold — the reading issue #238 fixes for this
    /// design, whose smallest bold display step is 20 pt.
    static let largeText = 3.0
}

@MainActor
private func relativeLuminance(_ color: Color) -> Double {
    let resolved = color.resolve(in: EnvironmentValues())
    /// `Color.Resolved` hands back gamma-encoded sRGB; SC 1.4.3 wants the
    /// linear components, and this is its own transfer function rather than
    /// `linearRed` and friends, which is what the issue asked to be computed.
    func linear(_ channel: Float) -> Double {
        let value = Double(channel)
        return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * linear(resolved.red)
        + 0.7152 * linear(resolved.green)
        + 0.0722 * linear(resolved.blue)
}

extension ContrastPair {
    /// Every pair, one entry per tone, in the order the components declare
    /// them. Spelled out rather than derived from the components: what a tone
    /// paints is internal to `ZilpZalpUI`, and a list that walked the same
    /// switch statements would pass whatever those statements said.
    static let all: [ContrastPair] = homeTile + pressables + glyphs + banners + badges + cards
        + surfaces

    /// The one non-text pair worth pinning: `LedgePalette.clay`.
    ///
    /// Issue #238 asked for a darker `clay500` because `textOnColor` on it is
    /// 4.25:1. No text is ever set on that palette — `ZButton.Tone` has no
    /// clay, so `IconButton` is its only user and a glyph is judged by SC
    /// 1.4.11 at 3:1, which it clears. It is listed rather than left out so
    /// that the reasoning is a test rather than a paragraph, and so that a
    /// future clay button with a label meets a threshold that has moved.
    static let glyphs: [ContrastPair] = [
        ContrastPair(
            name: "IconButton .clay glyph",
            foreground: ZColor.textOnColor,
            background: ZColor.info,
            minimum: WCAG.largeText,
        ),
    ]

    /// `HomeTile.Tone.palette` — foreground on background. The label follows
    /// the tile down to `body` 20 pt on a phone, so all four are normal text.
    static let homeTile: [ContrastPair] = [
        ContrastPair(
            name: "HomeTile .leaf label",
            foreground: ZColor.olive700,
            background: ZColor.olive100,
        ),
        ContrastPair(
            name: "HomeTile .clay label",
            foreground: ZColor.clay700,
            background: ZColor.clay100,
        ),
        ContrastPair(
            name: "HomeTile .sun label",
            foreground: ZColor.ink900,
            background: ZColor.sun200,
        ),
        ContrastPair(
            name: "HomeTile .hoopoe label",
            foreground: ZColor.orange700,
            background: ZColor.orange100,
        ),
    ]

    /// `LedgePalette` — the label on the capsule's face, at rest and pressed.
    /// `ZButton.Size.medium` sets a label in `label` 22 pt bold, so a tone a
    /// screen puts words on is normal text.
    static let pressables: [ContrastPair] = [
        ContrastPair(
            name: "ZButton .primary label",
            foreground: ZColor.textOnColor,
            background: ZColor.primary,
        ),
        ContrastPair(
            name: "ZButton .primary label, pressed",
            foreground: ZColor.textOnColor,
            background: ZColor.primaryPress,
        ),
        // Large text because `ZButton`'s default size sets `headline` 28 pt
        // bold, and no screen draws an accent button
        // with a label at all — the tone reaches a child through `SoundButton`
        // and `IconButton`, both wordless. A `.medium` accent button would be
        // 3.23:1 against a 22 pt label, and darkening `orange500` — the crest,
        // the focus ring and the link colour — is a decision of its own.
        ContrastPair(
            name: "ZButton .accent label",
            foreground: ZColor.textOnColor,
            background: ZColor.accent,
            minimum: WCAG.largeText,
        ),
        ContrastPair(
            name: "ZButton .reward label",
            foreground: ZColor.textOnReward,
            background: ZColor.reward,
        ),
        ContrastPair(
            name: "ZButton .reward label, pressed",
            foreground: ZColor.textOnReward,
            background: ZColor.sun500,
        ),
        ContrastPair(
            name: "ZButton .quiet label",
            foreground: ZColor.textStrong,
            background: ZColor.white,
        ),
        ContrastPair(
            name: "ZButton .quiet label, pressed",
            foreground: ZColor.textStrong,
            background: ZColor.cream100,
        ),
    ]

    /// `FeedbackBanner.Kind.palette` — the sentence on the capsule, always
    /// `headline` 28 pt bold.
    static let banners: [ContrastPair] = [
        ContrastPair(
            name: "FeedbackBanner .correct sentence",
            foreground: ZColor.olive800,
            background: ZColor.correctSoft,
            minimum: WCAG.largeText,
        ),
        ContrastPair(
            name: "FeedbackBanner .retry sentence",
            foreground: ZColor.bark700,
            background: ZColor.retrySoft,
            minimum: WCAG.largeText,
        ),
        ContrastPair(
            name: "FeedbackBanner .hint sentence",
            foreground: ZColor.clay700,
            background: ZColor.clay50,
            minimum: WCAG.largeText,
        ),
    ]

    /// `Badge.Tone` — one or two words in `body` 20 pt bold.
    static let badges: [ContrastPair] = [
        ContrastPair(
            name: "Badge .leaf text",
            foreground: ZColor.olive700,
            background: ZColor.primarySoft,
        ),
        ContrastPair(
            name: "Badge .hoopoe text",
            foreground: ZColor.orange700,
            background: ZColor.accentSoft,
        ),
        ContrastPair(
            name: "Badge .sun text",
            foreground: ZColor.bark700,
            background: ZColor.sun200,
        ),
        ContrastPair(
            name: "Badge .clay text",
            foreground: ZColor.clay700,
            background: ZColor.clay100,
        ),
        ContrastPair(
            name: "Badge .rare text",
            foreground: ZColor.berry700,
            background: ZColor.berry100,
        ),
        ContrastPair(
            name: "Badge .sand text",
            foreground: ZColor.ink700,
            background: ZColor.sand200,
        ),
    ]

    /// `ZCardTone` — the prose a card holds, `body` 20 pt semibold in
    /// `--text-body`.
    static let cards: [ContrastPair] = [
        ContrastPair(
            name: "ZCard .paper copy",
            foreground: ZColor.textBody,
            background: ZColor.surfaceCard,
        ),
        ContrastPair(
            name: "ZCard .leaf copy",
            foreground: ZColor.textBody,
            background: ZColor.olive50,
        ),
        ContrastPair(
            name: "ZCard .clay copy",
            foreground: ZColor.textBody,
            background: ZColor.clay50,
        ),
        ContrastPair(
            name: "ZCard .sun copy",
            foreground: ZColor.textBody,
            background: ZColor.sun100,
        ),
        ContrastPair(
            name: "ZCard .sand copy",
            foreground: ZColor.textBody,
            background: ZColor.surfaceSunken,
        ),
    ]

    /// The text roles on the surfaces the screens paint: the page, a card, and
    /// the forest ground the round end celebrates on. `RewardSticker`'s
    /// caption is `body` 20 pt bold in `--text-strong`, or `--text-muted`
    /// while the bird is still locked.
    static let surfaces: [ContrastPair] = [
        ContrastPair(
            name: "Strong text on the page",
            foreground: ZColor.textStrong,
            background: ZColor.surfacePage,
        ),
        ContrastPair(
            name: "Body text on the page",
            foreground: ZColor.textBody,
            background: ZColor.surfacePage,
        ),
        ContrastPair(
            name: "RewardSticker caption, locked (muted on the page)",
            foreground: ZColor.textMuted,
            background: ZColor.surfacePage,
        ),
        ContrastPair(
            name: "Link on the page",
            foreground: ZColor.link,
            background: ZColor.surfacePage,
        ),
        ContrastPair(
            name: "RewardSticker caption on a card",
            foreground: ZColor.textStrong,
            background: ZColor.surfaceCard,
        ),
        ContrastPair(
            name: "Round end, text on the forest ground",
            foreground: ZColor.textOnColor,
            background: ZColor.surfaceForest,
        ),
    ]
}

@MainActor
@Test("Every text pair the components draw clears its WCAG threshold", arguments: ContrastPair.all)
func textContrastClearsItsThreshold(pair: ContrastPair) {
    let ratio = pair.ratio
    #expect(
        ratio >= pair.minimum,
        "\(pair.name): \(String(format: "%.2f", ratio)):1, below \(pair.minimum):1",
    )
}

@MainActor
@Test("The ratio is WCAG's own, checked against the two ends and a known pair")
func theContrastFormulaIsWCAGs() {
    // Black on white is 21:1 by definition, and a colour on itself is 1:1 —
    // the two ends of the scale. Without them a transfer function that had
    // drifted would still order the palette plausibly.
    let extreme = ContrastPair(
        name: "soot on white",
        foreground: Color(.sRGB, red: 0, green: 0, blue: 0),
        background: Color(.sRGB, red: 1, green: 1, blue: 1),
    )
    #expect(abs(extreme.ratio - 21) < 0.01)

    let flat = ContrastPair(
        name: "olive on olive",
        foreground: ZColor.olive500,
        background: ZColor.olive500,
    )
    #expect(abs(flat.ratio - 1) < 0.001)

    // And one pair from the palette, computed outside this file: `#FFFCF3` on
    // `#6E7A21` is 4.58:1, the tightest text pair the design system has.
    let primary = ContrastPair(
        name: "ZButton .primary label",
        foreground: ZColor.textOnColor,
        background: ZColor.primary,
    )
    #expect(abs(primary.ratio - 4.58) < 0.01)
}
