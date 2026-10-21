import SwiftUI
import ZilpZalpData

// The previews of ``HomeScreen``, in their own file, exactly as
// ``QuizScreen``'s are: the screen itself sits on SwiftLint's 400-line
// ceiling, and four fixed layouts are the part of it no child ever sees.

/// Three packs on the device, so there is something to choose between.
private let previewCollections: [CollectionEntry] = [
    .preview(nil, "Alle Vögel"),
    .preview("deutschland", "Vögel Deutschlands"),
    .preview("afrika", "Vögel Afrikas"),
]

#Preview("iPad landscape", traits: .fixedLayout(width: 1194, height: 834)) {
    HomeScreen(
        avatar: "feather",
        games: [.names, .calls],
        openGame: { _ in },
        openParents: {},
        openAbout: {},
        openProfiles: {},
        collections: previewCollections,
        chosenCollections: ["afrika"],
        chooseCollection: { _ in },
        openCollection: {},
    )
    .environment(\.speciesPhotos, SpeciesPhotos((try? .bundled()) ?? .empty))
    .environment(\.horizontalSizeClass, .regular)
}

#Preview("iPhone portrait", traits: .fixedLayout(width: 390, height: 844)) {
    HomeScreen(
        avatar: "feather",
        games: [.names, .calls],
        openGame: { _ in },
        openParents: {},
        openAbout: {},
        openProfiles: {},
        collections: previewCollections,
        chosenCollections: [],
        chooseCollection: { _ in },
        openCollection: {},
    )
    .environment(\.speciesPhotos, SpeciesPhotos((try? .bundled()) ?? .empty))
    .environment(\.horizontalSizeClass, .compact)
}

// The bundled pack alone: nothing to choose between, and the screen as it was
// before #187 — headline and tiles, and the tiles get every point of it.
#Preview("One pack, no collections", traits: .fixedLayout(width: 390, height: 844)) {
    HomeScreen(
        avatar: "feather",
        games: [.names, .calls],
        openGame: { _ in },
        openParents: {},
        openAbout: {},
        openProfiles: {},
        collections: [],
        chosenCollections: [],
        chooseCollection: { _ in },
        openCollection: {},
    )
    .environment(\.speciesPhotos, SpeciesPhotos((try? .bundled()) ?? .empty))
    .environment(\.horizontalSizeClass, .compact)
}

// What every device shows while no pack carries a call and until #32 curates
// them: game 1 alone, in the whole space the pair had.
#Preview("Without the calls", traits: .fixedLayout(width: 1194, height: 834)) {
    HomeScreen(
        avatar: "feather",
        games: [.names],
        openGame: { _ in },
        openParents: {},
        openAbout: {},
        openProfiles: {},
        collections: [],
        chosenCollections: [],
        chooseCollection: { _ in },
        openCollection: {},
    )
    .environment(\.speciesPhotos, SpeciesPhotos((try? .bundled()) ?? .empty))
    .environment(\.horizontalSizeClass, .regular)
}
