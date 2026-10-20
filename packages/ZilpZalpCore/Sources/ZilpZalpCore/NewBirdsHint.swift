/// When the grown-ups' button on the home screen says "Neue Vögel" (#262): a
/// child who has collected most of the birds on the device is ready for more.
///
/// Counted from stickers rather than from rounds, and by count rather than by
/// how a sticker is earned — that is the profile's business and a grown-up's
/// setting. What is shown is a badge without words; the child is told nothing.
public enum NewBirdsHint {
    /// Four in five of the installed species.
    ///
    /// - Parameters:
    ///   - collected: stickers the child holds of the installed species.
    ///   - total: installed species, each one counted once.
    public static func isDue(collected: Int, of total: Int) -> Bool {
        total > 0 && collected * 5 >= total * 4
    }
}
