import SwiftUI
import ZilpZalpData
import ZilpZalpUI

/// "Wie heißt du?" — screen 1g: a name and one of ten birds.
///
/// A name and an avatar, and that is the whole form. No age, no e-mail, no
/// account: the app is in the Kids Category and collects nothing, and there is
/// nothing here a family could later be asked to justify.
///
/// The typing is a grown-up's or an older sibling's job — a four-year-old
/// picks the bird. So the field takes the plain keyboard with autocorrection
/// off (a child's name is not in any dictionary) and the avatars are the
/// biggest thing on the screen.
struct ProfileCreationScreen: View {
    /// One first name. Long enough for "Charlotte" and for a nickname a family
    /// invented; short enough that the name still fits on a picker card and in
    /// the pill below without scrolling under the typist's fingers.
    private static let nameLimit = 20

    /// The field from 1g: 440 × 88.
    private static let fieldWidth: CGFloat = 440
    private static let fieldHeight: CGFloat = 88

    /// The wordmark that stands in for the back button on the first launch.
    private static let wordmarkSize: CGFloat = 52

    /// One bird in the grid. 1g draws 118 pt across four columns; 104 is
    /// what lets the headline, the field, two rows of five and "Los!" all
    /// stand on a landscape iPad at once. A form a grown-up has to scroll to
    /// find the confirm button in is a form that looks broken, and 104 pt is
    /// still two thirds again the size of anything a child must hit.
    private static let discDiameter: CGFloat = 104
    private static let compactDiscDiameter: CGFloat = 76

    /// The birds a child can pick from — the avatars are species of the pack
    /// that ships inside the app (#205), and this is what puts a name to each
    /// of them. Empty in a build whose pack did not open, which leaves the
    /// grid wordless and silent rather than the screen broken.
    let library: PackLibrary

    /// Whether there is anywhere to go back to. False when this screen is the
    /// app's root — the very first launch, no profile yet — because a back
    /// button that leads nowhere is a button a child will press.
    let canGoBack: Bool
    let back: () -> Void
    let create: (String, String) async -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var name = ""
    @State private var chosenAvatar: String?

    /// Shuts the confirm button while the store is being written, so a double
    /// tap cannot make two children out of one.
    @State private var isSaving = false

    /// Says a bird's name when its disc is tapped, so a child who cannot read
    /// hears what it is picking. One announcer for the screen, and built on
    /// the first tap rather than with the screen — it needs the packs the
    /// recorded names lie in, and a `@State` default is evaluated again every
    /// time the view struct is rebuilt. ``CollectionScreen`` and
    /// ``CollectionPicker`` do it the same way.
    @State private var announcer: SpeechAnnouncer?

    @FocusState private var nameFocused: Bool

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canConfirm: Bool {
        !trimmedName.isEmpty && chosenAvatar != nil && !isSaving
    }

    /// The avatars to draw, each with the bird it names. `nil` for a bird no
    /// open pack carries, which is a broken build rather than a state to
    /// design for: the disc then shows the glyph and says nothing.
    private var choices: [(id: String, bird: Bird?)] {
        // Ten searches through the open packs rather than a dictionary of all
        // of them: this is read on every keystroke in the name field, and
        // building a map of seventy birds to ask it ten questions is the more
        // expensive half of that.
        Profile.avatarChoices.map { choice in
            (choice, library.birds.first { $0.id == choice })
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(leading: { barContent })

            ScrollView {
                VStack(spacing: ZSpacing.step5) {
                    Text("profile.create.title")
                        .typeStyle(
                            isCompact ? .headline : .display2,
                            .display,
                            weight: .extraBold,
                        )
                        .foregroundStyle(ZColor.textStrong)
                        .multilineTextAlignment(.center)

                    nameField

                    Text("profile.create.avatar.title")
                        .typeStyle(isCompact ? .bodyLarge : .headline, .display, weight: .bold)
                        .foregroundStyle(ZColor.textBody)
                        .multilineTextAlignment(.center)

                    avatarGrid

                    confirmButton
                        .padding(.top, ZSpacing.step2)
                }
                .frame(maxWidth: ZSpacing.maxContent)
                .padding(.horizontal, ZSpacing.gutterScreen)
                .padding(.vertical, ZSpacing.step6)
                .frame(maxWidth: .infinity)
            }
            // The avatars sit under the keyboard on an iPhone; swiping the
            // grid should put the keyboard away rather than fight it.
            .scrollDismissesKeyboard(.interactively)
        }
        .background(ZColor.surfacePage)
        .readAloudOnce(.fixed("profile.create.title"))
        .onDisappear { announcer?.stop() }
    }

    /// The back button, or the brand where there is nothing to go back to.
    ///
    /// On the very first launch this screen is the app's root, so an empty bar
    /// would be the first thing anyone ever sees of ZilpZalp. The wordmark is
    /// better company than a blank strip, and it costs a child nothing: they
    /// are looking at the birds.
    @ViewBuilder private var barContent: some View {
        if canGoBack {
            IconButton(
                .chevronLeft,
                label: String(localized: "nav.back.accessibility"),
                tone: .quiet,
                diameter: ZSpacing.touchMinimum,
                action: back,
            )
            // Shut while the profile is being written, like the confirm
            // button. Leaving on it would drop the picker in front of a write
            // that is still running, and the finished write would then throw
            // the new child's home screen over the top of it.
            .disabled(isSaving)
        } else {
            Wordmark(size: isCompact ? Wordmark.minimumSize : Self.wordmarkSize)
        }
    }

