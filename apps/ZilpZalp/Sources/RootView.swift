import SwiftUI

/// Platzhalter, bis der Startbildschirm aus M1 kommt.
///
/// Der Text steht im String Catalog, nicht im Code — siehe
/// `Resources/Localizable.xcstrings`.
struct RootView: View {
    var body: some View {
        Text("app.name")
            .font(.largeTitle)
    }
}
