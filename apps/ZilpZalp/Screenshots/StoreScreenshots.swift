import XCTest

/// The five pictures App Store Connect asks for, taken by playing the app.
///
/// Not a test of anything, and it asserts only enough to fail loudly rather
/// than write five pictures of the wrong screen. What it produces is
/// `01-home.png` to `05-collection.png` under the directory
/// `mise run screenshots` names — raw captures of the whole screen, no device
/// frames and no captions.
///
/// **Nothing builds or runs it but `mise run screenshots`** — not the
/// `ZilpZalp` scheme, not `mise run check`, not CI. It wants a booted
/// simulator and takes minutes, and neither belongs in a gate that runs on
/// every commit. The source is still formatted and linted with the rest of
/// `apps/`, which is a different thing and a good one.
///
/// **It never touches the profiles on the machine it runs on.** The app is
/// launched with `-screenshots` and then keeps its child, its stars and the
/// grown-ups' settings under a temporary directory of its own; see
/// `ScreenshotSeed` in the app target.
final class StoreScreenshots: XCTestCase {
    /// What the app is launched with. `ScreenshotSeed` reads it.
    private static let screenshotMode = "-screenshots"

    /// Where the pictures go. `mise run screenshots` sets it as
    /// `TEST_RUNNER_SCREENSHOT_DIR`, and xcodebuild hands every
    /// `TEST_RUNNER_`-prefixed variable to the runner with the prefix off.
    private static let outputVariable = "SCREENSHOT_DIR"

    /// What a question identifier reads before the species it asks for — and
    /// on its own, what one with nothing left to ask reads. Taken from
    /// `QuizIdentifier` itself, which `project.yml` compiles into this target
    /// as well: a rename there is then a compile error here rather than a
    /// question that never turns up.
    private static let questionPrefix = QuizIdentifier.question(nil)

    /// German, because the app is: these are the words on the things a child
    /// taps, and the app is built to be localisable but ships in one language.
    private static let gameNames = "Finde den Vogel"
    private static let gameCalls = "Wer singt da?"
    private static let album = "Sammlung"
    private static let playAgain = "Nochmal spielen"

    /// The album's own headline, which is the child's name in the genitive
    /// (#204) — `ScreenshotSeed` names her Mia. Not the word on the pill that
    /// opens it, which the home screen shares with the round end (#212).
    private static let albumTitle = "Mias Sammlung"

    /// A round is ten questions, and ten answered right at the first attempt
    /// is exactly what earns the three stars screenshot 4 is about.
    private static let questionsInARound = 10

    /// How long a screen may take to arrive. Generous: a cold launch on a
    /// simulator that has just been booted is slower than anything else here.
    private static let arrival: TimeInterval = 60

    /// How often the question is read while waiting for it to change.
    private static let poll: TimeInterval = 0.1

    /// What a screen is given to come to rest before it is captured.
    ///
    /// Every capture gets it, not only the round end that needs the most:
    /// an element existing is not the same as its photos being drawn, and
    /// four of the five screens are mostly photographs. Fifteen seconds
    /// across a run this task is measured in minutes is the cheapest
    /// insurance here against a picture of a half-drawn screen.
    private static let settling: TimeInterval = 1.5

    override func setUp() {
        super.setUp()
        // A picture of the wrong screen is worse than no picture: stop at the
        // first thing that is not where it should be.
        continueAfterFailure = false
    }

    func testTakesTheStoreScreenshots() throws {
        let output = try outputDirectory()
        let app = XCUIApplication()
        app.launchArguments = [Self.screenshotMode]

        // Three launches rather than one walk through the app. Every way back
        // out of a screen here is a screen of its own — the quit card in front
        // of a running round, a chevron whose twin is still in the hierarchy
        // on the screen underneath — and a relaunch is both shorter to write
        // and a child that has not just played.
        try captureHomeAndTheAlbum(app, into: output)
        captureNamesAndItsRoundEnd(app, into: output)
        captureCalls(app, into: output)
    }

    // MARK: - The five screens

    /// 1 and 5: the home screen and the album.
    ///
    /// The album is taken before any round is played and not after: a round
    /// asks for every species of the base pack, so one round leaves an album
    /// with nothing still to find — and the gap is the whole point of a
    /// sticker album.
    private func captureHomeAndTheAlbum(_ app: XCUIApplication, into output: URL) throws {
        launch(app)

        XCTAssertTrue(app.buttons[Self.gameNames].waitForExistence(timeout: Self.arrival))
        // Game 2 is offered only where four species carry a call on disk. It
        // is asserted here rather than discovered as a missing tile later,
        // because without it screenshot 1 shows one tile and 3 is impossible.
        XCTAssertTrue(app.buttons[Self.gameCalls].exists, "The pack carries too few calls")
        capture("01-home", into: output)

        app.buttons[Self.album].tap()
        // The album's own headline, which no other screen carries: the door to
        // it is a pill reading "Sammlung", and the page behind it is the
        // child's own album.
        XCTAssertTrue(app.staticTexts[Self.albumTitle].waitForExistence(timeout: Self.arrival))
        capture("05-collection", into: output)
    }

