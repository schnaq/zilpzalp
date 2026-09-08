import SwiftUI
import ZilpZalpData
import ZilpZalpUI

/// The grown-ups' area: the one screen with small type, full sentences and
/// switches. After `design/ui_kits/ipad_app/GrownupsScreen.jsx`, minus the
/// three rows v1 has nothing behind — "Musik" (there is none), "Sprache"
/// (German only until #46) and "Pakete" (nothing to manage until #33).
///
/// A door in front of it, and the door has two keys. The device lock
/// (``ParentsLock``) is the normal one. On a device with neither a code nor a
/// face on file it cannot be asked at all, and then ``ParentalGate`` — the
/// same adult-level task the credits screen will put in front of every
/// external link (#37) — takes over, so the area is reachable on every device
/// without ever being reachable by a child.
///
/// The door falls shut again when the screen goes away or the app is put down.
struct ParentsScreen: View {
    /// What the door is doing.
    private enum Door: Hashable {
        /// Shut, with the "Entsperren" button. `refused` adds one calm line
        /// after an attempt that did not go through — never an alert, and
        /// never a second sheet on top of the first.
        case shut(refused: Bool)
        /// The device cannot be asked, so the adult-level task stands in.
        case task
        case open
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var parental = ParentalSettingsModel()
    @State private var door: Door = .shut(refused: false)
    /// Whether the credits are pushed on top. Read on the way out, so the
    /// door is not slammed behind a grown-up who only stepped into them.
    @State private var showsCredits = false
    /// True while the system sheet is up, so a second tap cannot start a
    /// second attempt behind the first.
    @State private var isAsking = false

    var body: some View {
        VStack(spacing: 0) {
            TopBar {
                IconButton(
                    .chevronLeft,
                    label: String(localized: "nav.back.accessibility"),
                    diameter: ZSpacing.touchMinimum,
                ) { dismiss() }
            } center: {
                Text("parents.title")
                    // `TopBar` offers its centre the headline step, and next
                    // to a 64 pt back button that is wider than a phone
                    // holds: measured on an iPhone 17 Pro the title wrapped
                    // to three lines and took the bar with it. The label step
                    // fits, and below the narrowest supported screen the text
                    // shrinks rather than breaks — the same step down the
                    // home screen makes with its headline.
                    //
                    // This belongs in `TopBar`, whose own documentation
                    // promises that a screen may pass a plain `Text` and get
                    // it typeset correctly. This is the first screen to take
                    // it up on that, and fixing it there is a design decision
                    // about the wordless centre as well — so it waits for a
                    // change that owns the component (#12), and this goes in
                    // the bin that day.
                    .typeStyle(
                        horizontalSizeClass == .compact ? .label : .headline,
                        .display,
                        weight: .bold,
                        singleLine: true,
                    )
                    .minimumScaleFactor(ZType.Step.caption.size / ZType.Step.label.size)
            }

            content
        }
        .background(ZColor.surfacePage)
        // Every screen brings its own `TopBar`; the system bar would stack a
        // second, smaller back button above it.
        .toolbar(.hidden, for: .navigationBar)
        // A destination of this screen rather than a `Route` case: the credits
        // are a room inside the grown-ups' area and nothing else may navigate
        // to them, least of all past the lock. #37 replaces the placeholder.
        .navigationDestination(isPresented: $showsCredits) {
            PlaceholderScreen(title: String(localized: "parents.credits.title"), icon: .camera)
        }
        .task { await parental.load() }
        .onAppear {
            // Never while the area is already open — this also runs on the way
            // back from the credits.
            guard door != .open else { return }
            door = closedDoor
        }
        .onDisappear {
            // Pushing the credits takes this screen off the screen without
            // taking anybody out of the area; relocking here would ask for the
            // code again on the way back.
            guard !showsCredits else { return }
            door = closedDoor
        }
        .onChange(of: scenePhase) { _, phase in
            // `.background` only. The system's own authentication sheet makes
            // the scene `.inactive`, and relocking on that would shut the door
            // in the middle of opening it — and recomputing on `.active` would
            // race `knock()` for the refused line it just set.
            guard phase == .background else { return }
            door = closedDoor
        }
    }

    /// The shut door as this device can present it, asked fresh every time.
    ///
    /// Fresh because a grown-up can set a device code up or take one away
    /// while the app sits in the background. And in one expression because
    /// every place that shuts the door has to agree: a handler that shut it to
    /// `.shut` on a device that cannot be asked would leave an "Entsperren"
    /// button that can only ever fail, with no way back to the task except
    /// leaving the screen and coming back.
    private var closedDoor: Door {
        ParentsLock.isAvailable ? .shut(refused: false) : .task
    }

    @ViewBuilder
    private var content: some View {
        switch door {
        case let .shut(refused):
            locked(refused: refused)
        case .task:
            // Undressed: the gate brings its own gutter, so that #37 can put
            // the same view in a sheet without repeating this.
            ParentalGate(reason: String(localized: "parents.gate.reason")) { door = .open }
        case .open:
            settings
        }
    }

    // MARK: - Shut

