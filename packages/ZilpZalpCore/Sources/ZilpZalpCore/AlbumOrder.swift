/// The order the sticker album lays its birds out in (#204).
///
/// Everything already found stands at the top. A manifest orders its species
/// for the pack, not for one child, so the two birds a child has collected sat
/// wherever they happened to fall — in the playtest album, in the third row
/// between locked ones. What a child has earned is what the album is opened
/// for, and it should be the first thing on the page.
///
/// Generic over the item, because Core owns no data model: the app's `Bird`
/// lives in `ZilpZalpData` and the rule is the same for anything with a
/// found/not-yet-found split.
public enum AlbumOrder {
    /// `items` with everything ``earned`` first, then the rest.
    ///
    /// Stable within each group: the manifest's order survives, so a child
    /// finds a bird where it stood yesterday. Only the two groups move.
    public static func earnedFirst<Item>(
        _ items: [Item],
        earned: (Item) -> Bool,
    ) -> [Item] {
        items.filter(earned) + items.filter { !earned($0) }
    }
}
