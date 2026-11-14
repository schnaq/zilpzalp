import MessageUI
import SwiftUI
import ZilpZalpData
import ZilpZalpUI

/// The grown-ups' side of a feedback report: ``ParentalGate``, then the form,
/// then the system mail composer.
///
/// Nothing leaves the device from here. The composer — or the share sheet on a
/// device without a mail account — is the grown-up's own, and only their
/// „Senden" sends anything.
struct FeedbackSheet: View {
    private enum Stage {
        case gate
        case form
        case mail(FeedbackReport, screenshot: UIImage?)
    }

    let capture: FeedbackCapture
    /// Closes the sheet; the round carries on from its `onDismiss`.
    let onDone: () -> Void

    @State private var stage = Stage.gate

    var body: some View {
        Group {
            switch stage {
            case .gate:
                ParentalGate(reason: String(localized: "feedback.gate.reason")) { stage = .form }
            case .form:
                FeedbackForm(capture: capture) { stage = .mail($0, screenshot: $1) }
            case let .mail(report, screenshot):
                // Sent, cancelled or failed alike: the round is waiting.
                MailComposer(
                    report: report,
                    subject: subject(for: report),
                    screenshot: screenshot,
                    onFinish: onDone,
                )
                .ignoresSafeArea()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ZColor.surfacePage)
        // A page, as in front of a link — see `ExternalLinkGate`.
        .presentationSizing(.page)
    }
}

/// What the report is about, in the grown-ups' area's card style: the
/// screenshot and whether it goes along, the tile, the reason and a note.
private struct FeedbackForm: View {
    let capture: FeedbackCapture
    /// Hands the finished report up, with the screenshot only if the grown-up
    /// chose to send it.
    let onSend: (FeedbackReport, UIImage?) -> Void

    private static let tileColumns = [GridItem(.adaptive(minimum: 140), spacing: ZSpacing.step3)]

    /// Asked once: whether a mail account is set up cannot change while the
    /// sheet is up, and the form redraws on every keystroke in the note.
    private let canSendMail = MFMailComposeViewController.canSendMail()

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var target = FeedbackTarget.other
    @State private var reason = FeedbackReason.other
    @State private var note = ""
    /// Off on every presentation and never stored: the screenshot goes along
    /// only when a grown-up who has seen it says so, each time.
    @State private var sendsScreenshot = false
    @State private var choosingReason = false
    @State private var choosingScreenshot = false

    private var report: FeedbackReport {
        FeedbackReport(snapshot: capture.snapshot, target: target, reason: reason, note: note)
    }

