import SwiftUI

/// One line in the grown-ups area — either a navigation row with a value and
/// a chevron, or a switch row.
///
/// Ported from `design/components/navigation/SettingRow.jsx`. This is the only
/// component allowed the 16 pt caption step, and it uses it for the hint line
/// alone: nobody but a grown-up ever reads a settings row, so the kid-facing
/// 20 pt floor does not apply here.
///
/// A navigation row is tappable across its full width. A switch row is a
/// plain `Toggle`, so the system switch is the tap target and the system's
/// own off-state grey shows through — an adult control on an adult screen,
/// behaving exactly as Settings.app does, rather than a hand-drawn switch in
/// sand and olive. Either way the row is at least 64 pt tall and reads as one
/// VoiceOver element — which a switch row does not do on its own, see the
/// comment in `body`.
///
/// The design's three columns are an iPad's; below the regular size class, and
/// at an accessibility text size whatever the class, the row stacks instead —
/// ``SettingRowStack`` says how.
///
/// `.disabled(_:)` works as on any SwiftUI control: a navigation row dims to
/// the system's one disabled opacity, a switch row lets `Toggle` grey itself.
/// A row that exists before the screen behind it does — the time budget
/// before #36 — is drawn this way rather than dimmed by its caller.
///
/// Every visible string is a parameter. The package holds no product copy.
public struct SettingRow: View {
    private enum Kind {
        case navigation(value: String?, action: () -> Void)
        case toggle(isOn: Binding<Bool>)
    }

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private let title: String
    private let hint: String?
    private let icon: ZIcon?
    private let showsSeparator: Bool
    private let kind: Kind

    /// A navigation row: taps it to open something, with an optional current
    /// value in front of the chevron.
    ///
    /// - Parameters:
    ///   - title: The setting's name.
    ///   - hint: The explanatory line underneath, in the caption step.
    ///   - icon: The glyph in front of the title.
    ///   - value: What the setting currently stands at, right-aligned.
    ///   - showsSeparator: The line along the bottom edge. Turn it off for the
    ///     last row of a card, exactly as the design's grown-ups screen does.
    ///     The line lives here so its width and colour are stated once; it
    ///     moves to `ZCard` when that component can interleave rows itself.
    ///   - action: Run on tap.
    public init(
        title: String,
        hint: String? = nil,
        icon: ZIcon? = nil,
        value: String? = nil,
        showsSeparator: Bool = true,
        action: @escaping () -> Void,
    ) {
        self.init(
            title: title,
            hint: hint,
            icon: icon,
            showsSeparator: showsSeparator,
            kind: .navigation(value: value, action: action),
        )
    }

    /// A switch row: the whole row toggles the binding.
    ///
    /// - Parameters:
    ///   - title: The setting's name.
    ///   - hint: The explanatory line underneath, in the caption step.
    ///   - icon: The glyph in front of the title.
    ///   - isOn: The state the switch reads and writes.
    ///   - showsSeparator: The line along the bottom edge. Turn it off for the
    ///     last row of a card.
    public init(
        title: String,
        hint: String? = nil,
        icon: ZIcon? = nil,
        isOn: Binding<Bool>,
        showsSeparator: Bool = true,
    ) {
        self.init(
            title: title,
            hint: hint,
            icon: icon,
            showsSeparator: showsSeparator,
            kind: .toggle(isOn: isOn),
        )
    }

    private init(
        title: String,
        hint: String?,
        icon: ZIcon?,
        showsSeparator: Bool,
        kind: Kind,
    ) {
        self.title = title
        self.hint = hint
        self.icon = icon
        self.showsSeparator = showsSeparator
        self.kind = kind
    }

