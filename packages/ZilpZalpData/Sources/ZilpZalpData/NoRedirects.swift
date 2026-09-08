import Foundation

/// Refuses every HTTP redirect.
///
/// `URLSession` follows redirects by default, so a `302` in an answer from the
/// bucket would send the next request to whatever host it names — and the app
/// is allowed exactly one. Returning `nil` leaves the redirect response
/// standing, which `PackDownloader.fetch` then reports as the failure it is.
///
/// Stateless, hence `@unchecked Sendable`: there is nothing to race over, and
/// `NSObject` cannot be `Sendable` on its own.
final class NoRedirects: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    static let shared = NoRedirects()

    func urlSession(
        _: URLSession,
        task _: URLSessionTask,
        willPerformHTTPRedirection _: HTTPURLResponse,
        newRequest _: URLRequest,
    ) async -> URLRequest? {
        nil
    }
}
