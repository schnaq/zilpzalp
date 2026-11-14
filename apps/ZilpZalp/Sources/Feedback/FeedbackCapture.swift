import SwiftUI
import UIKit
import ZilpZalpData

/// One screenshot moment of a round: the app's own window as an image, and the
/// round as it stood — taken together, so the report describes what the
/// grown-up saw even if the child answers before the hint is tapped.
struct FeedbackCapture: Identifiable {
    let id = UUID()
    /// The app's own window. Never the system screenshot: that lives in Photos,
    /// which the app does not read and needs no permission for.
    let screenshot: UIImage
    let snapshot: FeedbackSnapshot
    /// Each tile's image at that moment, by species id, for the sheet's "which
    /// one?" row.
    let thumbnails: [String: Image]

    /// Everything at once and before any state changes, so the hint is never
    /// in the image. `nil` once the round is over or without a window to draw.
    @MainActor
    static func take(of session: QuizSession) -> FeedbackCapture? {
        guard let window = activeWindow,
              let snapshot = session.feedbackSnapshot(
                  app: appVersion,
                  system: systemVersion,
                  device: deviceModel,
              )
        else { return nil }

        let screenshot = UIGraphicsImageRenderer(bounds: window.bounds).image { _ in
            _ = window.drawHierarchy(in: window.bounds, afterScreenUpdates: false)
        }
        let thumbnails = session.choices.reduce(into: [String: Image]()) { thumbnails, bird in
            thumbnails[bird.id] = session.photo(for: bird)
        }
        return FeedbackCapture(screenshot: screenshot, snapshot: snapshot, thumbnails: thumbnails)
    }

    /// The key window of the scene in front — on an iPad in Split View the one
    /// the screenshot was taken in.
    @MainActor
    private static var activeWindow: UIWindow? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }?
            .keyWindow
    }

    /// "1.3.0 (231)".
    private static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }

    /// "iOS 27.1".
    @MainActor
    private static var systemVersion: String {
        "\(UIDevice.current.systemName) \(UIDevice.current.systemVersion)"
    }

    /// "iPhone17,3" — the model identifier, which tells a crop problem on an
    /// iPhone SE from one on an iPad. The simulator reports the Mac's
    /// architecture there, so it names the simulated model instead.
    private static var deviceModel: String {
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }
        var system = utsname()
        uname(&system)
        return withUnsafeBytes(of: system.machine) { bytes in
            String(bytes: bytes.prefix { $0 != 0 }, encoding: .utf8) ?? "?"
        }
    }
}
