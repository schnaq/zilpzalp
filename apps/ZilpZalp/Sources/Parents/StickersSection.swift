import SwiftUI
import ZilpZalpCore
import ZilpZalpData
import ZilpZalpUI

/// The "Sticker" card of the grown-ups' area: per child, how often a bird has
/// to be recognised before its sticker goes into the album — three or five
/// (#260).
///
/// Per child rather than one setting for the device, because siblings of
/// four and of eight share an iPad and should not share a threshold. One
/// ``SettingRow`` per profile and a dialog for the choice, exactly as the
/// daily limit has: a pushed screen would take the area off the display,
/// and that shuts the door.
///
/// Its own file, as ``PacksSection`` is, because ``ParentsScreen`` sits at
/// SwiftLint's ceiling. Absent while there is no profile to set anything for.
struct StickersSection: View {
    let profiles: [Profile]

    /// A grown-up picked `threshold` for the child with this id.
    let choose: (_ threshold: Int, _ profile: Profile.ID) -> Void

    /// The child whose threshold is being chosen, while the dialog is up.
    @State private var choosing: Profile?

    var body: some View {
        if !profiles.isEmpty {
            VStack(alignment: .leading, spacing: ZSpacing.step4) {
                VStack(alignment: .leading, spacing: ZSpacing.step1) {
                    Text("parents.stickers.title")
                        .typeStyle(.bodyLarge, .body, weight: .bold)
                        .foregroundStyle(ZColor.textStrong)
                    Text("parents.stickers.intro")
                        .typeStyle(.caption, .body, weight: .semibold)
                        .foregroundStyle(ZColor.textMuted)
                }

                card
            }
            .confirmationDialog(
                Text(verbatim: choosing?.name ?? ""),
                isPresented: Binding(
                    get: { choosing != nil },
                    set: {
                        if !$0 {
                            choosing = nil
                        }
                    },
                ),
                titleVisibility: .visible,
                presenting: choosing,
            ) { profile in
                ForEach(Scoring.stickerThresholds, id: \.self) { threshold in
                    Button(label(for: threshold)) {
                        choose(threshold, profile.id)
                    }
                }
                Button("parents.stickers.cancel", role: .cancel) {}
            } message: { _ in
                Text("parents.stickers.intro")
            }
        }
    }

    private var card: some View {
        ZCard(padding: 0) {
            VStack(spacing: 0) {
                ForEach(profiles) { profile in
                    SettingRow(
                        title: profile.name,
                        icon: .album,
                        value: label(for: profile.stickerThreshold),
                        showsSeparator: profile.id != profiles.last?.id,
                    ) {
                        choosing = profile
                    }
                }
            }
            // The same arithmetic every full-bleed card needs, and the same
            // note: it belongs in `ZCard` once that can interleave rows (#12).
            .clipShape(
                RoundedRectangle(cornerRadius: ZRadius.card - ZBorder.width, style: .continuous),
            )
        }
    }

    /// "5-mal erkannt", in the row and in the dialog — one spelling, so the
    /// value a grown-up picked reads back exactly as it was offered.
    private func label(for threshold: Int) -> String {
        String(format: String(localized: "parents.stickers.value"), threshold)
    }
}

#Preview {
    ScrollView {
        StickersSection(
            profiles: [
                Profile(id: UUID(), name: "Mila", avatar: "amsel"),
                Profile(id: UUID(), name: "Jonas", avatar: "star", stickerThreshold: 3),
            ],
            choose: { _, _ in },
        )
        .padding(ZSpacing.step4)
    }
    .background(ZColor.surfacePage)
}
