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
/// Pushed from ``AboutScreen`` rather than a `Route` case of its own: the
/// credits are one part of what there is to say about the app, and the screen
/// above them is where a grown-up arrives. Its type is theirs as well: full
/// sentences, body sizes, settings rows.
///
/// Public since #199. Behind the grown-ups' lock the attribution CC BY 4.0
/// §3(a)(2) asks for was the weakest form of it — a name nobody without a
/// device code can read; here anybody who opens the app can.
///
/// **Every external link on this screen opens through ``ParentalGate``.**
/// Names and licences stand in plain text and need no gate; the source and
/// the licence text leave the app, and Guideline 1.3 asks for an adult-level
/// task in front of that — see ``SwiftUI/View/opensExternalLinks(_:)``, which
/// is where the link actually opens.
struct CreditsScreen: View {
    /// The credits as they ship, decoded once per process.
    ///
    /// A `static let` because this is a constant of the build, not state: the
    /// file is a resource that cannot change while the app runs, and a stored
    /// property would re-read and re-decode it on every construction of this
    /// view — that is, on every pass of ``AboutScreen``'s body.
    ///
    /// `try?` because there is no useful thing to say to a parent about a
    /// missing bundle resource. `mise run check` regenerates the file and
    /// fails on drift, and `CreditsTests` decodes it without a simulator, so
    /// the empty case is a broken build rather than a state to design for —
    /// it gets one calm line instead of an error screen.
    private static let credits = try? Credits.bundled()

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// The link a grown-up asked for, waiting for the task to be solved.
    /// See ``SwiftUI/View/opensExternalLinks(_:)``.
    @State private var pendingLink: ExternalLink?

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: String(localized: "credits.title")) {
                IconButton(
                    .chevronLeft,
                    label: String(localized: "nav.back.accessibility"),
                    diameter: ZSpacing.touchMinimum,
                ) { dismiss() }
            }

            // Everything below the bar is a grown-up's to read, so it
            // follows the system text size (#239). The bar itself does not —
            // its title already shrinks to the width two buttons leave it.
            content
                .grownUpDynamicType()
        }
        .background(ZColor.surfacePage)
        // Every screen brings its own `TopBar`; the system bar would stack a
        // second, smaller back button above it.
        .toolbar(.hidden, for: .navigationBar)
        // Back up to the screen about the app, which is what the chevron does
        // (#150).
        .swipesBack(.pops)
        .opensExternalLinks($pendingLink)
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
            // The same phone gutter the room next door takes (#142): these
            // are the longest strings in the area — a credit line is a name,
            // a licence and sometimes a recording number — and behind the
            // iPad margin a 375 pt phone left them 177 pt.
            .padding(
                .horizontal,
                horizontalSizeClass == .compact ? ZSpacing.step4 : ZSpacing.gutterScreen,
            )
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
        .accessibilityHint(Text("link.web.accessibility"))
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
            .accessibilityHint(Text("link.web.accessibility"))
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
