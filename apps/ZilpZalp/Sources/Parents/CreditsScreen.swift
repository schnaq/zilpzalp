import SwiftUI
import ZilpZalpData
import ZilpZalpUI

/// Who took the pictures, who made the recordings, and under which licence.
///
/// Every line on this screen is read from `Credits.bundled()`, which
/// `tools/generate_credits.py` derives from the pack manifests and the
/// vendored licence files. Nothing here is written by hand: attribution typed
/// into a view drifts away from the assets the moment anybody exchanges a
/// photo, and CC BY is not satisfied by a name that used to be right.
///
/// A room inside the grown-ups' area rather than a `Route` case — the only way
/// in is past the lock, and its type is the grown-ups' type: full sentences,
/// body sizes, settings rows.
///
/// **Every external link on this screen opens through ``ParentalGate``.**
/// Names and licences stand in plain text and need no gate; the source and
/// the licence text leave the app, and Guideline 1.3 asks for an adult-level
/// task in front of that. This is the app's only `openURL` call site.
struct CreditsScreen: View {
    /// The credits as they ship, decoded once per process.
    ///
    /// A `static let` because this is a constant of the build, not state: the
    /// file is a resource that cannot change while the app runs, and a stored
    /// property would re-read and re-decode it on every construction of this
    /// view — that is, on every pass of the grown-ups' screen's body.
    ///
    /// `try?` because there is no useful thing to say to a parent about a
    /// missing bundle resource. `mise run check` regenerates the file and
    /// fails on drift, and `CreditsTests` decodes it without a simulator, so
    /// the empty case is a broken build rather than a state to design for —
    /// it gets one calm line instead of an error screen.
    private static let credits = try? Credits.bundled()

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    /// The link a grown-up asked for, waiting for the task to be solved.
    /// `nil` whenever no gate is up — setting it is what puts the sheet there.
    @State private var pendingLink: ExternalLink?

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: String(localized: "parents.credits.title")) {
                IconButton(
                    .chevronLeft,
                    label: String(localized: "nav.back.accessibility"),
                    diameter: ZSpacing.touchMinimum,
                ) { dismiss() }
            }

            content
        }
        .background(ZColor.surfacePage)
        // Every screen brings its own `TopBar`; the system bar would stack a
        // second, smaller back button above it.
        .toolbar(.hidden, for: .navigationBar)
        // Back into the grown-ups' area, which is what the chevron does; the
        // area's own lock is untouched by either (#150).
        .swipesBack(.pops)
        // The gate, undressed: it brings its own gutter and scrolls itself, so
        // the sheet only has to give it the page colour. Swiping it down is
        // the way out — there is nothing to confirm and nothing to save.
        .sheet(item: $pendingLink) { link in
            ParentalGate(reason: String(localized: "credits.gate.reason")) {
                // Down first, then out: the sheet is gone before the browser
                // comes up, so coming back lands on the credits and not on a
                // solved task.
                pendingLink = nil
                openURL(link.url)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(ZColor.surfacePage)
            // A page, not the default form sheet. Measured on an iPad Pro
            // 13-inch the form sheet is about 620 pt tall and cut the bottom
            // row of answer pills in half — the gate scrolls, so nothing was
            // unreachable, but a task whose answers are sliced through reads
            // as broken rather than as "there is more below". On a phone a
            // sheet is full width either way and this changes nothing.
            .presentationSizing(.page)
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ZSpacing.step6) {
                // The body step, not the `bodyLarge` the grown-ups' area
                // opens with: this screen is a long list and its opening
                // paragraph filled an entire phone screen at 24 pt.
                Text("credits.intro")
                    .typeStyle(.body, .body, weight: .semibold)
                    .foregroundStyle(ZColor.textBody)

                if let credits = Self.credits {
                    ForEach(Self.packs(of: credits)) { pack in
                        section(pack.title) {
                            ForEach(Array(pack.media.enumerated()), id: \.element) { index, entry in
                                mediaRow(entry, showsSeparator: index != pack.media.count - 1)
                            }
                        }
                    }

                    section(String(localized: "credits.fonts.title")) {
                        vendoredRows(credits.fonts, icon: .type)
                    }
                    section(String(localized: "credits.icons.title")) {
                        vendoredRows(credits.icons, icon: .feather)
                    }
                } else {
                    Text("credits.unavailable")
                        .typeStyle(.body, .body, weight: .semibold)
                        .foregroundStyle(ZColor.textMuted)
                }
            }
            .frame(maxWidth: ZSpacing.maxContent)
            .padding(.horizontal, ZSpacing.gutterScreen)
            .padding(.vertical, ZSpacing.step6)
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Sections

    private func section(
        _ title: String,
        @ViewBuilder rows: () -> some View,
    ) -> some View {
        VStack(alignment: .leading, spacing: ZSpacing.step4) {
            Text(verbatim: title)
                .typeStyle(.label, .display, weight: .bold)
                .foregroundStyle(ZColor.textStrong)

            ZCard(padding: 0) {
                VStack(spacing: 0) { rows() }
                    // The rows paint to the card's inner edge, so their square
                    // corners would otherwise sit inside its round ones. The
                    // same arithmetic `ParentsScreen` does, and it moves to
                    // `ZCard` on the same day (#12).
                    .clipShape(
                        RoundedRectangle(
                            cornerRadius: ZRadius.card - ZBorder.width,
                            style: .continuous,
                        ),
                    )
            }
        }
    }

    /// One photo or one recording. Name and licence are in the row itself;
    /// only the source leaves the app, and the chevron says where to.
    ///
    /// No `value` in front of the chevron, although the row would take one and
    /// "Quelle" would name what it opens. Measured on an iPhone 17 Pro it cost
    /// about 90 pt of the row's width, which left the credit line four words
    /// wide and broke "Blaumeise" across two lines. The intro says what the
    /// chevron leads to; VoiceOver gets it from the hint below.
    private func mediaRow(_ entry: Credits.Media, showsSeparator: Bool) -> some View {
        SettingRow(
            title: entry.birdName,
            hint: credit(for: entry),
            icon: entry.kind == .photo ? .camera : .volume2,
            showsSeparator: showsSeparator,
        ) {
            pendingLink = ExternalLink(url: entry.sourceURL)
        }
        .accessibilityHint(Text("credits.link.accessibility"))
    }

    /// The font families and the icon sets, which sit in no manifest and come
    /// from the generator's own lists.
    private func vendoredRows(_ entries: [Credits.Vendored], icon: ZIcon) -> some View {
        ForEach(Array(entries.enumerated()), id: \.element) { index, entry in
            SettingRow(
                title: entry.name,
                // `entry.license` is an SPDX identifier and is shown as one.
                // The app maps exactly one thing, ``License/shortName``, and
                // that enum holds only the three media licences; OFL, ISC and
                // MIT are not among them. Their public names live in the
                // generator's own table, next to the licence texts and the
                // deed URLs — one table, in the place that already has to
                // know them for CREDITS.md.
                hint: String(
                    format: String(localized: "credits.vendored.by"),
                    entry.authors.joined(separator: ", "),
                    entry.license,
                ),
                icon: icon,
                showsSeparator: index != entries.count - 1,
            ) {
                pendingLink = ExternalLink(url: entry.licenseURL)
            }
            .accessibilityHint(Text("credits.link.accessibility"))
        }
    }

    /// "Foto von Alexis Tinker-Tsavalas · CC BY". Two formats rather than one
    /// with a third argument, so a translation can put the kind where its own
    /// grammar wants it.
    private func credit(for entry: Credits.Media) -> String {
        let format = switch entry.kind {
        case .photo: String(localized: "credits.photo.by")
        case .call: String(localized: "credits.call.by")
        }
        return String(format: format, entry.attribution, entry.license.shortName)
    }

    /// The media grouped by pack, in the order the generator wrote them —
    /// packs by id, birds in manifest order, photo before call. Nothing is
    /// sorted here: the order is the generator's to state, and re-sorting it
    /// would make two places responsible for one arrangement.
    private static func packs(of credits: Credits) -> [CreditedPack] {
        credits.media.reduce(into: [CreditedPack]()) { packs, entry in
            if let index = packs.firstIndex(where: { $0.id == entry.packID }) {
                packs[index].media.append(entry)
            } else {
                packs.append(
                    CreditedPack(id: entry.packID, title: entry.packTitle, media: [entry]),
                )
            }
        }
    }
}

// MARK: - Values

/// One pack's worth of credits, under the pack's own title.
private struct CreditedPack: Identifiable {
    let id: String
    let title: String
    var media: [Credits.Media]
}

/// A URL on its way out of the app, waiting behind the task.
///
/// A wrapper rather than the bare `URL` because `.sheet(item:)` needs an
/// `Identifiable`, and the URL is its own identity: two rows pointing at the
/// same page are the same pending link.
private struct ExternalLink: Identifiable {
    let url: URL

    var id: URL {
        url
    }
}

#Preview("iPhone") {
    NavigationStack {
        CreditsScreen()
    }
}

#Preview("iPad", traits: .fixedLayout(width: 1194, height: 834)) {
    NavigationStack {
        CreditsScreen()
    }
}