    public var body: some View {
        Group {
            switch kind {
            case let .navigation(value, action):
                Button(action: action) {
                    row {
                        HStack(spacing: ZSpacing.step2) {
                            if let value {
                                Text(value)
                            }
                            Icon(.chevronRight, size: .small)
                        }
                        // Not `singleLine`: this sets the type for the value
                        // and the chevron together, and the chevron carries
                        // its own size.
                        .typeStyle(.body, .body, weight: .semibold)
                        .foregroundStyle(ZColor.textMuted)
                        // The title beside it is greedy, so on a narrow phone
                        // the value was offered a column two words wide and
                        // broke "45 Min" across two lines — measured on an
                        // iPhone 17 with the time budget (#36). This takes
                        // the width the value needs and leaves the rest to
                        // the title, which is the one this component already
                        // calls the better thing to wrap.
                        //
                        // It states that a value never wraps, not that it
                        // wraps last: a value long enough to want the whole
                        // row would push past it rather than break. Every
                        // value in this system is one short phrase — "Kein
                        // Limit", "45 Min", "Deutsch" — which is what makes
                        // that the cheaper promise. `layoutPriority(1)` is
                        // the softer one if a long value ever turns up.
                        .fixedSize(horizontal: true, vertical: false)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                // A `.plain` button does not dim when it is disabled, so a row
                // that is on the screen before it is live would still look
                // tappable. The system has one disabled opacity and every
                // pressable already uses it; this is the same one. Only the
                // navigation row needs it — `Toggle` greys itself.
                .opacity(isEnabled ? 1 : LedgeButtonStyle.disabledOpacity)

            case let .toggle(isOn):
                Toggle(isOn: isOn) {
                    row { EmptyView() }
                }
                .toggleStyle(.switch)
                .tint(ZColor.primary)
                // A plain `Toggle` publishes two switches, not one: its own
                // element, named after the row, and the system switch inside
                // it, named after nothing. Standing in a bare `Toggle` for the
                // whole row replaces the subtree rather than relabelling it,
                // so exactly one switch is left — same trait, same on/off
                // value, same activation, and now with a name. The hint goes
                // where a hint belongs; an empty one is no hint, so a row
                // without one is announced by its name alone.
                .accessibilityRepresentation {
                    Toggle(title, isOn: isOn)
                        .accessibilityHint(hint ?? "")
                }
            }
        }
        .padding(.horizontal, ZSpacing.step5)
        .frame(minHeight: ZSpacing.touchMinimum)
        .background(ZColor.surfaceCard)
        .overlay(alignment: .bottom) {
            if showsSeparator {
                ZColor.borderCard
                    .frame(height: SettingRowMetrics.separatorWidth)
            }
        }
    }

    /// Icon, title and hint. The trailing slot differs per variant: the
    /// navigation row fills it with value and chevron, the switch row leaves
    /// it to `Toggle`, which places the switch itself.
    ///
    /// ``SettingRowStack`` decides how the four sit: the design's three
    /// columns on an iPad, stacked on a phone. A switch row hands it an empty
    /// trailing slot and so never stacks one — the switch is `Toggle`'s to
    /// place, on the middle of whatever the label turns out to be, exactly as
    /// Settings.app does it.
    private func row(@ViewBuilder trailing: () -> some View) -> some View {
        SettingRowStack(
            sizeClass: horizontalSizeClass,
            typeSize: dynamicTypeSize,
            spacing: ZSpacing.step4,
            hintSpacing: SettingRowMetrics.hintSpacing,
        ) {
            // Four slots, always all four, and each optional one wrapped: a
            // `Layout` never sees an `EmptyView` — SwiftUI drops it before
            // the layout runs — and a missing slot would shift every other
            // one onto the wrong place.
            HStack(spacing: 0) {
                if let icon {
                    Icon(icon, size: .standard)
                        .foregroundStyle(ZColor.olive600)
                }
            }

            Text(title)
                // Not `singleLine`, even though a title is one line in
                // practice. Nunito's box is smaller than the design's here,
                // so the frame would add 2.7 pt inside a row that
                // `--touch-min` already holds at 64 — invisible — while the
                // `lineLimit(1)` that comes with it would truncate a long
                // setting name. Wrapping is the better failure in the one
                // area that uses full sentences.
                .typeStyle(.body, .body, weight: .bold)
                .foregroundStyle(ZColor.textStrong)

            HStack(spacing: 0) {
                if let hint {
                    Text(hint)
                        // Explanatory copy, and the one string in the system
                        // that regularly runs to two lines.
                        .typeStyle(.caption, .body, weight: .semibold)
                        .foregroundStyle(ZColor.textMuted)
                }
            }

            HStack(spacing: 0) { trailing() }
        }
        // Pins the row to the height its paragraphs need, so that no ancestor
        // can compress it — a `Toggle` label in particular gets what the
        // switch leaves over. Nothing observed today asks for less; this
        // states what the row is entitled to.
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, ZSpacing.step4)
    }
}

/// The row's measurements. The values without a token are the JSX's own
/// literals, named here rather than spelled out inside the view.
///
/// The two icon sizes are not among them: the JSX draws them at 28 px and
/// 22 px, and both snap to the nearest ``Icon/Size`` preset rather than
/// introducing a `.custom` size per call site.
enum SettingRowMetrics {
    /// The gap between title and hint.
    ///
    /// Not the JSX's `marginTop: 2`, which assumes a title that stays on one
    /// line. A title still wraps — a long one, or the hint under it running to
    /// two lines — and at 2 pt the second line of the title sits *closer* to
    /// the hint than to the line above it, which SwiftUI separates by
    /// ``ZType/Step/lineSpacing(for:)``, 2.7 pt at the body step. The two then
    /// read as one run-on block. A step of the scale is the smallest gap that
    /// reads as a break; `NavigationComponentTests` holds it above the title's
    /// own line spacing.
    ///
    /// ``SettingRowStack`` leaves it wherever it stacks something inside a
    /// row, the trailing line of a phone row included.
    static let hintSpacing: CGFloat = ZSpacing.step2
    /// `borderBottom: 2px` — a hairline inside a card, thinner than
    /// ``ZBorder/width``, which outlines the card itself.
    static let separatorWidth: CGFloat = 2
}

// MARK: - Previews

/// Preview only. It is a view rather than a plain `#Preview` body because the
/// switches need `@State`, which a macro closure cannot hold; the German
/// strings below are sample copy, exactly as in a `#Preview` block, and never
/// reach a screen.
private struct SettingRowPreviewCard: View {
    @State private var calls = true
    @State private var music = false
    @State private var names = true

