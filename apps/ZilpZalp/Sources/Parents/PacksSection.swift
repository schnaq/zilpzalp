import SwiftUI
import ZilpZalpData
import ZilpZalpUI

/// The pack gallery: the first section of the grown-ups' area (#262). One
/// card per pack with three of its birds as stickers, what it holds and costs,
/// and one button that carries its state. A tap on the card opens every bird of
/// the pack in ``PackDetail``.
///
/// **Deliberately behind the lock** (spec §3): the index and the previews are
/// fetched while this view is on screen, so no screen a child can reach ever
/// opens a connection, and nobody but a grown-up starts a download.
///
/// The stickers are the album's own circles, so the gallery stays in the
/// visual world the child knows; `design/` has no pack screen to follow.
struct PacksSection: View {
    let packs: PackModel

    /// "Fertig – jetzt spielen": the pack becomes the playing child's
    /// collection, and the app goes home.
    let play: (String) -> Void

    /// The pack whose birds are up in the sheet.
    @State private var opened: String?

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        // Once per pass: the grid and the sheet both read it.
        let cards = packs.cards

        return VStack(alignment: .leading, spacing: ZSpacing.step4) {
            VStack(alignment: .leading, spacing: ZSpacing.step1) {
                Text("parents.packs.title")
                    .typeStyle(.bodyLarge, .body, weight: .bold)
                    .foregroundStyle(ZColor.textStrong)
                Text("parents.packs.intro")
                    .typeStyle(.caption, .body, weight: .semibold)
                    .foregroundStyle(ZColor.textMuted)
            }

            ForEach(packs.migrations) { migration in
                MigrationCard(
                    migration: migration,
                    title: title(of: migration.retired),
                    packs: packs,
                )
            }

            // One column on a phone, two or three on an iPad, where a single
            // card across 900 pt would be mostly air.
            LazyVGrid(
                columns: [GridItem(
                    .adaptive(minimum: 320),
                    spacing: ZSpacing.step4,
                    alignment: .top,
                )],
                alignment: .leading,
                spacing: ZSpacing.step4,
            ) {
                ForEach(cards) { card in
                    cardView(card)
                }
            }

            footer
        }
        // Two doors in: the grown-ups' lock, and this section being on screen.
        // Whatever the catalogue lists has now been shown, which is what
        // takes the dot for a new pack off the home screen's door (#334).
        .task {
            packs.watchConnection()
            await packs.loadAvailable()
            packs.markSeen()
        }
        .onDisappear { packs.stopWatchingConnection() }
        // Here, inside the open door, rather than on the screen: when the door
        // shuts, this view goes and the sheet with it — nothing fed from the
        // network stays up behind a shut lock.
        .sheet(item: Binding(
            get: { opened.flatMap { id in cards.first { $0.id == id } } },
            set: { opened = $0?.id },
        )) { card in
            PackDetail(card: card, packs: packs, play: play) { opened = nil }
        }
    }

    private func cardView(_ card: PackCard) -> some View {
        ZCard {
            VStack(alignment: .leading, spacing: ZSpacing.step4) {
                Button {
                    opened = card.id
                } label: {
                    // The stickers above the words rather than beside them:
                    // beside them, „Vögel Deutschlands" broke inside the word
                    // on a 402 pt phone at the default text size.
                    VStack(alignment: .leading, spacing: ZSpacing.step3) {
                        HStack {
                            covers(card)
                            Spacer()
                            Icon(.chevronRight, size: .small)
                                .foregroundStyle(ZColor.textMuted)
                        }
                        Text(verbatim: card.title)
                            .typeStyle(.bodyLarge, .body, weight: .bold)
                            .foregroundStyle(ZColor.textStrong)
                        Text(verbatim: card.detail)
                            .typeStyle(.caption, .body, weight: .semibold)
                            .foregroundStyle(ZColor.textMuted)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint(String(localized: "parents.packs.open.accessibility"))

                PackStateButton(card: card, packs: packs, play: play)
                problem(card.state)
            }
        }
    }

    /// Three of the pack's birds, overlapping like stickers on a page.
    private func covers(_ card: PackCard) -> some View {
        let size: CGFloat = horizontalSizeClass == .compact ? 72 : 96
        let tilts: [Angle] = [.degrees(-6), .degrees(3), .degrees(-2)]
        return HStack(spacing: -size / 3) {
            ForEach(Array(card.covers.enumerated()), id: \.element.id) { index, bird in
                PackSticker(
                    bird: bird,
                    packs: packs,
                    size: size,
                    rotation: tilts[index % tilts.count],
                )
            }
            // An index from before the previews names no birds: three glyph
            // stickers, so the card still reads as a pack of birds.
            if card.covers.isEmpty {
                ForEach(tilts.indices, id: \.self) { index in
                    RewardSticker(icon: .bird, rotation: tilts[index], size: size)
                }
            }
        }
        .accessibilityHidden(true)
    }

    /// One calm line under a button that did not get there.
    @ViewBuilder
    private func problem(_ state: PackCard.State) -> some View {
        switch state {
        case .failed: note(Text("parents.packs.download.failed"))
        case .outOfSpace: note(Text("parents.packs.outOfSpace"))
        default: EmptyView()
        }
    }

    private func title(of packID: String) -> String {
        packs.installed.first { $0.id == packID }?.pack.title ?? packID
    }

    /// What the bucket had to say, and what the packs take up.
    @ViewBuilder
    private var footer: some View {
        switch packs.available {
        case .loading:
            note(Text("parents.packs.loading"))
        case .failed:
            VStack(alignment: .leading, spacing: ZSpacing.step3) {
                note(Text("parents.packs.failed"))
                ZButton(
                    String(localized: "parents.packs.retry"),
                    tone: .quiet,
                    size: .medium,
                    leadingIcon: .rotateCcw,
                ) {
                    Task { await packs.loadAvailable() }
                }
            }
        case .ready where packs.downloadable.isEmpty:
            note(Text("parents.packs.complete"))
        case .ready:
            EmptyView()
        }

        if !packs.installed.isEmpty {
            note(Text(
                String(
                    format: String(localized: "parents.packs.total"),
                    packs.totalBytes.formatted(.byteCount(style: .file)),
                ),
            ))
        }
    }

    private func note(_ text: Text) -> some View {
        text
            .typeStyle(.caption, .body, weight: .semibold)
            .foregroundStyle(ZColor.textMuted)
    }
}

/// A retired pack on the device (#262): its birds moved into new packs, and
/// one button loads them. The old pack goes once all of them are there.
private struct MigrationCard: View {
    let migration: PackIndex.Migration
    let title: String
    let packs: PackModel

    @State private var asking: [PackIndex.Entry]?

    var body: some View {
        ZCard(tone: .sun) {
            VStack(alignment: .leading, spacing: ZSpacing.step3) {
                Text(String(format: String(localized: "parents.packs.migration.title"), title))
                    .typeStyle(.body, .body, weight: .bold)
                    .foregroundStyle(ZColor.textStrong)
                Text("parents.packs.migration.hint")
                    .typeStyle(.caption, .body, weight: .semibold)
                    .foregroundStyle(ZColor.textMuted)
                ZButton(
                    String(localized: "parents.packs.migration.load"),
                    size: .medium,
                    leadingIcon: .sparkles,
                ) {
                    // The retired pack goes once the last successor is
                    // there — `PackModel.finishMigrations()` — and not a
                    // moment earlier, so no bird is missing in between.
                    asking = packs.load(migration.remaining)
                }
                .modifier(CostlyDownloadQuestion(asking: $asking, packs: packs))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
