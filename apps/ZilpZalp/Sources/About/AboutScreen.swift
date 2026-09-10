import Foundation
import SwiftUI
import ZilpZalpUI

/// What the app is, who publishes it, and where the pages the App Store
/// expects can be read — with the credits pushed from it.
///
/// A `Route` case and not a room inside the grown-ups' area (#199). Everything
/// here is public information: the attribution CC BY 4.0 §3(a)(2) asks for is
/// only "reasonable" if it can actually be reached, and behind a device code
/// it cannot. So the way in is the home screen's own quiet "i" and no lock
/// stands in front of it.
///
/// The type is the grown-ups': full sentences, body sizes, settings rows, as
/// next door in ``ParentsScreen``. A child that lands here by accident finds
/// nothing to do and the chevron back — which is the whole design of the
/// screen for that reader.
///
/// **Every link out of the app opens through ``ParentalGate``**, exactly as
/// the credits do — see ``SwiftUI/View/opensExternalLinks(_:)``.
struct AboutScreen: View {
    /// The pages this screen leads to. Constants of the build, not settings:
    /// there is one website and one mailbox, and a `nil` here would be a typo
    /// in this file rather than anything a grown-up could act on — the same
    /// reasoning, and the same `URL(string:)!`, as ``PackModel/bucket``.
    private static let privacyURL = URL(string: "https://zilpzalp.schnaq.com/datenschutz")!
    private static let websiteURL = URL(string: "https://zilpzalp.schnaq.com")!

    /// Johanna's mailbox, which is the address the website gives for questions
    /// about the app — deliberately not the company address in the Impressum.
    private static let supportURL = URL(string: "mailto:zilpzalp-app@posteo.net")!

    /// "Version 0.1.0 (12)", read out of the bundle so that no number on this
    /// screen can drift from the build a grown-up is looking at.
    ///
    /// `nil` only in a bundle without those keys — the previews, and a broken
    /// build. Then the line is left out rather than filled with a dash: there
    /// is nothing a parent could do about it, and `mise run build` generates
    /// both keys from `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION`.
    private static let version: String? = {
        guard let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
              let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        else { return nil }
        return String(format: String(localized: "about.version"), short, build)
    }()

    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    /// Whether the credits are pushed on top.
    @State private var showsCredits = false

    /// The link a grown-up asked for, waiting for the task to be solved.
    /// See ``SwiftUI/View/opensExternalLinks(_:)``.
    @State private var pendingLink: ExternalLink?

    var body: some View {
        VStack(spacing: 0) {
            TopBar(title: String(localized: "about.title")) {
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
        // Back to the home screen, which is what the chevron does (#150).
        .swipesBack(.pops)
        // A destination of this screen rather than a `Route` case: the credits
        // are one section of what there is to say about the app, and the way
        // to them leads across this screen.
        .navigationDestination(isPresented: $showsCredits) {
            CreditsScreen()
        }
        .opensExternalLinks($pendingLink)
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ZSpacing.step6) {
                // The body step, not the `bodyLarge` the grown-ups' area
                // opens with, for the reason the credits give: this screen is
                // a stack of rows and its opening paragraph would take a
                // phone's whole first screen at 24 pt.
                Text("about.intro")
                    .typeStyle(.body, .body, weight: .semibold)
                    .foregroundStyle(ZColor.textBody)

                signature
                rows
            }
            .frame(maxWidth: ZSpacing.maxContent)
            // The phone gutter both rooms next door take (#142): 96 pt of a
            // 375 pt phone is most of a settings row's text.
            .padding(
                .horizontal,
                horizontalSizeClass == .compact ? ZSpacing.step4 : ZSpacing.gutterScreen,
            )
            .padding(.vertical, ZSpacing.step6)
            .frame(maxWidth: .infinity)
        }
    }

    /// The app's own signature and the build it is: the one place in the app
    /// that says which ZilpZalp this is.
    ///
    /// ``BrandLockup`` rather than the app's name as a string — the name is
    /// drawn art here, not product copy, and the mark beside it is what a
    /// grown-up recognises from the App Store. At the wordmark's floor,
    /// because this is a settings screen and not a title page: measured, the
    /// pair is 200 pt wide, which the narrowest supported phone can give it
    /// inside a card.
    private var signature: some View {
        ZCard {
            VStack(alignment: .leading, spacing: ZSpacing.step3) {
                BrandLockup(size: Wordmark.minimumSize)

                if let version = Self.version {
                    Text(verbatim: version)
                        .typeStyle(.caption, .body, weight: .semibold)
                        .foregroundStyle(ZColor.textMuted)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    /// The credits first — they are what this screen is mostly for — then the
    /// three pages the Kids Category and the App Store expect.
    ///
    /// The credits row is the only one that opens nothing external and is
    /// therefore the only one without a gate in front of it.
    private var rows: some View {
        ZCard(padding: 0) {
            VStack(spacing: 0) {
                SettingRow(
                    title: String(localized: "credits.title"),
                    hint: String(localized: "credits.hint"),
                    icon: .camera,
                ) {
                    showsCredits = true
                }
                linkRow(
                    title: "about.privacy.title",
                    hint: "about.privacy.hint",
                    icon: .shieldCheck,
                    url: Self.privacyURL,
                )
                linkRow(
                    title: "about.website.title",
                    hint: "about.website.hint",
                    icon: .house,
                    url: Self.websiteURL,
                )
                linkRow(
                    title: "about.mail.title",
                    hint: "about.mail.hint",
                    icon: .mail,
                    url: Self.supportURL,
                    accessibilityHint: "link.mail.accessibility",
                    showsSeparator: false,
                )
            }
            // The rows paint to the card's inner edge, so their square corners
            // would otherwise sit inside its round ones. The same arithmetic
            // the credits and the grown-ups' area do, and it moves to `ZCard`
            // on the same day (#12).
            .clipShape(
                RoundedRectangle(cornerRadius: ZRadius.card - ZBorder.width, style: .continuous),
            )
        }
    }

    /// One row that leaves the app. The tap sets the pending link and nothing
    /// else; the gate is what opens it.
    private func linkRow(
        title: String.LocalizationValue,
        hint: String.LocalizationValue,
        icon: ZIcon,
        url: URL,
        accessibilityHint: LocalizedStringKey = "link.web.accessibility",
        showsSeparator: Bool = true,
    ) -> some View {
        SettingRow(
            title: String(localized: title),
            hint: String(localized: hint),
            icon: icon,
            showsSeparator: showsSeparator,
        ) {
            pendingLink = ExternalLink(url: url)
        }
        .accessibilityHint(Text(accessibilityHint))
    }
}

#Preview("iPhone") {
    NavigationStack {
        AboutScreen()
    }
}

#Preview("iPad", traits: .fixedLayout(width: 1194, height: 834)) {
    NavigationStack {
        AboutScreen()
    }
}
