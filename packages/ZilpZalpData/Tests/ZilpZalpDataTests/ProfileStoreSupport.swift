import Foundation
import Testing

/// What the profile suites need in common.
///
/// Every test gets a directory of its own, so none of them ever sees the
/// Application Support of the machine it runs on, and every date is fixed in
/// a calendar of its own: read in the host's calendar, a day-key assertion
/// would pass on a Mac in Berlin and fail on a runner shortly before
/// midnight.
let testCalendar: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = .gmt
    return calendar
}()

/// Noon on that day in ``testCalendar``, so that a time zone an hour either
/// way cannot move the date.
func noon(_ year: Int, _ month: Int, _ day: Int) throws -> Date {
    try #require(
        testCalendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)),
    )
}

/// Runs `body` against a directory of its own and removes it afterwards. The
/// directory itself is not created: the store makes it on its first write,
/// and one test holds it to that.
func withTemporaryDirectory(_ body: (URL) async throws -> Void) async throws {
    let directory = URL.temporaryDirectory
        .appending(path: "ProfileStoreTests-\(UUID().uuidString)")
    defer { try? FileManager.default.removeItem(at: directory) }
    try await body(directory)
}

func profileFileURL(in directory: URL) -> URL {
    directory.appending(path: "Profiles/profiles.json")
}

/// Puts a file where the store looks for it.
func seedProfileFile(_ contents: Data, in directory: URL) throws {
    let file = profileFileURL(in: directory)
    try FileManager.default.createDirectory(
        at: file.deletingLastPathComponent(),
        withIntermediateDirectories: true,
    )
    try contents.write(to: file)
}

func profileFileText(in directory: URL) throws -> String {
    try String(contentsOf: profileFileURL(in: directory), encoding: .utf8)
}

/// A profile file as an earlier build wrote it. Its keys stand in the order a
/// person would write them rather than the order the store writes them —
/// which is the point: reading a file must not depend on its key order.
func profileFixture(_ name: String) throws -> Data {
    let url = try #require(
        Bundle.module.url(
            forResource: name,
            withExtension: "json",
            subdirectory: "Fixtures/profiles",
        ),
        "no fixture \(name).json in the test bundle",
    )
    return try Data(contentsOf: url)
}
