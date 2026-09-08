import SwiftUI

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
    let model: AppModel

    @State private var isCreating = false

    var body: some View {
        if model.profiles.isEmpty || isCreating {
            ProfileCreationScreen(
                canGoBack: !model.profiles.isEmpty,
                back: { isCreating = false },
                create: { name, avatar in
                    await model.create(name: name, avatar: avatar)
                },
            )
        } else {
            ProfilePickerScreen(
                profiles: model.profiles,
                choose: { model.select($0) },
                createNew: { isCreating = true },
            )
        }
    }
}