    /// 2 and 4: game 1's question, and the end of the round it opens.
    private func captureNamesAndItsRoundEnd(_ app: XCUIApplication, into output: URL) {
        guard let asked = openGame(app, Self.gameNames) else { return }
        capture("02-names", into: output)

        answerCorrectly(app, startingWith: asked)
        XCTAssertTrue(app.buttons[Self.playAgain].waitForExistence(timeout: Self.arrival))
        capture("04-round-end", into: output)
    }

    /// 3: game 2's question, with the sound button that puts it again.
    private func captureCalls(_ app: XCUIApplication, into output: URL) {
        guard openGame(app, Self.gameCalls) != nil else { return }
        capture("03-calls", into: output)
    }

    // MARK: - Playing a round

    /// Launches the app, opens the game whose tile reads `title`, and waits
    /// for its first question.
    ///
    /// - Returns: the species that question asks for, or `nil` — having
    ///   already failed the test — when no question turned up.
    private func openGame(_ app: XCUIApplication, _ title: String) -> String? {
        launch(app)

        XCTAssertTrue(app.buttons[title].waitForExistence(timeout: Self.arrival))
        app.buttons[title].tap()

        let asked = waitForQuestion(app, after: nil)
        XCTAssertNotNil(asked, "\(title) put no question")
        return asked
    }

    /// Answers every question of the round right at the first attempt, which
    /// is what a three-star round is.
    ///
    /// Each answer waits for the question to change rather than for a fixed
    /// pause: an answered question stays up for `--dur-celebrate` before the
    /// round moves on, and a second tap on the same species is ignored — so a
    /// loop that only slept would answer the first question ten times over.
    ///
    /// "Changed" is read off the species, which is only the same thing while
    /// the pack has at least as many species to ask for as the round has
    /// questions — `Round.answers` shuffles a fresh pass once it runs out,
    /// and a smaller pack could put one bird at the end of one pass and the
    /// start of the next. The bundled pack has ten of each, and the assertion
    /// below says so rather than leaving a shrunken pack to look like a round
    /// that hung.
    private func answerCorrectly(_ app: XCUIApplication, startingWith first: String) {
        var asked: String? = first
        for _ in 0 ..< Self.questionsInARound {
            guard let species = asked else { return }
            app.buttons[QuizIdentifier.tile(species)].tap()
            asked = waitForQuestion(app, after: species)
            // Without this the loop would tap the same tile again, and again,
            // each time waiting out the whole of `arrival`. `setUp` turns the
            // first failure into the end of the run.
            XCTAssertNotEqual(
                asked,
                species,
                "The round did not move on from \(species) — a pack with fewer "
                    + "than \(Self.questionsInARound) species can ask twice in a row",
            )
        }
    }

    /// The species the question asks for, once it is one other than
    /// `previous`.
    ///
    /// `nil` is "no question up", which is where a round both starts and
    /// ends — so waiting for the question to *change* covers the first one
    /// arriving and the last one being answered under a single rule, and
    /// neither has to be told apart from the other.
    ///
    /// Polled rather than expected: `XCTNSPredicateExpectation` watches one
    /// element, and which element carries the question changes with the
    /// question. The value that ends the wait is the value handed back, so
    /// there is one query per poll and no second one that could disagree.
    private func waitForQuestion(_ app: XCUIApplication, after previous: String?) -> String? {
        let deadline = Date().addingTimeInterval(Self.arrival)
        var species = askedSpecies(app)
        while species == previous, Date() < deadline {
            Thread.sleep(forTimeInterval: Self.poll)
            species = askedSpecies(app)
        }
        return species
    }

    /// The species the question asks for right now, `nil` between rounds and
    /// once the last question is answered.
    ///
    /// The sound button carries it, in both games. Game 2 writes no question
    /// at all since #220 — the name would be the answer — so a text is not
    /// something both games have; the button that puts the question again is.
    private func askedSpecies(_ app: XCUIApplication) -> String? {
        let question = app.buttons
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", Self.questionPrefix))
            .firstMatch
        guard question.exists else { return nil }
        let species = question.identifier.dropFirst(Self.questionPrefix.count)
        return species.isEmpty ? nil : String(species)
    }

    // MARK: - Driving and capturing

    private func launch(_ app: XCUIApplication) {
        app.launch()
        // Nothing else pins the simulator to portrait, and the iPad picture
        // App Store Connect wants is 2064x2752 — portrait. The phone allows
        // nothing else and ignores this.
        XCUIDevice.shared.orientation = .portrait
    }

    /// Writes the screen as it stands to `<output>/<name>.png`.
    ///
    /// `XCUIScreen` and not `XCUIApplication`: the app's own screenshot is its
    /// window, and the store wants the whole screen with its status bar. What
    /// the store then insists on — the exact pixel size, and no alpha channel
    /// — is `tools/finish_screenshots.py`'s to check once the run is over.
    private func capture(_ name: String, into output: URL) {
        Thread.sleep(forTimeInterval: Self.settling)
        let file = output.appending(path: "\(name).png")
        XCTAssertNoThrow(try XCUIScreen.main.screenshot().pngRepresentation.write(to: file))
    }

    /// The directory the pictures are written to, created if it is not there.
    private func outputDirectory() throws -> URL {
        let path = try XCTUnwrap(
            ProcessInfo.processInfo.environment[Self.outputVariable],
            "\(Self.outputVariable) is unset — run this through `mise run screenshots`",
        )
        let output = URL(filePath: path)
        try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
        return output
    }
}
