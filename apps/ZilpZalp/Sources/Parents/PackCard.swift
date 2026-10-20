import SwiftUI
import ZilpZalpData
import ZilpZalpUI

/// One pack as the gallery draws it (#262), resolved from the model before
/// anything is drawn: the bundled pack, a downloaded one or one still in the
/// bucket all become the same shape, so the card and the detail sheet need not
/// know where a pack lies.
struct PackCard: Identifiable {
    /// One bird of the pack.
    struct Bird: Identifiable {
        let id: String
        let name: String
        /// Bucket key of its preview, for a pack that is not on the device.
        let preview: String?
        /// "Jane Doe, CC-BY-4.0" — who took the photo the preview was cut from.
        let credit: String?
    }

    /// What the one button of the card says and does.
    enum State {
        /// Ships with the app: nothing to do.
        case bundled
        case available(PackIndex.Entry)
        case running(Double)
        /// Interrupted; the next tap resumes.
        case failed(PackIndex.Entry)
        case outOfSpace(PackIndex.Entry)
        case installed
        /// Downloaded while the app runs: "Fertig – jetzt spielen".
        case fresh
        case outdated(PackIndex.Entry)
    }

    let id: String
    let title: String
    let birdCount: Int
    /// On disk for an installed pack, the download for one that is not;
    /// `nil` for the bundled pack.
    let bytes: Int?
    let birds: [Bird]
    let covers: [Bird]
    let state: State
    let isDeletable: Bool

    /// "70 Vögel · 43 MB", "70 Vögel · immer dabei".
    var detail: String {
        let size = bytes.map { $0.formatted(.byteCount(style: .file)) }
            ?? String(localized: "parents.packs.alwaysThere")
        return String(
            format: String(localized: "parents.packs.detail"),
            String(format: String(localized: "parents.packs.species"), birdCount),
            size,
        )
    }
}

extension PackModel {
    /// The gallery: the bundled pack, the downloaded ones, then what the
    /// bucket still offers — the order the old list had.
    var cards: [PackCard] {
        var cards: [PackCard] = []
        if let bundled {
            cards.append(card(for: bundled, bytes: nil, state: .bundled, deletable: false))
        }
        cards += installed.map { installation in
            card(
                for: installation.pack,
                bytes: installation.bytes,
                state: state(of: installation),
                deletable: true,
            )
        }
        cards += downloadable.map(card(for:))
        return cards
    }

    private func state(of installation: PackInstallation) -> PackCard.State {
        let entry = entry(for: installation.id)
        if let download = downloads[installation.id], let entry {
            return state(of: download, entry)
        }
        if let entry, installation.isOutdated(by: entry) {
            return .outdated(entry)
        }
        return fresh.contains(installation.id) ? .fresh : .installed
    }

    private func state(of download: Download, _ entry: PackIndex.Entry) -> PackCard.State {
        switch download {
        case let .running(share): .running(share)
        case .failed: .failed(entry)
        case .outOfSpace: .outOfSpace(entry)
        }
    }

    private func card(
        for pack: Pack,
        bytes: Int?,
        state: PackCard.State,
        deletable: Bool,
    ) -> PackCard {
        let birds = pack.birds.map { PackCard.Bird(
            id: $0.id,
            name: $0.name,
            preview: nil,
            credit: nil,
        ) }
        return PackCard(
            id: pack.id,
            title: pack.title,
            birdCount: birds.count,
            bytes: bytes,
            birds: birds,
            covers: Array(birds.prefix(3)),
            state: state,
            isDeletable: deletable,
        )
    }

    private func card(for entry: PackIndex.Entry) -> PackCard {
        let birds = entry.species.map { species in
            PackCard.Bird(
                id: species.id,
                name: species.name,
                preview: species.preview,
                credit: "\(species.attribution), \(species.license)",
            )
        }
        let named = entry.covers.compactMap { id in birds.first { $0.id == id } }
        return PackCard(
            id: entry.id,
            title: entry.title,
            birdCount: entry.speciesCount,
            bytes: entry.downloadSize,
            birds: birds,
            covers: named.isEmpty ? Array(birds.prefix(3)) : named,
            state: downloads[entry.id].map { state(of: $0, entry) } ?? .available(entry),
            isDeletable: false,
        )
    }

