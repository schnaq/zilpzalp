import Foundation
import SwiftUI
import ZilpZalpUI

/// The adult-level task Guideline 1.3 asks for: a sum whose numbers are
/// written out in words, so solving it needs reading — which is exactly what
/// the children this app is built for cannot do yet.
///
/// Apple's own examples on [The Kids Category](https://developer.apple.com/kids/)
/// show a maths task and a question task and nothing else; a device unlock is
/// deliberately not one of them, because it asks who owns the device rather
/// than who is old enough. See `docs/kids-category.md` §2.
///
/// Two callers, one view. ``ParentsScreen`` puts it up when the device has
/// neither a code nor a face on file, so the grown-ups' area is reachable on
/// every device; ``SwiftUI/View/opensExternalLinks(_:)`` puts it in front of
/// every link that leaves the app (#37). Its whole surface is the reason to
/// show it and what to do when it is solved — no result to read out, no state
/// to hand back in.
///
/// Nothing is stored. Not the question, not the answer, not that anybody
/// passed: the view is built fresh, and the numbers change on every attempt.
/// A wrong answer costs a new question and nothing else — there is no counter,
/// no delay and no way to lock a grown-up out of their own settings.
struct ParentalGate: View {
    /// One sentence saying what is behind the task. Shown above the question,
    /// so a grown-up knows what they are being asked to confirm.
    let reason: String
    /// Run once, when the sum is right.
    let onSuccess: () -> Void

    @State private var question = Question.random()
    /// Whether the last answer was wrong. Only ever changes the hint line —
    /// the numbers have already been replaced by then.
    @State private var lastAnswerWasWrong = false

    var body: some View {
        // A scroll view, because the task is taller than an iPhone in
        // landscape and than a slide-over pane: measured without one, the
        // question and the reason were truncated to "Wie viel ist fünf p…"
        // rather than allowed to wrap. It carries its own gutter so that #37
        // can put it in a sheet without dressing it first.
        ScrollView {
            task
                .frame(maxWidth: ZSpacing.maxContent)
                .padding(ZSpacing.gutterScreen)
                .frame(maxWidth: .infinity)
        }
        // No rubber band on a screen that fits: a page that bounces reads as
        // one that has more below.
        .scrollBounceBehavior(.basedOnSize)
        // Here rather than at the two call sites: the task is a grown-up's
        // whether it stands in the door of the grown-ups' area or in the
        // sheet in front of a link, and the sheet is presented from above the
        // screen's own content (#239).
        .grownUpDynamicType()
        // A gate that is shown a second time asks something else: `@State`
        // survives a re-presentation of the same view, so the numbers are
        // replaced here rather than only at first construction.
        .onAppear { newQuestion() }
        // The spoken hint spec §7 asks for, and the one thing Apple's own page
        // suggests on top of the task itself: "If your app is intended for
        // pre-literate children, consider using a voiceover prompt to help
        // kids know that they need to involve their parent."
        //
        // The hint, never the question. Reading the sum out loud would hand a
        // child the one thing the spelled-out numbers exist to withhold.
        //
        // #35 left this to #37 because the spec names the gate in front of an
        // external link — but it lands in the gate itself rather than at that
        // one call site, because the child meets this view far more often
        // through the fallback on the grown-ups' door.
        .readAloudOnce(.fixed("gate.spoken"))
    }

    private var task: some View {
        VStack(spacing: ZSpacing.step6) {
            Icon(.lock, size: .custom(ZSpacing.touchComfortable))
                .foregroundStyle(ZColor.textMuted)

            Text(verbatim: reason)
                .typeStyle(.bodyLarge, .body, weight: .semibold)
                .foregroundStyle(ZColor.textBody)

            // Always laid out, shown only after a wrong answer: appearing it
            // into the stack would shove the buttons out from under the finger
            // that just missed.
            Text("gate.hint.wrong")
                .typeStyle(.body, .body, weight: .semibold)
                .foregroundStyle(ZColor.textMuted)
                .opacity(lastAnswerWasWrong ? 1 : 0)
                .accessibilityHidden(!lastAnswerWasWrong)

            Text(verbatim: question.text)
                .typeStyle(.title, .display, weight: .bold)
                .foregroundStyle(ZColor.textStrong)

            answers
        }
        .multilineTextAlignment(.center)
    }

    /// The four numbers to choose from, two by two. A row of four would put
    /// them below the touch floor on the narrowest supported screen.
    ///
    /// `large`, not the grown-up `medium`: a pill sizes itself around its
    /// label, and around a single digit `medium` comes out 62 pt across —
    /// under the floor in the one direction nobody measures. `large` is 96 pt
    /// tall and wider than that.
    private var answers: some View {
        LazyVGrid(columns: Self.twoColumns, spacing: ZSpacing.step4) {
            ForEach(question.choices, id: \.self) { choice in
                ZButton(choice.formatted(), tone: .quiet) { answer(choice) }
            }
        }
    }

    private static let twoColumns = Array(
        repeating: GridItem(.flexible(), spacing: ZSpacing.step4),
        count: 2,
    )

    private func answer(_ choice: Int) {
        guard choice == question.answer else {
            // New numbers before the hint, so a grown-up who looks up at the
            // hint is already looking at the task it announces.
            newQuestion()
            lastAnswerWasWrong = true
            return
        }
        onSuccess()
    }

    private func newQuestion() {
        question = .random()
    }
}

// MARK: - The task

/// One sum, with the four numbers it is answered from.
///
/// A value, not a view model: it is made, read once and thrown away.
private struct Question {
    /// Both operands. Single digits from two up — one and zero make the sum
    /// too easy to guess at, and nine plus nine is the largest sum, so the
    /// result never leaves the range a grown-up adds up without thinking.
    static let operands = 2 ... 9
    /// How far a wrong choice sits from the right one. Near misses, so the
    /// answer cannot be picked out as the odd number in the row.
    private static let distractorSpread = 3

    let answer: Int
    /// "Wie viel ist sieben plus vier?" — spelled out, never in digits. Digits
    /// are the one thing a four-year-old may well recognise.
    ///
    /// Written once when the question is made rather than computed on demand:
    /// a computed property would build two `NumberFormatter`s on every pass of
    /// the view's body, and the text cannot change while the question stands.
    let text: String
    /// The right number and three near misses, in a random order.
    let choices: [Int]

    static func random() -> Question {
        let left = Int.random(in: operands)
        let right = Int.random(in: operands)
        let answer = left + right
        let distractors = ((answer - distractorSpread) ... (answer + distractorSpread))
            .filter { $0 != answer && $0 >= operands.lowerBound }
            .shuffled()
            .prefix(3)

        return Question(
            answer: answer,
            text: String(
                format: String(localized: "gate.question"),
                spelled(left),
                spelled(right),
            ),
            choices: ([answer] + distractors).shuffled(),
        )
    }

    /// The app's language, not the device's: ZilpZalp ships German only, and
    /// `Locale.current` on an English phone would spell "seven plus four"
    /// under a German question.
    private static func spelled(_ number: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        formatter.locale = Locale(identifier: Bundle.main.preferredLocalizations.first ?? "de")
        return formatter.string(from: number as NSNumber) ?? number.formatted()
    }
}

#Preview {
    ParentalGate(reason: "Diese Seite ist für Erwachsene.") {}
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(ZColor.surfacePage)
}
