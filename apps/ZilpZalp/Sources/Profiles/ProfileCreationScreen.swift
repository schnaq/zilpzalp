import SwiftUI
import ZilpZalpData
import ZilpZalpUI

/// "Wie heißt du?" — screen 1g: a name and one of eight avatars.
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

    /// One avatar in the grid. 1g draws 118 pt across four columns; 104 is
    /// what lets the headline, the field, two rows of eight and "Los!" all
    /// stand on a landscape iPad at once. A form a grown-up has to scroll to
    /// find the confirm button in is a form that looks broken, and 104 pt is
    /// still two thirds again the size of anything a child must hit.
    private static let discDiameter: CGFloat = 104
    private static let compactDiscDiameter: CGFloat = 76

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
        .readAloudOnce(String(localized: "profile.create.title"))
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

    /// Exactly the eight choices the store knows about, in its order — the
    /// grid follows `Profile.avatarChoices` rather than a second list here, so
    /// a ninth choice appears without anyone remembering to add it twice.
    private var avatarGrid: some View {
        let diameter = isCompact ? Self.compactDiscDiameter : Self.discDiameter

        return LazyVGrid(
            columns: [
                GridItem(.adaptive(minimum: diameter), spacing: ZSpacing.gapTiles),
            ],
            spacing: ZSpacing.gapTiles,
        ) {
            ForEach(Profile.avatarChoices, id: \.self) { choice in
                let style = AvatarStyle.avatar(choice)

                Button {
                    chosenAvatar = choice
                    // The bird is the last thing a child picks; taking the
                    // keyboard away here is what makes the button below
                    // visible on an iPhone at the moment it turns on.
                    nameFocused = false
                } label: {
                    AvatarDisc(
                        style: style,
                        diameter: diameter,
                        chosen: chosenAvatar == choice,
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(style.name))
                .accessibilityAddTraits(chosenAvatar == choice ? [.isSelected] : [])
            }
        }
        // Four across at the design's size, as in 1g: four discs plus the
        // three gaps between them, and not a point more — an extra gap's worth
        // of width here is what silently drops the grid to three columns and
        // pushes "Los!" off the bottom of a landscape iPad. Narrower screens
        // take fewer columns on their own. The ring around the chosen avatar
        // needs the padding not to be clipped by the row above.
        .frame(maxWidth: 4 * diameter + 3 * ZSpacing.gapTiles)
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
    ProfileCreationScreen(canGoBack: true, back: {}, create: { _, _ in })
        .environment(\.horizontalSizeClass, .regular)
}

#Preview("iPhone portrait, first launch", traits: .fixedLayout(width: 390, height: 844)) {
    ProfileCreationScreen(canGoBack: false, back: {}, create: { _, _ in })
        .environment(\.horizontalSizeClass, .compact)
}
