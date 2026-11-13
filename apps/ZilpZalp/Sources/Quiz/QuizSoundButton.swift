import SwiftUI
import ZilpZalpUI

/// The question, put again on demand — read out in game 1, played in game 2 —
/// and, on a tricky question, marked with binoculars on its corner.
///
/// Its own type because it owns what changes on the button from question to
/// question: the tricky mark, its pop and the label that announces it, and
/// the call's rings.
///
/// The rings are the call's. In game 1 `isPlaying` stays false throughout:
/// nothing there comes out of a file, and whether the synthesiser is still
/// speaking is not observable, so rings driven by it would never switch off
/// again.
struct QuizSoundButton: View {
    let session: QuizSession
    let diameter: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        SoundButton(
            isPlaying: session.isCallPlaying,
            label: label,
            diameter: diameter,
        ) { session.askQuestion(unprompted: false) }
            // On the button, not on the written name: game 2 has none, and
            // this is the one part of the row both games draw (#220).
            .accessibilityIdentifier(QuizIdentifier.question(session.answer?.id))
            .overlay(alignment: .topTrailing) { trickyMark }
    }

    /// The badge on the corner, overhanging it by no more than 8 pt. Taps pass
    /// through it to the button underneath.
    ///
    /// Animated on the question rather than on the flag, so it pops in with
    /// each tricky question; under reduced motion it simply appears.
    private var trickyMark: some View {
        ZStack {
            if session.isTricky {
                GlyphBadge(.binoculars, diameter: max(44, diameter * 0.35))
                    .offset(x: 6, y: -4)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    // A fresh badge per question, so two tricky questions in
                    // a row each pop in instead of the second one sitting
                    // there already.
                    .id(session.index)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(
            reduceMotion ? nil : ZMotion.easeBounce.animation(duration: ZMotion.slow),
            value: session.index,
        )
    }

    /// What VoiceOver says the button will do, which is what it is about to
    /// say or play. Game 1 names the bird — the name is the whole question,
    /// and the button says it anyway. Game 2 must not: there it is the answer.
    /// A tricky question says so too, since the badge is not in VoiceOver's
    /// reach.
    private var label: String {
        let action = if let name = session.writtenQuestion {
            String(format: String(localized: "quiz.sound.name.accessibility"), name)
        } else {
            String(localized: "quiz.sound.call.accessibility")
        }
        guard session.isTricky else { return action }
        return "\(action). \(String(localized: "quiz.tricky.accessibility"))"
    }
}