    /// The photo a bird's sticker shows: its own when any pack on the device
    /// carries the species — ids are shared across packs — else the preview.
    func image(for bird: PackCard.Bird) -> Image? {
        photos[bird.id] ?? bird.preview.flatMap { previews[$0] }
    }
}

/// A bird of a pack as a sticker, fetching its preview the first time it is
/// drawn when the device has no photo of it.
struct PackSticker: View {
    let bird: PackCard.Bird
    let packs: PackModel
    var size: CGFloat
    var rotation: Angle = RewardSticker.defaultRotation

    var body: some View {
        RewardSticker(image: packs.image(for: bird), icon: .bird, rotation: rotation, size: size)
            .task(id: bird.preview) {
                guard packs.photos[bird.id] == nil, let key = bird.preview else { return }
                await packs.loadPreview(key)
            }
            .accessibilityLabel(bird.name)
    }
}

/// The one button a pack's card and its detail sheet carry. Asks before a
/// download over a costly connection, so it brings its own dialog — the
/// detail sheet could not present one from the screen underneath.
struct PackStateButton: View {
    let card: PackCard
    let packs: PackModel
    /// "Fertig – jetzt spielen": choose the pack and go home.
    let play: (String) -> Void

    @State private var asking: PackIndex.Entry?

    var body: some View {
        content
            .confirmationDialog(
                "parents.packs.costly.title",
                isPresented: Binding(get: { asking != nil }, set: {
                    if !$0 {
                        asking = nil
                    }
                }),
                titleVisibility: .visible,
                presenting: asking,
            ) { entry in
                Button(String(localized: "parents.packs.costly.confirm")) { packs.download(entry) }
                Button("parents.packs.costly.cancel", role: .cancel) {}
            } message: { entry in
                Text(String(
                    format: String(localized: "parents.packs.costly.message"),
                    entry.title,
                    entry.downloadSize.formatted(.byteCount(style: .file)),
                ))
            }
    }

    @ViewBuilder
    private var content: some View {
        switch card.state {
        case .bundled:
            EmptyView()
        case let .available(entry):
            button("parents.packs.action.load", icon: .plus, tone: .primary) { load(entry) }
        case let .running(share):
            ProgressRing(share: share)
        case let .failed(entry), let .outOfSpace(entry):
            button("parents.packs.action.resume", icon: .rotateCcw) { load(entry) }
        case .installed:
            Label {
                Text("parents.packs.action.loaded")
            } icon: {
                Icon(.check, size: .small)
            }
            .typeStyle(.body, .body, weight: .bold)
            .foregroundStyle(ZColor.textMuted)
        case .fresh:
            button("parents.packs.action.play", icon: .play, tone: .primary) { play(card.id) }
        case let .outdated(entry):
            button("parents.packs.action.update", icon: .rotateCcw) { load(entry) }
        }
    }

    private func button(
        _ key: String.LocalizationValue,
        icon: ZIcon,
        tone: ZButton.Tone = .quiet,
        action: @escaping () -> Void,
    ) -> some View {
        ZButton(
            String(localized: key),
            tone: tone,
            size: .medium,
            leadingIcon: icon,
            action: action,
        )
    }

    private func load(_ entry: PackIndex.Entry) {
        if packs.isCostly {
            asking = entry
        } else {
            packs.download(entry)
        }
    }
}

/// How far a download has got: a ring and the percentage inside it.
private struct ProgressRing: View {
    private static let diameter = ZSpacing.touchMinimum
    private static let line: CGFloat = 6

    let share: Double

    var body: some View {
        let percent = share.formatted(.percent.precision(.fractionLength(0)))
        ZStack {
            Circle().stroke(ZColor.borderCard, lineWidth: Self.line)
            Circle()
                .trim(from: 0, to: share)
                .stroke(ZColor.primary, style: StrokeStyle(lineWidth: Self.line, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear, value: share)
            Text(verbatim: percent)
                .typeStyle(.caption, .body, weight: .bold)
                .foregroundStyle(ZColor.textStrong)
                .minimumScaleFactor(0.5)
                .padding(Self.line)
        }
        .frame(width: Self.diameter, height: Self.diameter)
        .accessibilityElement()
        .accessibilityLabel(String(localized: "parents.packs.progress.accessibility"))
        .accessibilityValue(percent)
    }
}
