import SwiftUI
import ZilpZalpCore
import ZilpZalpData
import ZilpZalpUI

/// The grown-ups' area: the one screen with small type, full sentences and a
/// switch. After `design/ui_kits/ipad_app/GrownupsScreen.jsx`, minus the two
/// rows v1 has nothing behind — "Musik" (there is none) and "Sprache" (German
/// only until #46) — and minus "Vogelstimmen", the one row v1 does have
/// something behind and deliberately does not offer: where there are calls,
/// game 2 is there, and a grown-up who wants quiet turns the device down
/// (#138). The design's "Pakete" row is a card of its own here, because packs
/// are a list that changes rather than a setting — see ``PacksSection``.
///
/// A door in front of it, and the door has two keys. The device lock
/// (``ParentsLock``) is the normal one. On a device with neither a code nor a
/// face on file it cannot be asked at all, and then ``ParentalGate`` — the
/// same adult-level task that stands in front of every external link (#37) —
/// takes over, so the area is reachable on every device without ever being
/// reachable by a child.
///
/// What is *not* behind this door: the credits and everything else there is
/// to say about the app. They are public and live in ``AboutScreen``, which
/// the home screen opens without a lock (#199).
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

    /// What a day may last, `nil` first because off is the default and
    /// because a grown-up looking for the way back to no limit should find it
    /// at the top. Open decision 4 of the night plan.
    private static let limitPresets: [Int?] = [nil, 15, 30, 45, 60]

    /// The one settings model, owned by ``AppModel``: the home screen reads
    /// the daily limit off it as well, and two instances would be two
    /// answers to the same question.
    let parental: ParentalSettingsModel

    /// The packs on the device. Also owned by ``AppModel``: the games play
    /// from them, and a download that is running when a grown-up leaves this
    /// screen keeps running.
    let packs: PackModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var door: Door = .shut(refused: false)
    /// Whether the daily limit's presets are up.
    ///
    /// A dialog rather than a pushed screen on purpose: five choices do not
    /// need a screen, and a screen would take this one off the display —
    /// which is what shuts the door. A grown-up who picked "30 Minuten" would
    /// come back to "Entsperren".
    @State private var choosingLimit = false
    /// True while the system sheet is up, so a second tap cannot start a
    /// second attempt behind the first.
    @State private var isAsking = false

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: String(localized: "parents.title")) {
                IconButton(
                    .chevronLeft,
                    label: String(localized: "nav.back.accessibility"),
                    diameter: ZSpacing.touchMinimum,
                ) { dismiss() }
            }

            content
        }
        .background(ZColor.surfacePage)
        // Every screen brings its own `TopBar`; the system bar would stack a
        // second, smaller back button above it.
        .toolbar(.hidden, for: .navigationBar)
        // Out of the area the way in was: nothing here is protected on the
        // way out, and the door shuts behind the swipe exactly as it shuts
        // behind the chevron (#150).
        .swipesBack(.pops)
        // Nothing is pushed from this screen any more since the credits went
        // public (#199) — the packs and the daily limit are a sheet and a
        // dialog, and neither takes the screen off the display. So the door
        // can shut on every appearance and every disappearance, with nothing
        // to make an exception for.
        .onAppear { door = closedDoor }
        .onDisappear { door = closedDoor }
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

        // An answer that arrives after the app was put down does not open
        // anything: the scene-phase handler already shut the door, and this
        // would quietly re-open it behind a screen nobody is looking at.
        // Tested against `.background` rather than for `.active`, because the
        // system's own sheet leaves the scene `.inactive` while it is up —
        // which is exactly when the successful answer arrives.
        guard scenePhase != .background else {
            door = closedDoor
            return
        }
        door = opened ? .open : .shut(refused: true)
    }

    // MARK: - Open

    private var settings: some View {
        // The phone gutter the `TopBar` takes: 96 pt of a 390 pt phone is most
        // of a settings row's text (#93, #142). The shut door keeps the iPad's.
        let gutter = horizontalSizeClass == .compact ? ZSpacing.step4 : ZSpacing.gutterScreen
        return ScrollView {
            VStack(alignment: .leading, spacing: ZSpacing.step6) {
                Text("parents.intro")
                    .typeStyle(.bodyLarge, .body, weight: .semibold)
                    .foregroundStyle(ZColor.textBody)

                rows
                PacksSection(packs: packs)
                voiceNotice
                notice
            }
            .frame(maxWidth: ZSpacing.maxContent)
            .padding(.horizontal, gutter)
            .padding(.vertical, ZSpacing.step6)
            .frame(maxWidth: .infinity)
        }
    }

    private var rows: some View {
        ZCard(padding: 0) {
            VStack(spacing: 0) {
                SettingRow(
                    title: String(localized: "parents.names.title"),
                    hint: String(localized: "parents.names.hint"),
                    icon: .type,
                    isOn: switchFor(\.showNames),
                )
                SettingRow(
                    title: String(localized: "parents.playtime.title"),
                    hint: String(localized: "parents.playtime.hint"),
                    icon: .clock,
                    value: label(forLimit: parental.settings.dailyLimitMinutes),
                    showsSeparator: false,
                ) {
                    choosingLimit = true
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
        .confirmationDialog(
            "parents.playtime.title",
            isPresented: $choosingLimit,
            titleVisibility: .visible,
        ) {
            ForEach(Self.limitPresets, id: \.self) { minutes in
                Button(label(forLimit: minutes)) {
                    parental.set(\.dailyLimitMinutes, to: minutes)
                }
            }
            Button("parents.playtime.cancel", role: .cancel) {}
        } message: {
            Text("parents.playtime.hint")
        }
    }

    /// Which voice reads the questions, and where a better one comes from.
    ///
    /// Not a ``SettingRow``: there is nothing here to switch and nothing to
    /// open. No app may download a voice, so the only honest thing this screen
    /// can do is name the one in use and say where Settings keeps the others.
    /// It borrows the shape of ``notice`` below and leaves that one the sand
    /// tint, so the sentence about data collection stays the one that stands
    /// out.
    ///
    /// No link into Settings: `App-Prefs:` deep links into a specific pane are
    /// undocumented, and an app in the Kids Category has no business finding
    /// out how App Review feels about one.
    private var voiceNotice: some View {
        ZCard {
            HStack(spacing: ZSpacing.step4) {
                Icon(.volume2, size: .standard)
                    .foregroundStyle(ZColor.olive600)

                VStack(alignment: .leading, spacing: ZSpacing.step1) {
                    Text(verbatim: voiceName)
                        .typeStyle(.body, .body, weight: .bold)
                        .foregroundStyle(ZColor.textStrong)
                    Text("parents.voice.hint")
                        .typeStyle(.caption, .body, weight: .semibold)
                        .foregroundStyle(ZColor.textMuted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    /// "Vorlesestimme: Anna (Standard)", or the plain heading on a device
    /// whose voice the app did not choose — then the name would be a guess.
    private var voiceName: String {
        guard let voice = SpeechVoice.chosen else {
            return String(localized: "parents.voice.unknown")
        }
        return String(
            format: String(localized: "parents.voice.title"),
            voice.name,
            qualityName(voice.quality),
        )
    }

    /// The three tiers as Settings names them in German.
    private func qualityName(_ quality: SpeechVoiceQuality) -> String {
        switch quality {
        case .standard: String(localized: "parents.voice.quality.standard")
        case .enhanced: String(localized: "parents.voice.quality.enhanced")
        case .premium: String(localized: "parents.voice.quality.premium")
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

    /// One preset, in the row and in the dialog — one spelling, so the value
    /// a grown-up picked reads back exactly as it was offered.
    private func label(forLimit minutes: Int?) -> String {
        guard let minutes else { return String(localized: "parents.playtime.none") }
        return String(format: String(localized: "parents.playtime.minutes"), minutes)
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
        ParentsScreen(
            parental: ParentalSettingsModel(),
            packs: PackModel(directory: .temporaryDirectory),
        )
    }
}

#Preview("iPad", traits: .fixedLayout(width: 1194, height: 834)) {
    NavigationStack {
        ParentsScreen(
            parental: ParentalSettingsModel(),
            packs: PackModel(directory: .temporaryDirectory),
        )
    }
}