    /// The name pill. The placeholder doubles as the field's VoiceOver label,
    /// which is why the title is a real key and not an empty string.
    private var nameField: some View {
        TextField("profile.create.name.placeholder", text: $name)
            .textFieldStyle(.plain)
            .focused($nameFocused)
            // No autocorrection: a child's name is not in the dictionary and
            // being "corrected" into a word is how Mira becomes Mirage. No
            // `textContentType` either — it would open the address book on a
            // device that belongs to a family, and this app asks for one word.
            .autocorrectionDisabled()
            .textInputAutocapitalization(.words)
            .submitLabel(.done)
            .onSubmit { nameFocused = false }
            .onChange(of: name) { _, typed in
                if typed.count > Self.nameLimit {
                    name = String(typed.prefix(Self.nameLimit))
                }
            }
            .typeStyle(.title, .display, weight: .bold, singleLine: true)
            .foregroundStyle(ZColor.textStrong)
            .multilineTextAlignment(.center)
            .padding(.horizontal, ZSpacing.step5)
            .frame(maxWidth: Self.fieldWidth, minHeight: Self.fieldHeight)
            .background(Capsule().fill(ZColor.surfaceCard))
            .overlay(Capsule().strokeBorder(ZColor.borderStrong, lineWidth: ZBorder.width))
    }

    /// Exactly the ten choices the store knows about, in its order — the grid
    /// follows `Profile.avatarChoices` rather than a second list here, so an
    /// eleventh choice appears without anyone remembering to add it twice.
    private var avatarGrid: some View {
        let diameter = isCompact ? Self.compactDiscDiameter : Self.discDiameter

        return LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: diameter), spacing: ZSpacing.gapTiles),
            ],
            spacing: ZSpacing.gapTiles,
        ) {
            ForEach(choices, id: \.id) { choice in
                Button {
                    chosenAvatar = choice.id
                    // The bird is the last thing a child picks; taking the
                    // keyboard away here is what makes the button below
                    // visible on an iPhone at the moment it turns on.
                    nameFocused = false
                    // And it says which bird that was, because the child
                    // picking it cannot read the name anywhere.
                    if let bird = choice.bird {
                        say(.name(bird))
                    }
                } label: {
                    AvatarDisc(
                        style: .avatar(choice.id),
                        diameter: diameter,
                        chosen: chosenAvatar == choice.id,
                    )
                }
                .buttonStyle(.plain)
                // The bird's name from the manifest, not from the String
                // Catalog: the pack is where a species is named, and the
                // credits are generated from the same document. For the
                // grown-up who cannot see — the child goes by the photo.
                .accessibilityLabel(Text(verbatim: choice.bird?.name ?? choice.id))
                .accessibilityAddTraits(chosenAvatar == choice.id ? [.isSelected] : [])
            }
        }
        // Five across rather than the four of 1g, which drew eight avatars in
        // two rows: ten birds across four columns is three rows, and the third
        // one pushes "Los!" off the bottom of a landscape iPad — a form a
        // grown-up has to scroll to find the confirm button in is a form that
        // looks broken. Five discs plus the four gaps between them and not a
        // point more (616 pt, inside the 864 the gutters leave an iPad in
        // portrait). Narrower screens take fewer columns on their own. The ring
        // around the chosen avatar needs the padding not to be clipped by the
        // row above.
        .frame(maxWidth: 5 * diameter + 4 * ZSpacing.gapTiles)
        .padding(.vertical, ZShadow.focusRingWidth)
    }

    private var confirmButton: some View {
        ZButton(
            String(localized: "profile.create.confirm"),
            tone: .primary,
            size: .large,
            action: confirm,
        )
        .disabled(!canConfirm)
    }

    /// Says one line, building the announcer the first time a bird is tapped
    /// and keeping it afterwards, so the next name cuts the last one off
    /// instead of talking over it.
    private func say(_ line: SpokenLine) {
        let voice = announcer ?? SpeechAnnouncer(library: library)
        announcer = voice
        voice.announce(line)
    }

    private func confirm() {
        guard let chosenAvatar, canConfirm else { return }

        isSaving = true
        nameFocused = false
        let named = trimmedName

        Task {
            await create(named, chosenAvatar)
            isSaving = false
        }
    }
}

// MARK: - Previews

#Preview("iPad landscape", traits: .fixedLayout(width: 1194, height: 834)) {
    ProfileCreationScreen(
        library: (try? .bundled()) ?? .empty,
        canGoBack: true,
        back: {},
        create: { _, _ in },
    )
    .environment(\.horizontalSizeClass, .regular)
    .environment(\.speciesPhotos, SpeciesPhotos((try? .bundled()) ?? .empty))
}

#Preview("iPhone portrait, first launch", traits: .fixedLayout(width: 390, height: 844)) {
    ProfileCreationScreen(
        library: (try? .bundled()) ?? .empty,
        canGoBack: false,
        back: {},
        create: { _, _ in },
    )
    .environment(\.horizontalSizeClass, .compact)
    .environment(\.speciesPhotos, SpeciesPhotos((try? .bundled()) ?? .empty))
}
