import XCTest

/// The five pictures App Store Connect asks for, taken by playing the app.
///
/// Not a test of anything, and it asserts only enough to fail loudly rather
/// than write five pictures of the wrong screen. What it produces is
/// `01-home.png` to `05-collection.png` under the directory
/// `mise run screenshots` names — raw captures of the whole screen, no device
/// frames and no captions.
///
/// **No part of `mise run check` or of CI.** It wants a booted simulator and
/// takes minutes, and neither belongs in a gate that runs on every commit.
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

    /// The prefixes `QuizIdentifier` writes, spelled a second time because a
    /// UI test runs in its own process and links nothing of the app.
    private static let questionPrefix = "quiz.question."
    private static let tilePrefix = "quiz.tile."

    /// German, because the app is: these are the words on the things a child
    /// taps, and the app is built to be localisable but ships in one language.
    private static let gameNames = "Wer ist das?"
    private static let gameCalls = "Wer singt da?"
    private static let album = "Meine Sammlung"
    private static let playAgain = "Nochmal spielen"

    /// A round is ten questions, and ten answered right at the first attempt
    /// is exactly what earns the three stars screenshot 4 is about.
    private static let questionsInARound = 10

    /// How long a screen may take to arrive. Generous: a cold launch on a
    /// simulator that has just been booted is slower than anything else here.
    private static let arrival: TimeInterval = 60

    /// What a screen is given to come to rest before it is captured. The
    /// slowest thing any of the five does is the round end, which writes the
    /// round down before it says anything about it and then pops the sticker
    /// in over `--dur-celebrate`.
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
        // The album's own title rather than anything it offers: the home
        // screen's door to it carries the same words, but as a button's label
        // and never as a line of text on the page.
        XCTAssertTrue(app.staticTexts[Self.album].waitForExistence(timeout: Self.arrival))
        capture("05-collection", into: output)
    }

    /// 2 and 4: game 1's question, and the end of the round it opens.
    private func captureNamesAndItsRoundEnd(_ app: XCUIApplication, into output: URL) {
        launch(app)

        XCTAssertTrue(app.buttons[Self.gameNames].waitForExistence(timeout: Self.arrival))
        app.buttons[Self.gameNames].tap()

        guard let asked = waitForQuestion(app) else {
            return XCTFail("Game 1 put no question")
        }
        capture("02-names", into: output)

        answerCorrectly(app, startingWith: asked)
        XCTAssertTrue(app.buttons[Self.playAgain].waitForExistence(timeout: Self.arrival))
        capture("04-round-end", into: output)
    }

    /// 3: game 2's question, with the sound button that puts it again.
    private func captureCalls(_ app: XCUIApplication, into output: URL) {
        launch(app)

        XCTAssertTrue(app.buttons[Self.gameCalls].waitForExistence(timeout: Self.arrival))
        app.buttons[Self.gameCalls].tap()

        XCTAssertNotNil(waitForQuestion(app), "Game 2 put no question")
        capture("03-calls", into: output)
    }

    // MARK: - Playing a round

    /// Answers every question of the round right at the first attempt.
    ///
    /// Waits for the question to change rather than for a fixed pause: an
    /// answered question stays up for `--dur-celebrate` before the round moves
    /// on, and a second tap on the same species is ignored — so a loop that
    /// only slept would answer the first question ten times over.
    private func answerCorrectly(_ app: XCUIApplication, startingWith first: String) {
        var asked: String? = first
        for _ in 0 ..< Self.questionsInARound {
            guard let species = asked else { return }
            app.buttons[Self.tilePrefix + species].tap()
            XCTAssertTrue(
                waitUntil { self.askedSpecies(app) != species },
                "The round did not move on from \(species)",
            )
            asked = askedSpecies(app)
        }
    }

    /// The species the question asks for, once one is up.
    private func waitForQuestion(_ app: XCUIApplication) -> String? {
        var species: String?
        _ = waitUntil(timeout: Self.arrival) {
            species = self.askedSpecies(app)
            return species != nil
        }
        return species
    }

    /// The species the question asks for right now, `nil` between rounds and
    /// once the last question is answered.
    private func askedSpecies(_ app: XCUIApplication) -> String? {
        let question = app.staticTexts
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
    /// window, and the store wants the whole screen with its status bar. The
    /// alpha channel every simulator capture carries is taken out afterwards
    /// by `tools/strip_alpha.py` — App Store Connect refuses an RGBA PNG.
    private func capture(_ name: String, into output: URL) {
        Thread.sleep(forTimeInterval: Self.settling)
        let file = output.appending(path: "\(name).png")
        XCTAssertNoThrow(try XCUIScreen.main.screenshot().pngRepresentation.write(to: file))
    }

    /// Polls until `condition` holds or the wait runs out.
    ///
    /// XCTest's own expectations watch one element; what a round waits for is
    /// the question changing from one species to another, and that is a query.
    private func waitUntil(timeout: TimeInterval = 20, _ condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() {
                return true
            }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return condition()
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
