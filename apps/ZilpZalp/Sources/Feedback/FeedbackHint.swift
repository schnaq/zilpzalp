import SwiftUI
import UIKit
import ZilpZalpUI

extension View {
    /// Offers a grown-up feedback on what is on screen after they take a
    /// system screenshot in a round; see
    /// `docs/superpowers/specs/2026-11-14-in-app-feedback-design.md`.
    ///
    /// - Parameters:
    ///   - session: The round being played.
    ///   - isActive: Whether the round is the screen in front. A screenshot of
    ///     anything else — the round end above it, the quit card — does
    ///     nothing, or the report would carry the wrong screen and stale
    ///     context.
    func feedbackOnScreenshot(session: QuizSession?, isActive: Bool) -> some View {
        modifier(FeedbackOnScreenshot(session: session, isActive: isActive))
    }
}

/// The quiet hint after a screenshot, and the sheet behind it.
///
/// Nothing is spoken and nothing pauses until the hint is tapped: a child who
/// takes a screenshot by accident and ignores the hint loses nothing.
private struct FeedbackOnScreenshot: ViewModifier {
    /// How long the hint waits for a tap.
    private static let hintDuration: Duration = .seconds(5)

    /// Where the hint stands: below ``TopBar`` — its 64 pt back button and the
    /// bar's vertical padding — over the progress row, the one strip of a round
    /// a child has no reason to tap. At the very top it would cover the back
    /// chevron, and a child reaching for that would pause the round instead.
    private static let hintInset = ZSpacing.touchMinimum + 2 * ZSpacing.step4

    private static let screenshots = NotificationCenter.default
        .publisher(for: UIApplication.userDidTakeScreenshotNotification)

    let session: QuizSession?
    let isActive: Bool

    /// The moment the hint offers to report.
    @State private var pending: FeedbackCapture?
    /// The moment the sheet is reporting.
    @State private var open: FeedbackCapture?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let pending {
                    // `medium`, the grown-ups' size, on a child's screen: the
                    // hint is for the grown-up who just took the screenshot,
                    // and it should not compete with the tiles.
                    ZButton(
                        String(localized: "feedback.hint"),
                        tone: .quiet,
                        size: .medium,
                        leadingIcon: .mail,
                    ) {
                        session?.suspend()
                        open = pending
                        self.pending = nil
                    }
                    .padding(.top, Self.hintInset)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(
                reduceMotion ? nil : ZMotion.easeOut.animation(duration: ZMotion.fast),
                value: pending?.id,
            )
            .onReceive(Self.screenshots) { _ in
                // Not while the hint is up either: the capture would draw the
                // hint into the screenshot the grown-up is offered to send.
                guard isActive, open == nil, pending == nil, let session,
                      !session.isFinished else { return }
                pending = .take(of: session)
            }
            .task(id: pending?.id) {
                guard pending != nil else { return }
                try? await Task.sleep(for: Self.hintDuration)
                guard !Task.isCancelled else { return }
                pending = nil
            }
            .onChange(of: isActive) { _, active in
                if !active {
                    pending = nil
                }
            }
            // A sheet, never a full-screen cover: the round stays underneath,
            // so its `onAppear` — which would ask the question again — does
            // not run when the sheet goes.
            .sheet(item: $open, onDismiss: { session?.carryOn() }, content: { capture in
                FeedbackSheet(capture: capture) { open = nil }
            })
    }
}
