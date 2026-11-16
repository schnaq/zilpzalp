import Testing
@testable import ZilpZalpUI

// Which leaves of the progress row open a look back at their question. Apart
// from `QuizComponentTests` only because that suite is at SwiftLint's length.

@MainActor
@Suite("Quiz progress opening")
struct QuizProgressOpeningTests {
    @Test("Only answered leaves open, and only when someone listens")
    func openableLeaves() {
        let quiet = QuizProgress(total: 10, completed: 3, current: 3, label: "Fortschritt")
        #expect(quiet.openableLeaves.isEmpty)
        let open = QuizProgress(
            total: 10, completed: 3, current: 3, label: "Fortschritt", onOpen: { _ in },
        )
        #expect(open.openableLeaves == 0 ..< 3)
        let fresh = QuizProgress(
            total: 10, completed: 0, current: 0, label: "Fortschritt", onOpen: { _ in },
        )
        #expect(fresh.openableLeaves.isEmpty)
    }

    @Test("Opening changes nothing the row draws")
    func openingKeepsTheLeaves() {
        let plain = QuizProgress(total: 5, completed: 2, current: 2, label: "Fortschritt")
        let open = QuizProgress(
            total: 5, completed: 2, current: 2, label: "Fortschritt", onOpen: { _ in },
        )
        #expect(plain.leafStates == open.leafStates)
    }
}
