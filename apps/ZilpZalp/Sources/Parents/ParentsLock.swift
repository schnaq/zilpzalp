import LocalAuthentication

/// The device's own lock, in front of the grown-ups' area.
///
/// The policy is `.deviceOwnerAuthentication` and never
/// `.deviceOwnerAuthenticationWithBiometrics`: the first one falls back to the
/// device code by itself, the second one shuts out every device without Face
/// ID or Touch ID — a family iPad with a passcode and nothing else included.
///
/// This lock guards the door to the settings, and only that. It is *not* the
/// parental gate Guideline 1.3 asks for in front of an external link: that one
/// tests whether the person is cognitively an adult, this one tests whether
/// they own the device. ``ParentalGate`` does the other job, and stands in for
/// this one on a device that has neither a code nor a face on file — see
/// `docs/kids-category.md` §2.
///
/// A namespace rather than an object: there is nothing to remember between two
/// attempts. Every attempt gets a fresh `LAContext` on purpose — a context
/// re-used after a success answers the second call from its own cache, which
/// would turn "unlock again" into "no question asked".
@MainActor
enum ParentsLock {
    /// Whether this device can be asked at all — read fresh every time the
    /// locked screen appears, because a grown-up can set up or remove a device
    /// code while the app is in the background.
    ///
    /// `false` means no code and no biometry. Then there is no door to knock
    /// on and ``ParentalGate`` takes over, so the area is never unreachable.
    static var isAvailable: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil)
    }

    /// One attempt, one tap.
    ///
    /// - Parameter reason: Shown in the system's own sheet. Mandatory and
    ///   non-empty — `LAContext` raises an exception otherwise.
    /// - Returns: `true` only when the device said yes. A cancelled sheet, a
    ///   wrong face and a wrong code are all the same answer here: the door
    ///   stays shut, the screen says so calmly, and the grown-up may tap
    ///   again. Nothing counts attempts and nothing locks anybody out.
    static func unlock(reason: String) async -> Bool {
        let context = LAContext()
        return await withCheckedContinuation { continuation in
            // The callback form, not the `async` bridge: `LAContext` is not
            // `Sendable`, and this way it never leaves the main actor — the
            // reply block captures nothing but the continuation.
            //
            // The error is dropped rather than logged. It carries the reason a
            // grown-up's authentication failed, which is nothing this app has
            // any business writing into a device log.
            context
                .evaluatePolicy(
                    .deviceOwnerAuthentication,
                    localizedReason: reason,
                ) { succeeded, _ in
                    continuation.resume(returning: succeeded)
                }
        }
    }
}
