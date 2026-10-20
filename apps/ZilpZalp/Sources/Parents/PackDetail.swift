import SwiftUI
import ZilpZalpUI

/// Every bird of one pack, as the album would show them (#262): what a grown-up
/// looks at before deciding whether this is the pack a child asked for.
///
/// A sheet rather than a pushed screen: the grown-ups' door shuts whenever its
/// screen leaves the display, and a push would shut it behind the parent.
struct PackDetail: View {
    let card: PackCard
    let packs: PackModel
    let play: (String) -> Void
    let close: () -> Void

    @State private var deleting = false

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: card.title) {
                IconButton(
                    .chevronLeft,
                    label: String(localized: "nav.back.accessibility"),
                    diameter: ZSpacing.touchMinimum,
                    action: close,
                )
            }

            ScrollView {
                VStack(alignment: .leading, spacing: ZSpacing.step5) {
                    Text(verbatim: card.detail)
                        .typeStyle(.body, .body, weight: .semibold)
                        .foregroundStyle(ZColor.textBody)

                    PackStateButton(card: card, packs: packs, play: play)

                    grid
                    credits

                    if card.isDeletable {
                        ZButton(
                            String(localized: "parents.packs.delete.confirm"),
                            tone: .quiet,
                            size: .medium,
                        ) { deleting = true }
                    }
                }
                .frame(maxWidth: ZSpacing.maxContent, alignment: .leading)
                .padding(isCompact ? ZSpacing.step4 : ZSpacing.gutterScreen)
                .frame(maxWidth: .infinity)
            }
            .grownUpDynamicType()
        }
        .background(ZColor.surfacePage)
        .confirmationDialog(
            "parents.packs.delete.title",
            isPresented: $deleting,
            titleVisibility: .visible,
        ) {
            Button(String(localized: "parents.packs.delete.confirm"), role: .destructive) {
                close()
                Task { await packs.delete(card.id) }
            }
            Button("parents.packs.delete.cancel", role: .cancel) {}
        } message: {
            Text(String(format: String(localized: "parents.packs.delete.message"), card.title))
        }
    }

    /// The album's grid at the album's sizes — see ``StickerGrid``. Empty
    /// for a pack whose index entry predates the previews: its card says how
    /// many birds there are, and that is all there is to say.
    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(
                .adaptive(minimum: StickerGrid.column(compact: isCompact)),
                spacing: StickerGrid.spacing(compact: isCompact),
                alignment: .top,
            )],
            spacing: StickerGrid.spacing(compact: isCompact),
        ) {
            ForEach(card.birds) { bird in
                StickerCaption(caption: bird.name, earned: true) {
                    PackSticker(
                        bird: bird,
                        packs: packs,
                        size: StickerGrid.size(compact: isCompact),
                    )
                }
            }
        }
    }

    /// Who took the photos the previews were cut from. A pack's credits reach
    /// the credits screen with the pack, so a preview shown before the download
    /// has to say it here — generated from the index, never written by hand.
    @ViewBuilder
    private var credits: some View {
        let credited = card.birds.filter { $0.credit != nil && packs.photos[$0.id] == nil }
        if !credited.isEmpty {
            VStack(alignment: .leading, spacing: ZSpacing.step1) {
                Text("parents.packs.credits")
                    .typeStyle(.caption, .body, weight: .bold)
                    .foregroundStyle(ZColor.textMuted)
                ForEach(credited) { bird in
                    Text(verbatim: "\(bird.name): \(bird.credit ?? "")")
                        .typeStyle(.caption, .body, weight: .regular)
                        .foregroundStyle(ZColor.textMuted)
                }
            }
        }
    }
}
