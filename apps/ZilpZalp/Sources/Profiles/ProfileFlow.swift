import SwiftUI
import ZilpZalpData

/// The two profile screens, and the one piece of state that decides which of
/// them is on screen.
///
/// Deliberately not a ``Route``. The shell's question is only ever "is a child
/// chosen yet?", and nothing outside this flow navigates to either screen —
/// so the picker and the creation screen are one destination as far as
/// ``RootView`` is concerned, and `Route.swift` stays as it was.
///
/// With no profiles at all the creation screen *is* this flow: there is
/// nothing to pick from, so the picker is skipped and there is nowhere to go
/// back to.
struct ProfileFlow: View {
    /// What is on screen. Editing is the creation screen filled in with the
    /// child whose pencil was tapped (#258): a second form would drift from
    /// the first.
    private enum Mode {
        case picking
        case creating
        case editing(Profile)
    }

    let model: AppModel

    @State private var mode = Mode.picking

    private var editing: Profile? {
        if case let .editing(profile) = mode {
            profile
        } else {
            nil
        }
    }

    var body: some View {
        if case .picking = mode, !model.profiles.isEmpty {
            ProfilePickerScreen(
                profiles: model.profiles,
                choose: { model.select($0) },
                edit: { mode = .editing($0) },
                createNew: { mode = .creating },
            )
        } else {
            ProfileCreationScreen(
                // The avatars are birds of the open packs, and the grid names
                // and speaks each of them (#205).
                library: model.packs.library,
                editing: editing,
                canGoBack: !model.profiles.isEmpty,
                back: { mode = .picking },
                save: { [editing] name, avatar in
                    if let editing {
                        await model.edit(editing.id, name: name, avatar: avatar)
                        mode = .picking
                    } else {
                        await model.create(name: name, avatar: avatar)
                    }
                },
            )
            // A fresh screen per child, so one child's name never stays in
            // the field when the next one's pencil is tapped.
            .id(editing?.id)
        }
    }
}
