/// Type-safe names for the icon glyphs vendored from [Lucide](https://lucide.dev)
/// 1.28.0 into `Resources/Icons.xcassets`. Each case's raw value matches both
/// the upstream icon name and the `.imageset` it resolves to, so there is
/// never a hand-typed string between a component and its glyph.
///
/// To add an icon: fetch its SVG from the pinned Lucide tag, drop it into a
/// new `<name>.imageset` next to the others (template rendering, preserved
/// vector data — copy an existing `Contents.json`), then add a case here.
/// `IconAssetCatalogTests` fails the build if the imageset is missing or
/// incomplete.
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
    case languages
    case leaf
    case lightbulb
    case lock
    case map
    case music
    case partyPopper = "party-popper"
    case play
    case plus
    case rotateCcw = "rotate-ccw"
    case shieldCheck = "shield-check"
    case sparkles
    case star
    case type
    case userRoundCog = "user-round-cog"
    case volume2 = "volume-2"
}