    var body: some View {
        VStack(spacing: 0) {
            SettingRow(
                title: "Vogelstimmen",
                hint: "Echte Aufnahmen aus der Sammlung",
                icon: .volume2,
                isOn: $calls,
            )
            SettingRow(
                title: "Hintergrundmusik",
                hint: "Leise Waldgeräusche zwischen den Runden",
                icon: .music,
                isOn: $music,
            )
            SettingRow(title: "Namen anzeigen", icon: .type, isOn: $names)
            SettingRow(
                title: "Spielzeit pro Tag",
                hint: "Danach schlafen die Vögel",
                icon: .clock,
                value: "20 Min",
            ) {}
            SettingRow(title: "Sprache", icon: .languages, value: "Deutsch") {}
            SettingRow(
                title: "Fotos & Dank",
                icon: .camera,
                value: "10 Fotos",
                showsSeparator: false,
            ) {}
        }
        .background(ZColor.surfaceCard)
        .clipShape(RoundedRectangle(cornerRadius: ZRadius.card, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: ZRadius.card, style: .continuous)
                .strokeBorder(ZColor.borderCard, lineWidth: ZBorder.width)
        }
        .padding(ZSpacing.step6)
        .frame(maxWidth: ZSpacing.maxContent)
        .background(ZColor.surfacePage)
    }
}

#Preview("A card of rows") {
    SettingRowPreviewCard()
}

// The case #142 was opened for, at the width of the smallest phone the app
// runs on: an iPhone SE is 375 pt across, and behind the iPad's gutter and
// columns "Spielzeit pro Tag" was left about 54 pt of text column and broke
// over four lines. Stacked, and behind the 16 pt phone gutter, the title has
// the column to itself and "Kein Limit" takes a line of its own.
//
// The size class is set rather than left to the canvas, because the width
// alone does not carry it — and it is half of what this preview shows.
#Preview("Stacked rows at 375 pt") {
    ZCard(padding: 0) {
        VStack(spacing: 0) {
            SettingRow(
                title: "Namen anzeigen",
                hint: "Vogelnamen unter den Bildern einblenden",
                icon: .type,
                isOn: .constant(true),
            )
            SettingRow(
                title: "Spielzeit pro Tag",
                hint: "Danach schlafen die Vögel",
                icon: .clock,
                value: "Kein Limit",
                showsSeparator: false,
            ) {}
        }
    }
    .frame(width: 375 - 2 * ZSpacing.step4)
    .padding(.horizontal, ZSpacing.step4)
    .environment(\.horizontalSizeClass, .compact)
    .background(ZColor.surfacePage)
}

#Preview("Both variants, bare") {
    VStack(spacing: 0) {
        SettingRow(title: "Namen anzeigen", isOn: .constant(true))
        SettingRow(title: "Namen anzeigen", hint: "Unter den Bildern", isOn: .constant(false))
        SettingRow(title: "Sprache", value: "Deutsch") {}
        SettingRow(title: "Sprache", icon: .languages, showsSeparator: false) {}
    }
    .padding(ZSpacing.step6)
    .background(ZColor.surfacePage)
}
