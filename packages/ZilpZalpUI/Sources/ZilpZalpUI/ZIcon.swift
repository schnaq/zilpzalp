/// Type-safe names for the icon glyphs vendored from [Lucide](https://lucide.dev)
/// 1.28.0 into `Resources/Icons.xcassets`. Each case's raw value matches the
/// `.imageset` it resolves to, so there is never a hand-typed string between a
/// component and its glyph, and — except where a case is a derivative of ours,
/// like ``starFilled``, which says so in its own doc comment — it matches the
/// upstream icon name as well.
///
/// To add an icon: fetch its SVG from the pinned Lucide tag, drop it into a
/// new `<name>.imageset` next to the others (template rendering, preserved
/// vector data — copy an existing `Contents.json`), then add a case here. A
/// variant of an icon we already have starts from the vendored SVG instead of
/// from upstream, so the two stay the same glyph. `IconAssetCatalogTests`
/// fails the build if the imageset is missing or incomplete.
///
/// Licensing: `Resources/Licenses/LICENSE-lucide.txt` carries Lucide's ISC
/// notice and, for the subset of these icons derived from the Feather icon
/// set, Feather's MIT notice — both required, neither hand-copied here.
public enum ZIcon: String, CaseIterable, Sendable {
    case album
    case arrowRight = "arrow-right"
    case bird
    case camera
    case check
    case chevronLeft = "chevron-left"
    case chevronRight = "chevron-right"
    case clock
    case egg
    case feather
    case handHeart = "hand-heart"
    case house
    case info
    case languages
    case leaf
    case lightbulb
    case lock
    case mail
    case map
    case music
    case partyPopper = "party-popper"
    case play
    case plus
    case rotateCcw = "rotate-ccw"
    case shieldCheck = "shield-check"
    case sparkles
    case star
    /// `star` filled rather than hollow, for a place that shows earned next to
    /// unearned and may not tell them apart by colour alone. Not an upstream
    /// name: it is `star.svg` with `fill="none"` changed to
    /// `fill="currentColor"` on the root, nothing else — same path, same
    /// stroke, same outer size, so a filled and a hollow star sit in a row
    /// without one of them growing. Lucide's ISC notice covers the change.
    case starFilled = "star-filled"
    case type
    case userRoundCog = "user-round-cog"
    case volume2 = "volume-2"
}
