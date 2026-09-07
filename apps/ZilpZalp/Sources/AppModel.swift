import os
import ZilpZalpData

/// What the shell knows: the species pack that ships inside the app.
///
/// Opened once at launch rather than when a game starts. A pack that cannot be
/// read is a broken build, and a broken build should say so on a calm screen
/// instead of dropping a child into a round with no birds in it. `try!` would
/// turn the same mistake into a crash on a child's iPad, which is why the
/// failure is a `nil` here and a sentence there.
///
/// There is exactly one profile in M3 — no picker, no store. The profile
/// choice (#28) slots in front of the home screen in M4.
///
/// Not `@Observable`: everything here is decided once in `init` and never
/// changes, so there is nothing to observe. The first screen that keeps state
/// — the quiz (#25) — adds the macro along with the `var` that needs it.
final class AppModel {
    /// `nil` only when `Bundle.module` carries no manifest, which
    /// `mise run check` already guards through `tools/sync_bundled_packs.py`.
    let catalog: PackCatalog?

    init() {
        do {
            catalog = try PackCatalog.bundled()
        } catch {
            catalog = nil
            let reason = String(describing: error)
            Logger.packs.error("Bundled pack did not open: \(reason, privacy: .public)")
        }
    }
}

private extension Logger {
    /// Opening and reading species packs.
    ///
    /// Same subsystem as `Logger.audio`: the app's bundle identifier from
    /// `project.yml`. Two copies of that string do not yet justify moving
    /// #24's declaration out of `Audio/` — the third area that logs should
    /// pull it into one constant and take both along.
    static let packs = Logger(subsystem: "com.schnaq.zilpzalp", category: "packs")
}
