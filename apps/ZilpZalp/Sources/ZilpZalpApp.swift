import SwiftUI

/// Einstiegspunkt der App.
///
/// Das App-Target ist reine Verdrahtung: Es hält den Szenen-Aufbau und sonst
/// nichts. Logik gehört nach `ZilpZalpCore`, Daten nach `ZilpZalpData`,
/// Komponenten nach `ZilpZalpUI`.
@main
struct ZilpZalpApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
