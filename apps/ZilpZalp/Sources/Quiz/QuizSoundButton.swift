import SwiftUI
import ZilpZalpUI

/// The question, put again on demand — read out in game 1, played in game 2 —
/// and, on a tricky question, marked with binoculars on its corner.
///
/// Its own type rather than a method of ``QuizScreen``: the screen sits on
/// SwiftLint's 400-line ceiling, and the button is the one part of it that
/// two things — the call's rings and the tricky mark — change from question to
/// question.
///
/// The rings are the call's. In game 1 `isPlaying` stays false throughout:
/// nothing there comes out of a file, and whether the synthesiser is still
/// speaking is not observable, so rings driven by it would never switch off
/// again.
struct QuizSoundButton: View {
    let session: QuizSession
    let diameter: CGFloat
    let isCompact: Bool

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

    /// The badge, stuck on the corner and overhanging it by no more than 8 pt:
    /// 56 pt on the iPad's 160 pt button, 44 pt on the phone's 120 pt one. It
    /// is a picture and not a control, so taps pass through to the button
    /// underneath.
    ///
    /// Animated on the question rather than on the flag: it pops in when a
    /// tricky question appears and does nothing otherwise, and the pop is
    /// skipped altogether under reduced motion.
    private var trickyMark: some View {
        ZStack {
            if session.isTricky {
                GlyphBadge(.binoculars, diameter: max(44, diameter * 0.35))
                    .offset(x: isCompact ? 6 : 8, y: -4)
                    .allowsHitTesting(false)
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