    var body: some View {
        // The phone gutter the grown-ups' area takes; see `ParentsScreen`.
        let gutter = horizontalSizeClass == .compact ? ZSpacing.step4 : ZSpacing.gutterScreen
        ScrollView {
            VStack(alignment: .leading, spacing: ZSpacing.step6) {
                Text("feedback.title")
                    .typeStyle(.title, .display, weight: .extraBold)
                    .foregroundStyle(ZColor.textStrong)
                screenshotCard
                targets
                details
                action
            }
            .frame(maxWidth: ZSpacing.maxContent)
            .padding(.horizontal, gutter)
            .padding(.vertical, ZSpacing.step6)
            .frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        .grownUpDynamicType()
    }

    // MARK: - Screenshot

    private var screenshotCard: some View {
        rowCard {
            Image(uiImage: capture.screenshot)
                .resizable()
                .scaledToFit()
                .frame(height: 160)
                .frame(maxWidth: .infinity)
                .padding(ZSpacing.step4)
                .background(ZColor.surfaceCard)
                .accessibilityHidden(true)

            SettingRow(
                title: String(localized: "feedback.screenshot.title"),
                hint: String(localized: "feedback.screenshot.hint"),
                icon: .camera,
                value: screenshotLabel(sendsScreenshot),
                showsSeparator: false,
            ) {
                choosingScreenshot = true
            }
        }
        .confirmationDialog(
            "feedback.screenshot.title",
            isPresented: $choosingScreenshot,
            titleVisibility: .visible,
        ) {
            Button(screenshotLabel(true)) { sendsScreenshot = true }
            Button(screenshotLabel(false)) { sendsScreenshot = false }
            Button("parents.playtime.cancel", role: .cancel) {}
        } message: {
            Text("feedback.screenshot.hint")
        }
    }

    private func screenshotLabel(_ sends: Bool) -> String {
        sends ? String(localized: "feedback.screenshot.yes") :
            String(localized: "feedback.screenshot.no")
    }

    // MARK: - Which one

    /// The round's tiles as they looked, with the name under each — fine here,
    /// behind the gate — then the call in game 2, and „Etwas anderes".
    private var targets: some View {
        VStack(alignment: .leading, spacing: ZSpacing.step3) {
            Text("feedback.target.title")
                .typeStyle(.bodyLarge, .body, weight: .bold)
                .foregroundStyle(ZColor.textStrong)

            ZCard {
                VStack(spacing: ZSpacing.step3) {
                    // Two across on a phone, four on an iPad: four across a
                    // phone broke „Haubentaucher" mid-word.
                    LazyVGrid(columns: Self.tileColumns, spacing: ZSpacing.step3) {
                        ForEach(capture.snapshot.tiles, id: \.species) { tile in
                            choice(.tile(tile.species)) {
                                VStack(spacing: ZSpacing.step2) {
                                    thumbnail(capture.thumbnails[tile.species])
                                    Text(verbatim: tile.name)
                                        .typeStyle(.caption, .body, weight: .semibold)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                }
                            }
                        }
                    }
                    HStack(spacing: ZSpacing.step3) {
                        if capture.snapshot.call != nil {
                            choice(.call) { Text("feedback.target.call") }
                        }
                        choice(.other) { Text("feedback.target.other") }
                    }
                }
            }
        }
    }

    private func thumbnail(_ image: Image?) -> some View {
        Color.clear
            .aspectRatio(1, contentMode: .fit)
            .overlay {
                if let image {
                    image.resizable().scaledToFill()
                } else {
                    ZColor.surfaceSunken
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: ZRadius.small, style: .continuous))
    }

    /// One pickable answer to „Welches Bild?". The picked one is outlined
    /// twice as thick in olive, so it does not rest on colour alone.
    private func choice(_ value: FeedbackTarget, @ViewBuilder label: () -> some View) -> some View {
        let selected = target == value
        let shape = RoundedRectangle(cornerRadius: ZRadius.medium, style: .continuous)
        return Button {
            target = value
        } label: {
            label()
                .foregroundStyle(ZColor.textStrong)
                .padding(ZSpacing.step2)
                .frame(maxWidth: .infinity, minHeight: ZSpacing.touchMinimum)
                .background(ZColor.surfaceCard, in: shape)
                .overlay(
                    shape.strokeBorder(
                        selected ? ZColor.olive600 : ZColor.borderCard,
                        lineWidth: selected ? 2 * ZBorder.width : ZBorder.width,
                    ),
                )
                .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - What is wrong

    private var details: some View {
        rowCard {
            SettingRow(
                title: String(localized: "feedback.reason.title"),
                icon: .pencil,
                value: reason.label,
            ) {
                choosingReason = true
            }

            TextField("feedback.note", text: $note, axis: .vertical)
                .lineLimit(3 ... 6)
                .typeStyle(.body, .body, weight: .semibold)
                .foregroundStyle(ZColor.textStrong)
                .padding(ZSpacing.step5)
                .background(ZColor.surfaceCard)
        }
        .confirmationDialog(
            "feedback.reason.title",
            isPresented: $choosingReason,
            titleVisibility: .visible,
        ) {
            ForEach(FeedbackReason.allCases, id: \.self) { reason in
                Button(reason.label) { self.reason = reason }
            }
            Button("parents.playtime.cancel", role: .cancel) {}
        }
    }

    // MARK: - Send

    @ViewBuilder
    private var action: some View {
        let report = report
        Group {
            if canSendMail {
                ZButton(String(localized: "feedback.send"), leadingIcon: .mail) {
                    onSend(report, sendsScreenshot ? capture.screenshot : nil)
                }
            } else {
                share(report)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// No mail account: the share sheet with the same text, which starts with
    /// our address because a share sheet cannot preset a recipient. It reports
    /// no outcome, so the grown-up closes the sheet themselves afterwards.
    @ViewBuilder
    private func share(_ report: FeedbackReport) -> some View {
        let body = report.body(recipient: FeedbackReport.recipient)
        let subject = subject(for: report)
        if sendsScreenshot {
            let image = Image(uiImage: capture.screenshot)
            ShareLink(
                item: image,
                subject: Text(verbatim: subject),
                message: Text(verbatim: body),
                preview: SharePreview(subject, image: image),
            ) { shareLabel }
        } else {
            ShareLink(
                item: body,
                subject: Text(verbatim: subject),
            ) {
                shareLabel
            }
        }
    }

    /// A ``ShareLink`` cannot wear ``ZButton``'s style, which the design
    /// system keeps to itself, so this draws the quiet pill's outline.
    private var shareLabel: some View {
        HStack(spacing: ZSpacing.step3) {
            Icon(.mail, size: .small)
            Text("feedback.share")
                .typeStyle(.label, .display, weight: .bold)
        }
        .foregroundStyle(ZColor.textStrong)
        .padding(.horizontal, ZSpacing.step5)
        .frame(minHeight: ZSpacing.touchMinimum)
        .background(ZColor.surfaceCard, in: Capsule())
        .overlay(Capsule().strokeBorder(ZColor.borderCard, lineWidth: ZBorder.width))
    }

    /// A card of full-width rows, clipped like `ParentsScreen`'s.
    private func rowCard(@ViewBuilder content: () -> some View) -> some View {
        ZCard(padding: 0) {
            VStack(spacing: 0, content: content)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: ZRadius.card - ZBorder.width,
                        style: .continuous,
                    ),
                )
        }
    }
}

/// The system mail composer, pre-filled: our address, the subject, the body
/// and the screenshot if the grown-up chose to send it.
private struct MailComposer: UIViewControllerRepresentable {
    let report: FeedbackReport
    let subject: String
    let screenshot: UIImage?
    let onFinish: () -> Void

    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients([FeedbackReport.recipient])
        composer.setSubject(subject)
        composer.setMessageBody(report.body(), isHTML: false)
        if let png = screenshot?.pngData() {
            composer.addAttachmentData(png, mimeType: "image/png", fileName: "zilpzalp.png")
        }
        return composer
    }

    func updateUIViewController(_: MFMailComposeViewController, context _: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }

    final class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func mailComposeController(
            _: MFMailComposeViewController,
            didFinishWith _: MFMailComposeResult,
            error _: Error?,
        ) {
            onFinish()
        }
    }
}

/// „ZilpZalp-Feedback: Amsel – Ausschnitt schlecht", or without a bird name
/// when the report is about something else.
private func subject(for report: FeedbackReport) -> String {
    if let bird = report.birdName {
        return String(
            format: String(localized: "feedback.mail.subject.bird"),
            bird,
            report.reason.label,
        )
    }
    return String(format: String(localized: "feedback.mail.subject"), report.reason.label)
}

private extension FeedbackReason {
    /// The reason as the sheet and the subject say it.
    var label: String {
        switch self {
        case .blurry: String(localized: "feedback.reason.blurry")
        case .crop: String(localized: "feedback.reason.crop")
        case .wrongBird: String(localized: "feedback.reason.wrongBird")
        case .call: String(localized: "feedback.reason.call")
        case .name: String(localized: "feedback.reason.name")
        case .other: String(localized: "feedback.reason.other")
        }
    }
}
