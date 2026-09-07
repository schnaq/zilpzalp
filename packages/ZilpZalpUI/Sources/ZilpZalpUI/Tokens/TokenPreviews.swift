#if DEBUG
    import SwiftUI

    // Xcode previews for the design tokens: every colour as a labelled swatch,
    // and the type scale as a ramp. The labels are the CSS custom property
    // names from `design/tokens/`, so the preview can be held against the
    // design export side by side.
    //
    // Baloo 2 and Nunito are registered from the app bundle, not from this
    // package, so the ramp renders in the system face here. What this preview
    // verifies is the scale: sizes, line spacing and the four weights.

    /// One labelled colour chip.
    private struct Swatch: Identifiable, Sendable {
        let id: String
        let color: Color
    }

    /// A titled block of chips.
    private struct SwatchGroup: Identifiable, Sendable {
        let title: String
        let swatches: [Swatch]

        var id: String {
            title
        }
    }

    private struct SwatchSection: View {
        let group: SwatchGroup

        private let columns = [GridItem(.adaptive(minimum: 92), spacing: ZSpacing.step2)]

        var body: some View {
            VStack(alignment: .leading, spacing: ZSpacing.step2) {
                Text(group.title)
                    .typeStyle(.label, .display, weight: .bold, singleLine: true)
                    .foregroundStyle(ZColor.textStrong)
                LazyVGrid(columns: columns, alignment: .leading, spacing: ZSpacing.step3) {
                    ForEach(group.swatches) { swatch in
                        VStack(alignment: .leading, spacing: ZSpacing.step1) {
                            RoundedRectangle(cornerRadius: ZRadius.small)
                                .fill(swatch.color)
                                .frame(height: 56)
                                .overlay {
                                    RoundedRectangle(cornerRadius: ZRadius.small)
                                        .strokeBorder(ZColor.borderCard, lineWidth: ZBorder.width)
                                }
                            Text(swatch.id)
                                .typeStyle(.caption, .body, weight: .semibold)
                                .foregroundStyle(ZColor.textMuted)
                        }
                    }
                }
            }
        }
    }

    private let colourGroups: [SwatchGroup] = [
        SwatchGroup(title: "Olive — meadow, primary", swatches: [
            Swatch(id: "olive-50", color: ZColor.olive50),
            Swatch(id: "olive-100", color: ZColor.olive100),
            Swatch(id: "olive-200", color: ZColor.olive200),
            Swatch(id: "olive-300", color: ZColor.olive300),
            Swatch(id: "olive-400", color: ZColor.olive400),
            Swatch(id: "olive-500", color: ZColor.olive500),
            Swatch(id: "olive-600", color: ZColor.olive600),
            Swatch(id: "olive-700", color: ZColor.olive700),
            Swatch(id: "olive-800", color: ZColor.olive800),
        ]),
        SwatchGroup(title: "Orange — hoopoe crest, accent", swatches: [
            Swatch(id: "orange-50", color: ZColor.orange50),
            Swatch(id: "orange-100", color: ZColor.orange100),
            Swatch(id: "orange-200", color: ZColor.orange200),
            Swatch(id: "orange-300", color: ZColor.orange300),
            Swatch(id: "orange-400", color: ZColor.orange400),
            Swatch(id: "orange-500", color: ZColor.orange500),
            Swatch(id: "orange-600", color: ZColor.orange600),
            Swatch(id: "orange-700", color: ZColor.orange700),
        ]),
        SwatchGroup(title: "Sun — reward, try again", swatches: [
            Swatch(id: "sun-100", color: ZColor.sun100),
            Swatch(id: "sun-200", color: ZColor.sun200),
            Swatch(id: "sun-300", color: ZColor.sun300),
            Swatch(id: "sun-400", color: ZColor.sun400),
            Swatch(id: "sun-500", color: ZColor.sun500),
            Swatch(id: "sun-600", color: ZColor.sun600),
        ]),
        SwatchGroup(title: "Clay — feathers", swatches: [
            Swatch(id: "clay-50", color: ZColor.clay50),
            Swatch(id: "clay-100", color: ZColor.clay100),
            Swatch(id: "clay-200", color: ZColor.clay200),
            Swatch(id: "clay-300", color: ZColor.clay300),
            Swatch(id: "clay-400", color: ZColor.clay400),
            Swatch(id: "clay-500", color: ZColor.clay500),
            Swatch(id: "clay-600", color: ZColor.clay600),
            Swatch(id: "clay-700", color: ZColor.clay700),
        ]),
        SwatchGroup(title: "Bark, berry, marsh", swatches: [
            Swatch(id: "bark-100", color: ZColor.bark100),
            Swatch(id: "bark-300", color: ZColor.bark300),
            Swatch(id: "bark-500", color: ZColor.bark500),
            Swatch(id: "bark-700", color: ZColor.bark700),
            Swatch(id: "berry-100", color: ZColor.berry100),
            Swatch(id: "berry-300", color: ZColor.berry300),
            Swatch(id: "berry-500", color: ZColor.berry500),
            Swatch(id: "berry-700", color: ZColor.berry700),
            Swatch(id: "marsh-100", color: ZColor.marsh100),
            Swatch(id: "marsh-300", color: ZColor.marsh300),
            Swatch(id: "marsh-500", color: ZColor.marsh500),
            Swatch(id: "marsh-700", color: ZColor.marsh700),
        ]),
        SwatchGroup(title: "Warm neutrals", swatches: [
            Swatch(id: "cream-50", color: ZColor.cream50),
            Swatch(id: "cream-100", color: ZColor.cream100),
            Swatch(id: "sand-200", color: ZColor.sand200),
            Swatch(id: "sand-300", color: ZColor.sand300),
            Swatch(id: "sand-400", color: ZColor.sand400),
            Swatch(id: "ink-300", color: ZColor.ink300),
            Swatch(id: "ink-500", color: ZColor.ink500),
            Swatch(id: "ink-700", color: ZColor.ink700),
            Swatch(id: "ink-900", color: ZColor.ink900),
            Swatch(id: "white", color: ZColor.white),
            Swatch(id: "soot", color: ZColor.soot),
        ]),
        SwatchGroup(title: "Brand roles", swatches: [
            Swatch(id: "primary", color: ZColor.primary),
            Swatch(id: "primary-hover", color: ZColor.primaryHover),
            Swatch(id: "primary-press", color: ZColor.primaryPress),
            Swatch(id: "primary-shadow", color: ZColor.primaryShadow),
            Swatch(id: "primary-soft", color: ZColor.primarySoft),
            Swatch(id: "accent", color: ZColor.accent),
            Swatch(id: "accent-press", color: ZColor.accentPress),
            Swatch(id: "accent-shadow", color: ZColor.accentShadow),
            Swatch(id: "accent-soft", color: ZColor.accentSoft),
            Swatch(id: "info", color: ZColor.info),
            Swatch(id: "info-soft", color: ZColor.infoSoft),
            Swatch(id: "reward", color: ZColor.reward),
            Swatch(id: "reward-shadow", color: ZColor.rewardShadow),
            Swatch(id: "rare", color: ZColor.rare),
        ]),
        SwatchGroup(title: "Feedback — olive is correct, sun is retry", swatches: [
            Swatch(id: "correct", color: ZColor.correct),
            Swatch(id: "correct-soft", color: ZColor.correctSoft),
            Swatch(id: "retry", color: ZColor.retry),
            Swatch(id: "retry-soft", color: ZColor.retrySoft),
        ]),
        SwatchGroup(title: "Surfaces", swatches: [
            Swatch(id: "surface-page", color: ZColor.surfacePage),
            Swatch(id: "surface-card", color: ZColor.surfaceCard),
            Swatch(id: "surface-sunken", color: ZColor.surfaceSunken),
            Swatch(id: "surface-forest", color: ZColor.surfaceForest),
            Swatch(id: "surface-warm", color: ZColor.surfaceWarm),
            Swatch(id: "scrim", color: ZColor.scrim),
        ]),
        SwatchGroup(title: "Text, lines and rings", swatches: [
            Swatch(id: "text-strong", color: ZColor.textStrong),
            Swatch(id: "text-body", color: ZColor.textBody),
            Swatch(id: "text-muted", color: ZColor.textMuted),
            Swatch(id: "text-on-color", color: ZColor.textOnColor),
            Swatch(id: "text-on-reward", color: ZColor.textOnReward),
            Swatch(id: "link", color: ZColor.link),
            Swatch(id: "link-hover", color: ZColor.linkHover),
            Swatch(id: "border-card", color: ZColor.borderCard),
            Swatch(id: "border-strong", color: ZColor.borderStrong),
            Swatch(id: "focus-ring", color: ZColor.focusRing),
        ]),
        SwatchGroup(
            title: "Rubrics — all ten topic colours",
            swatches: ZColor.Rubric.allCases.map { Swatch(id: $0.id, color: $0.color) },
        ),
    ]

    #Preview("Colours") {
        ScrollView {
            VStack(alignment: .leading, spacing: ZSpacing.step6) {
                ForEach(colourGroups) { group in
                    SwatchSection(group: group)
                }
            }
            .padding(ZSpacing.step5)
        }
        .background(ZColor.surfacePage)
    }

    #Preview("Type ramp") {
        ScrollView {
            VStack(alignment: .leading, spacing: ZSpacing.step5) {
                ForEach(ZType.Step.allCases) { step in
                    VStack(alignment: .leading, spacing: ZSpacing.step1) {
                        Text("text-\(step.id) · \(Int(step.size)) pt")
                            .typeStyle(.caption, .body, weight: .semibold)
                            .foregroundStyle(ZColor.textMuted)
                        Text("Zilpzalp")
                            // Not `singleLine`: at `hero` the design's box is
                            // 88 pt and Baloo 2 draws 141, so the glyphs would
                            // overhang far enough to sit on the caption above.
                            // A ramp is for reading the sizes off, so it keeps
                            // the face's own box.
                            .typeStyle(step, .display, weight: .bold)
                            .foregroundStyle(ZColor.textStrong)
                    }
                }
                Divider()
                ForEach(ZType.Weight.allCases, id: \.rawValue) { weight in
                    Text("Nunito \(weight.rawValue) — Wiedehopf, Rotkehlchen, Zilpzalp")
                        .typeStyle(.bodyLarge, .body, weight: weight)
                        .foregroundStyle(ZColor.textBody)
                }
            }
            .padding(ZSpacing.step5)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(ZColor.surfacePage)
    }
#endif
