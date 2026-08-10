import SwiftUI

// Semantic aliases, surfaces, text colours, lines and the ten rubric colours
// from `design/tokens/colors.css` (everything below its "SEMANTIC ALIASES"
// divider). The palette ramps these point at live in `Colors.swift`.
//
// Each token carries its CSS custom property and the ramp entry it resolves
// to, because the Swift name alone does not show which shade was chosen.

public extension ZColor {
    // MARK: - Brand roles

    /// `--color-primary` → `--olive-500`. Primary actions and the app's voice.
    static let primary = olive500
    /// `--color-primary-hover` → `--olive-400`.
    static let primaryHover = olive400
    /// `--color-primary-press` → `--olive-600`.
    static let primaryPress = olive600
    /// `--color-primary-shadow` → `--olive-700`. The ledge under a primary
    /// pressable; see ``ZShadow/ledgeOffset``.
    static let primaryShadow = olive700
    /// `--color-primary-soft` → `--olive-100`.
    static let primarySoft = olive100

    /// `--color-accent` → `--orange-500`. The hoopoe crest.
    static let accent = orange500
    /// `--color-accent-press` → `--orange-600`.
    static let accentPress = orange600
    /// `--color-accent-shadow` → `--orange-700`.
    static let accentShadow = orange700
    /// `--color-accent-soft` → `--orange-100`.
    static let accentSoft = orange100

    /// `--color-info` → `--clay-500`.
    static let info = clay500
    /// `--color-info-soft` → `--clay-100`.
    static let infoSoft = clay100

    /// `--color-reward` → `--sun-400`.
    static let reward = sun400
    /// `--color-reward-shadow` → `--sun-600`.
    static let rewardShadow = sun600

    /// `--color-rare` → `--berry-500`. Rare finds in the collection.
    static let rare = berry500

    // MARK: - Feedback

    // Feedback is never punishing: correct is olive, retry is sun, never red —
    // and never an X. This is a didactic decision, not a styling taste, and
    // `DesignTokenTests` guards it.

    /// `--color-correct` → `--olive-500`. Olive green, never red.
    static let correct = olive500
    /// `--color-correct-soft` → `--olive-200`.
    static let correctSoft = olive200
    /// `--color-retry` → `--sun-400`. Sun yellow — "try again", not "wrong".
    static let retry = sun400
    /// `--color-retry-soft` → `--sun-100`.
    static let retrySoft = sun100

    // MARK: - Surfaces

    /// `--surface-page` → `--cream-100`.
    static let surfacePage = cream100
    /// `--surface-card` → `--cream-50`.
    static let surfaceCard = cream50
    /// `--surface-sunken` → `--sand-200`.
    static let surfaceSunken = sand200
    /// `--surface-forest` → `--olive-800`.
    static let surfaceForest = olive800
    /// `--surface-warm` → `--orange-100`.
    static let surfaceWarm = orange100
    /// `--scrim: rgba(42,34,19,.45)` — `--ink-900` at 45 %.
    static let scrim = ink900.opacity(0.45)

    // MARK: - Text

    /// `--text-strong` → `--ink-900`.
    static let textStrong = ink900
    /// `--text-body` → `--ink-700`.
    static let textBody = ink700
    /// `--text-muted` → `--ink-500`.
    static let textMuted = ink500
    /// `--text-on-color` → `--cream-50`. Labels on primary, accent and clay.
    static let textOnColor = cream50
    /// `--text-on-reward` → `--ink-900`. Sun yellow needs dark text.
    static let textOnReward = ink900
    /// `--link` → `--olive-600`.
    static let link = olive600
    /// `--link-hover` → `--orange-500`.
    static let linkHover = orange500

    // MARK: - Lines & rings

    /// `--border-card` → `--sand-300`.
    static let borderCard = sand300
    /// `--border-strong` → `--sand-400`.
    static let borderStrong = sand400
    /// `--focus-ring` → `--orange-500`. See ``ZShadow/focusRingColor`` for the
    /// ring itself.
    static let focusRing = orange500
}

public extension ZColor {
    /// One of the ten topic colours from `colors.css` (`--rubric-*`): one
    /// colour per topic, all warm, used for tiles, badges and chapter headers.
    ///
    /// The identifiers are German because they are the token names from the
    /// design export — `wald` is `--rubric-wald`, not prose. Product copy
    /// never comes from here.
    ///
    /// A struct rather than an enum so each rubric carries its token name next
    /// to its colour; ``allCases`` makes the set enumerable for galleries and
    /// for the completeness test.
    struct Rubric: Sendable, Hashable, Identifiable, CaseIterable {
        /// The token name without the `--rubric-` prefix, e.g. `wald`.
        public let id: String
        /// The colour this topic is drawn in.
        public let color: Color

        /// `--rubric-wald` → `--olive-500`.
        public static let wald = Rubric(id: "wald", color: olive500)
        /// `--rubric-wiese` → `--olive-400`.
        public static let wiese = Rubric(id: "wiese", color: olive400)
        /// `--rubric-rufe` → `--orange-500`.
        public static let rufe = Rubric(id: "rufe", color: orange500)
        /// `--rubric-belohnung` → `--sun-400`.
        public static let belohnung = Rubric(id: "belohnung", color: sun400)
        /// `--rubric-federn` → `--clay-500`.
        public static let federn = Rubric(id: "federn", color: clay500)
        /// `--rubric-rinde` → `--bark-500`.
        public static let rinde = Rubric(id: "rinde", color: bark500)
        /// `--rubric-beeren` → `--berry-500`.
        public static let beeren = Rubric(id: "beeren", color: berry500)
        /// `--rubric-nest` → `--orange-200`. A light tint, unlike the other
        /// rubrics; the design guidelines pair it with `--ink-900` labels.
        public static let nest = Rubric(id: "nest", color: orange200)
        /// `--rubric-sumpf` → `--marsh-500`.
        public static let sumpf = Rubric(id: "sumpf", color: marsh500)
        /// `--rubric-sonne` → `--orange-300`. A light tint, unlike the other
        /// rubrics; the design guidelines pair it with `--ink-900` labels.
        public static let sonne = Rubric(id: "sonne", color: orange300)

        /// All ten rubrics, in the order `colors.css` declares them.
        public static let allCases: [Rubric] = [
            wald,
            wiese,
            rufe,
            belohnung,
            federn,
            rinde,
            beeren,
            nest,
            sumpf,
            sonne,
        ]
    }
}
