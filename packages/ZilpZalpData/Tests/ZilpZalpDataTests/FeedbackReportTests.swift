import Foundation
import Testing

// @testable for `MediaAsset`'s memberwise initialiser.
@testable import ZilpZalpData

/// The text a grown-up's feedback mail carries for us: which file to look at,
/// and on which screen it showed.
@Suite("A feedback report")
struct FeedbackReportTests {
    @Test("the context names the tile's pack, bird and photo file")
    func contextFindsThePhoto() {
        #expect(report(.tile("amsel"), .crop).context == """
        reason: crop
        pack: deutschland · bird: amsel · photo: photos/amsel-3.heic (sha256 c8cb5d756971)
        game: names · difficulty: medium · screen: question 3 of 10
        tiles: amsel, kohlmeise, rotkehlchen, star
        app: 1.3.0 (231) · iOS 27.1 · iPhone17,3
        """)
    }

    @Test("feedback on the call names the recording")
    func contextForTheCallNamesTheRecording() {
        let call = asset("audio/amsel.m4a", sha256: "825fde8b3c6c0d1e2f3a4b5c6d7e8f90")
        let lines = report(.call, .call, snapshot: snapshot(game: "calls", call: call))
            .context.components(separatedBy: "\n")

        #expect(lines[1] ==
            "pack: deutschland · bird: amsel · call: audio/amsel.m4a (sha256 825fde8b3c6c)")
    }

    @Test("feedback on something else has no asset line")
    func contextForSomethingElseHasNoAssetLine() {
        let lines = report(.other, .other).context.components(separatedBy: "\n")

        #expect(lines.count == 4)
        #expect(!lines.contains { $0.hasPrefix("pack:") })
    }

    @Test("a tile that showed no photo says so")
    func aTileWithoutPhotoSaysSo() {
        let lines = report(.tile("kohlmeise"), .blurry).context.components(separatedBy: "\n")

        #expect(lines[1].contains("photo: none"))
    }

    @Test("the bird's name follows what the grown-up picked")
    func birdNameFollowsTheTarget() {
        #expect(report(.tile("star"), .crop).birdName == "Star")
        #expect(report(.call, .call).birdName == "Amsel")
        #expect(report(.other, .other).birdName == nil)
    }

    @Test("the body puts the trimmed note before the context")
    func bodyPutsTheNoteFirst() {
        let report = report(.tile("amsel"), .crop, note: "  Kopf abgeschnitten\n")

        #expect(report.body() == "Kopf abgeschnitten\n\n" + report.context)
    }

    /// Review focus 5: a blank note leaves no blank lines in front.
    @Test("a note of only whitespace leaves the context alone")
    func bodyWithoutNoteIsTheContextAlone() {
        let report = report(.tile("amsel"), .crop, note: " \n ")

        #expect(report.body() == report.context)
    }

    /// The share sheet cannot preset a recipient, so the text carries it.
    @Test("the share body starts with the address")
    func shareBodyStartsWithTheAddress() {
        let body = report(.other, .other).body(recipient: FeedbackReport.recipient)

        #expect(body.hasPrefix("zilpzalp-app@posteo.net\n\n"))
    }

    // MARK: - Fixture

    private func report(
        _ target: FeedbackTarget,
        _ reason: FeedbackReason,
        note: String = "",
        snapshot: FeedbackSnapshot? = nil,
    ) -> FeedbackReport {
        FeedbackReport(
            snapshot: snapshot ?? self.snapshot(),
            target: target,
            reason: reason,
            note: note,
        )
    }

    private func snapshot(game: String = "names", call: MediaAsset? = nil) -> FeedbackSnapshot {
        let amsel = asset("photos/amsel-3.heic", sha256: "c8cb5d7569716cb2a1b2c3d4e5f60718")
        return FeedbackSnapshot(
            game: game,
            difficulty: "medium",
            question: 3,
            questionCount: 10,
            tiles: [
                .init(species: "amsel", name: "Amsel", pack: "deutschland", photo: amsel),
                .init(species: "kohlmeise", name: "Kohlmeise", pack: "deutschland", photo: nil),
                .init(species: "rotkehlchen", name: "Rotkehlchen", pack: "deutschland", photo: nil),
                .init(species: "star", name: "Star", pack: "deutschland", photo: nil),
            ],
            answer: "amsel",
            call: call,
            app: "1.3.0 (231)",
            system: "iOS 27.1",
            device: "iPhone17,3",
        )
    }

    private func asset(_ file: String, sha256: String) -> MediaAsset {
        MediaAsset(
            file: file,
            sha256: sha256,
            license: .cc0,
            attribution: "Test",
            sourceURL: URL(string: "https://example.org")!,
            retrieved: Date(timeIntervalSince1970: 0),
        )
    }
}
