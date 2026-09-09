import SwiftUI
import ZilpZalpData
import ZilpZalpUI

/// The "Pakete" card of the grown-ups' area: what is on the device, what can
/// be loaded, and what it all costs.
///
/// Its own file rather than three more computed properties on
/// ``ParentsScreen``, which sits at SwiftLint's ceiling — and its own view
/// because this is the one part of that screen with a state of its own.
///
/// **Deliberately behind the lock** (spec §3): the list is fetched when this
/// view appears, so no screen a child can reach ever opens a connection, and
/// nobody but a grown-up starts a download over mobile data.
///
/// `design/` has no pack screen to follow, so it borrows the shape of the rows
/// above it: one `ZCard`, one `SettingRow` per pack, the plain caption line
/// underneath that the rest of the area uses for anything that is not a
/// setting.
struct PacksSection: View {
    /// One row of the card, resolved from the model before anything is drawn:
    /// which pack is where and what may be done with it is the interesting
    /// part, and it is easier to read in one list than spread over three.
    private struct Row: Identifiable {
        /// What a tap does. `nil` for the base pack and for a download in
        /// flight — both are rows to read, not to press.
        enum Tap {
            case download(PackIndex.Entry)
            case delete(PackInstallation)
        }

        let id: String
        let title: String
        let hint: String
        /// Right of the title: a size, or how far a download has got.
        let value: String
        let icon: ZIcon
        var tap: Tap?
    }

    let packs: PackModel

    /// The pack a grown-up asked to delete, while the dialog is up.
    @State private var deleting: PackInstallation?

    var body: some View {
        VStack(alignment: .leading, spacing: ZSpacing.step4) {
            VStack(alignment: .leading, spacing: ZSpacing.step1) {
                Text("parents.packs.title")
                    .typeStyle(.bodyLarge, .body, weight: .bold)
                    .foregroundStyle(ZColor.textStrong)
                Text("parents.packs.intro")
                    .typeStyle(.caption, .body, weight: .semibold)
                    .foregroundStyle(ZColor.textMuted)
            }

            card
            footer
        }
        // The one place the app reaches for the network on its own, and it is
        // two doors in: the grown-ups' lock, and this section being on screen.
        .task { await packs.loadAvailable() }
        .confirmationDialog(
            "parents.packs.delete.title",
            isPresented: Binding(
                get: { deleting != nil },
                set: {
                    if !$0 {
                        deleting = nil
                    }
                },
            ),
            titleVisibility: .visible,
            presenting: deleting,
        ) { installation in
            Button(String(localized: "parents.packs.delete.confirm"), role: .destructive) {
                Task { await packs.delete(installation.id) }
            }
            Button("parents.packs.delete.cancel", role: .cancel) {}
        } message: { installation in
            Text(
                String(
                    format: String(localized: "parents.packs.delete.message"),
                    installation.pack.title,
                ),
            )
        }
    }

    private var card: some View {
        ZCard(padding: 0) {
            VStack(spacing: 0) {
                ForEach(rows) { row in
                    SettingRow(
                        title: row.title,
                        hint: row.hint,
                        icon: row.icon,
                        value: row.value,
                        showsSeparator: row.id != rows.last?.id,
                    ) {
                        tapped(row)
                    }
                    // A row with nothing to do is dimmed rather than absent:
                    // the base pack is a pack like the others, and a download
                    // in flight is the same row a moment later.
                    .disabled(row.tap == nil)
                }
            }
            // The same arithmetic every full-bleed card needs, and the same
            // note: it belongs in `ZCard` once that can interleave rows (#12).
            .clipShape(
                RoundedRectangle(cornerRadius: ZRadius.card - ZBorder.width, style: .continuous),
            )
        }
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
                    size(packs.totalBytes),
                ),
            ))
        }
    }

    /// The base pack, then what is installed, then what is still to be had.
    private var rows: [Row] {
        var rows: [Row] = []

        if let bundled = packs.bundled {
            rows.append(Row(
                id: bundled.id,
                title: bundled.title,
                hint: species(bundled.birds.count),
                value: String(localized: "parents.packs.alwaysThere"),
                icon: .check,
            ))
        }

        rows += packs.installed.map { installation in
            Row(
                id: installation.id,
                title: installation.pack.title,
                hint: species(installation.pack.birds.count),
                value: size(installation.bytes),
                icon: .check,
                tap: .delete(installation),
            )
        }

        rows += packs.downloadable.map { entry in
            if let share = packs.downloading[entry.id] {
                return Row(
                    id: entry.id,
                    title: entry.title,
                    hint: species(entry.speciesCount),
                    value: share.formatted(.percent.precision(.fractionLength(0))),
                    icon: .plus,
                )
            }
            return Row(
                id: entry.id,
                title: entry.title,
                hint: packs.failed.contains(entry.id)
                    ? String(localized: "parents.packs.download.failed")
                    : species(entry.speciesCount),
                value: size(entry.downloadSize),
                icon: .plus,
                tap: .download(entry),
            )
        }

        return rows
    }

    private func tapped(_ row: Row) {
        switch row.tap {
        case let .download(entry): packs.download(entry)
        case let .delete(installation): deleting = installation
        case nil: break
        }
    }

    /// "60 Arten", through the catalog's plural rules — never assembled from a
    /// number and a word, which German would get wrong at one.
    private func species(_ count: Int) -> String {
        String(format: String(localized: "parents.packs.species"), count)
    }

    /// "12 MB", in the device's own units and language.
    private func size(_ bytes: Int) -> String {
        bytes.formatted(.byteCount(style: .file))
    }

    private func note(_ text: Text) -> some View {
        text
            .typeStyle(.caption, .body, weight: .semibold)
            .foregroundStyle(ZColor.textMuted)
    }
}
