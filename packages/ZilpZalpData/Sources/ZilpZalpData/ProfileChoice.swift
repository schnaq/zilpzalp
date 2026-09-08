/// Which child the app opens on.
///
/// Its own type rather than a method on ``ProfileStore``: the rule reads
/// profiles, it does not touch the file, and keeping it out of the actor is
/// what lets it be tested without a directory (#28).
public enum ProfileChoice {
    /// The profile a launch should make active, or `nil` when the app has to
    /// ask — which means either the picker or, with nothing saved yet, the
    /// creation screen.
    ///
    /// The remembered child wins over the count, so a restart lands where the
    /// iPad was put down. `remembered` is checked against `profiles` rather
    /// than trusted: a profile deleted on another day must not select an id
    /// that is no longer there.
    ///
    /// Without a remembered child the count decides — nobody yet, exactly one
    /// (no point asking a question with one answer), or several.
    ///
    /// **Launch only.** A family with one profile still has to reach "Neues
    /// Nest", and they reach it through the picker the shell opens when the
    /// active profile is cleared. If this rule ran there too it would put that
    /// one child straight back and a second could never be created.
    ///
    /// - Parameters:
    ///   - profiles: Everything the store holds, in its order.
    ///   - remembered: The id this device last had active, if any.
    public static func atLaunch(
        among profiles: [Profile],
        remembered: Profile.ID?,
    ) -> Profile.ID? {
        if let remembered, profiles.contains(where: { $0.id == remembered }) {
            return remembered
        }
        return profiles.count == 1 ? profiles.first?.id : nil
    }
}
