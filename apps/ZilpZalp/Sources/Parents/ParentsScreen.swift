import SwiftUI

/// Replaced by #35 — the grown-ups' area behind its `LAContext` lock.
///
/// Unlocked while it is empty: the lock, the time budget, the pack management
/// and the credits all arrive with #35, and a lock in front of an empty room
/// would only be a lock to test. The door sits on the home screen from the
/// start because the design puts it in the same corner of every screen.
struct ParentsScreen: View {
    var body: some View {
        PlaceholderScreen(title: String(localized: "parents.title"), icon: .shieldCheck)
    }
}

#Preview {
    NavigationStack {
        ParentsScreen()
    }
}