    private func locked(refused: Bool) -> some View {
        // Scrolls for the same reason the gate does: a stack that does not fit
        // truncates its text rather than offering a way down, and this one is
        // taller than an iPhone in landscape.
        ScrollView {
            shutDoor(refused: refused)
                .frame(maxWidth: ZSpacing.maxContent)
                .padding(ZSpacing.gutterScreen)
                .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func shutDoor(refused: Bool) -> some View {
        VStack(spacing: ZSpacing.step6) {
            Icon(.lock, size: .custom(ZSpacing.touchComfortable))
                .foregroundStyle(ZColor.textMuted)

            Text("parents.lock.explanation")
                .typeStyle(.bodyLarge, .body, weight: .semibold)
                .foregroundStyle(ZColor.textBody)

            ZButton(
                String(localized: "parents.lock.unlock"),
                size: .large,
                leadingIcon: .shieldCheck,
            ) {
                // The flag is raised here rather than inside `knock()`: the
                // action closure runs on the main actor before anything can
                // suspend, while a `Task` body waits for the next turn — long
                // enough for a second tap to slip past `disabled` and start a
                // second sheet behind the first.
                guard !isAsking else { return }
                isAsking = true
                Task { await knock() }
            }
            .disabled(isAsking)

            // Laid out whether or not it is shown, so the button does not jump
            // out from under the finger that just used it.
            Text("parents.lock.refused")
                .typeStyle(.body, .body, weight: .semibold)
                .foregroundStyle(ZColor.textMuted)
                .opacity(refused ? 1 : 0)
                .accessibilityHidden(!refused)
        }
        .multilineTextAlignment(.center)
    }

    /// One attempt. A cancelled sheet, a wrong face and a wrong code all leave
    /// the door shut and say so in one line; nothing is counted and nobody is
    /// locked out of their own settings.
    private func knock() async {
        defer { isAsking = false }

        let opened = await ParentsLock.unlock(reason: String(localized: "parents.lock.reason"))
        door = opened ? .open : .shut(refused: true)
    }

    // MARK: - Open

    private var settings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ZSpacing.step6) {
                Text("parents.intro")
                    .typeStyle(.bodyLarge, .body, weight: .semibold)
                    .foregroundStyle(ZColor.textBody)

                rows
                notice
            }
            .frame(maxWidth: ZSpacing.maxContent)
            .padding(.horizontal, ZSpacing.gutterScreen)
            .padding(.vertical, ZSpacing.step6)
            .frame(maxWidth: .infinity)
        }
    }

    private var rows: some View {
        ZCard(padding: 0) {
            VStack(spacing: 0) {
                SettingRow(
                    title: String(localized: "parents.calls.title"),
                    hint: String(localized: "parents.calls.hint"),
                    icon: .volume2,
                    isOn: switchFor(\.callsEnabled),
                )
                SettingRow(
                    title: String(localized: "parents.names.title"),
                    hint: String(localized: "parents.names.hint"),
                    icon: .type,
                    isOn: switchFor(\.showNames),
                )
                SettingRow(
                    title: String(localized: "parents.playtime.title"),
                    icon: .clock,
                    value: String(localized: "parents.playtime.none"),
                ) {}
                    // Shown so a grown-up can see the limit stands at none, and
                    // inert because setting one is #36. No copy promising it:
                    // a date nobody has committed to is not a setting. The row
                    // dims itself; the caller only says it is off.
                    .disabled(true)
                SettingRow(
                    title: String(localized: "parents.credits.title"),
                    hint: String(localized: "parents.credits.hint"),
                    icon: .camera,
                    showsSeparator: false,
                ) {
                    showsCredits = true
                }
            }
            // The rows paint their own background to the card's inner edge, so
            // without this their square corners would sit in the card's round
            // ones. Inset by the outline the card draws inside its bounds.
            //
            // Every full-bleed card will need this same arithmetic, so it
            // belongs in `ZCard` — the same seam `SettingRow` already points
            // at when it says the separator moves there once the card can
            // interleave rows itself (#12).
            .clipShape(
                RoundedRectangle(cornerRadius: ZRadius.card - ZBorder.width, style: .continuous),
            )
        }
    }

    private var notice: some View {
        ZCard(tone: .sand) {
            HStack(spacing: ZSpacing.step4) {
                Icon(.shieldCheck, size: .standard)
                    .foregroundStyle(ZColor.olive600)

                VStack(alignment: .leading, spacing: ZSpacing.step1) {
                    Text("parents.notice")
                        .typeStyle(.body, .body, weight: .bold)
                        .foregroundStyle(ZColor.textStrong)
                    Text("parents.notice.hint")
                        .typeStyle(.caption, .body, weight: .semibold)
                        .foregroundStyle(ZColor.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// One switch, reading and writing through the store. Not a `@Bindable`
    /// path into the model: an assignment has to reach the disk, and only a
    /// setter can take it there.
    private func switchFor(_ field: WritableKeyPath<ParentalSettings, Bool>) -> Binding<Bool> {
        Binding(
            get: { parental.settings[keyPath: field] },
            set: { parental.set(field, to: $0) },
        )
    }
}

#Preview("iPhone") {
    NavigationStack {
        ParentsScreen()
    }
}

#Preview("iPad", traits: .fixedLayout(width: 1194, height: 834)) {
    NavigationStack {
        ParentsScreen()
    }
}
