import SwiftUI
import ZilpZalpUI

/// The question the app asks before a round that is still under way is thrown
/// away: "Willst du aufhören?", on a card over the dimmed round.
///
/// The back chevron sits in the corner every screen puts it in, and on the
/// quiz screen one stray tap on it used to cost ten questions, the stars they
/// were worth and the sticker they were about to earn (#146). So a round is
/// now left deliberately or not at all.
///
/// Everything here is built for somebody who cannot read the card. The
/// question is spoken as it appears, the way every screen in this app that
/// asks something speaks it — see ``ReadAloudOnce``, whose other caller is
/// the parental gate. Both answers are told apart by their icon, their colour
/// and their order rather than by their label: the olive one on top carries
/// on, the quiet one below goes home. That is the pairing the round end
/// already teaches with "Nochmal spielen" and "Meine Sammlung" (#119), where
/// position and colour do the same work at the same size.
///
/// Every way out of the card that is not the second button is the safe
/// answer, tapping beside it included: a child who did not mean to open this
/// gets back into the round by tapping anywhere.
struct QuitConfirmation: View {
    /// The question, in one place. Shown and — through ``ReadAloudOnce`` —
    /// said, so the two can never drift apart.
    private static var question: String {
        String(localized: "quiz.quit.question")
    }

    /// Back into the round. The scrim calls it too.
    let onKeepPlaying: () -> Void

    /// Out of the round. The only thing on this card that leaves.
    let onLeave: () -> Void

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    var body: some View {
        ZStack {
            ZColor.scrim
                // `--scrim` is the design system's own 45 % modal veil, and
                // this is the first thing in the app to use it. Over the top
                // bar and the home indicator as well: an undimmed strip at
                // either end would read as a piece of the round that is still
                // live, and it is not.
                .ignoresSafeArea()
                .onTapGesture(perform: onKeepPlaying)
                // Not a control anybody can find with VoiceOver — a swipe
                // must land on the two buttons, and the safe answer is one of
                // them.
                .accessibilityHidden(true)
                .transition(.opacity)

            card
        }
        // What is behind the card is dimmed and unreachable, so VoiceOver must
        // not offer it either. The trait sits on the whole overlay rather than
        // on the card: it makes VoiceOver ignore the *siblings* of the element
        // that carries it, and the round is a sibling of this view, not of the
        // card inside it.
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .readAloudOnce(Self.question)
    }

    private var card: some View {
        ZCard(padding: isCompact ? ZSpacing.step5 : ZSpacing.step6) {
            VStack(spacing: isCompact ? ZSpacing.step5 : ZSpacing.step6) {
                Text(verbatim: Self.question)
                    .typeStyle(isCompact ? .headline : .title, .display, weight: .extraBold)
                    .foregroundStyle(ZColor.textStrong)
                    .multilineTextAlignment(.center)

                answers
            }
        }
        // Never against the screen edge, and on the narrowest phone this is
        // the width the pills need.
        .padding(ZSpacing.step3)
        .transition(.scale(scale: 0.92).combined(with: .opacity))
    }

    /// Both answers at the same size — a child cannot read either of them, so
    /// which is which is carried by colour and position. The safe one is the
    /// filled olive pill at the top; the one that ends the round is the quiet
    /// outline below it, the app's only recessive pressable and the right
    /// weight for the answer nobody should give by accident.
    private var answers: some View {
        VStack(spacing: ZSpacing.step4) {
            ZButton(
                String(localized: "quiz.quit.continue"),
                leadingIcon: .play,
                action: onKeepPlaying,
            )

            ZButton(
                String(localized: "quiz.quit.leave"),
                tone: .quiet,
                leadingIcon: .house,
                action: onLeave,
            )
        }
    }
}

// MARK: - Asking

