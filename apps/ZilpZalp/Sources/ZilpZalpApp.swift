import SwiftUI

/// Entry point of the app.
///
/// The app target is pure wiring: it holds the scene setup and nothing else.
/// Logic belongs in `ZilpZalpCore`, data in `ZilpZalpData`, components in
/// `ZilpZalpUI`.
@main
struct ZilpZalpApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