/// Everything the way out of a round has to decide, in one place.
///
/// The back chevron asks it, and so does the swipe in from the left edge
/// (#150) — so the decision lives here rather than in a button's closure,
/// where the second caller could not reach it.
///
/// Main-actor isolated like everything it touches: a ``QuizSession`` is, and
/// so is the screen that holds this.
@MainActor
struct LeaveRequest {
    /// Whether the question is up. Only ever true over a round that is still
    /// under way.
    fileprivate private(set) var isAsking = false

    /// Somebody wants out of the round.
    ///
    /// A round that is over has nothing left to protect and is left at once —
    /// the blink between the last answer and the round end, and nowhere else.
    /// One that is still under way stops what it was saying and asks first.
    ///
    /// Silence before the card, in this order: ``QuizSession/suspend()`` stops
    /// the call or the sentence and cancels the round's pending move, so
    /// nothing sounds over the question and nothing moves behind it — and the
    /// card's own sentence is not dropped for a call that is still playing
    /// (#30).
    ///
    /// Nothing here puts the question away again: leaving pops the screen, and
    /// this request goes with it.
    mutating func ask(_ round: QuizSession?, orLeave leave: () -> Void) {
        round?.suspend()
        if round?.isFinished == false {
            isAsking = true
        } else {
            leave()
        }
    }

    /// "Weiterspielen". The card goes, and the round is picked up exactly as
    /// coming back to the screen picks it up — ``QuizSession/resume()`` puts
    /// the question again, which is what a child who has just heard a
    /// different sentence needs.
    fileprivate mutating func keepPlaying(_ round: QuizSession?) {
        isAsking = false
        round?.resume()
    }
}

/// Puts ``QuitConfirmation`` over a screen, and points the other way out of
/// that screen at the same question.
///
/// The two belong together: a screen that asks before it is left must not be
/// leavable by a swipe from the edge either — so the swipe asks instead of
/// leaving, which is ``SwipeBack/asks(_:)``. That is the whole difference to
/// every other pushed screen, where the same gesture simply goes back.
///
/// An overlay rather than a sheet: what makes the card understandable to
/// somebody who cannot read is that the round is still there behind it,
/// dimmed and waiting. A sheet would slide the round off the screen and bring
/// a drag-to-dismiss with it — a second way out that answers nothing.
private struct QuitQuestion: ViewModifier {
    @Binding var request: LeaveRequest
    let round: QuizSession?
    let onLeave: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .overlay {
                if request.isAsking {
                    QuitConfirmation(
                        onKeepPlaying: { request.keepPlaying(round) },
                        onLeave: onLeave,
                    )
                }
            }
            // Nothing at all where the system asks for less motion: the card
            // is then simply there, which is the one thing about it that
            // matters.
            .animation(
                reduceMotion ? nil : ZMotion.easeOut.animation(duration: ZMotion.fast),
                value: request.isAsking,
            )
            // The gesture asks the same question as the chevron above it, and
            // the round does not move an inch while it is answered. Nothing
            // follows the finger, because nothing is going anywhere yet.
            .swipesBack(.asks { request.ask(round, orLeave: onLeave) })
    }
}

extension View {
    /// Asks before a running round is left; see ``QuitConfirmation``.
    ///
    /// - Parameters:
    ///   - request: The screen's ``LeaveRequest``, which the back chevron asks.
    ///   - round: The round the question is about.
    ///   - onLeave: What leaving does. The second button, and nothing else.
    func quitQuestion(
        _ request: Binding<LeaveRequest>,
        round: QuizSession?,
        onLeave: @escaping () -> Void,
    ) -> some View {
        modifier(QuitQuestion(request: request, round: round, onLeave: onLeave))
    }
}

#Preview("iPhone portrait", traits: .fixedLayout(width: 390, height: 844)) {
    QuitConfirmation(onKeepPlaying: {}, onLeave: {})
        .environment(\.horizontalSizeClass, .compact)
        .background(ZColor.surfacePage)
}

#Preview("iPad landscape", traits: .fixedLayout(width: 1194, height: 834)) {
    QuitConfirmation(onKeepPlaying: {}, onLeave: {})
        .background(ZColor.surfacePage)
}
