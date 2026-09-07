import CryptoKit
import Foundation
import Synchronization
@testable import ZilpZalpData

/// A stand-in for the media bucket: a `URLProtocol` that answers from a
/// dictionary of bucket keys.
///
/// A protocol on an ephemeral session rather than a real HTTP listener,
/// because it needs no port, no start-up and no teardown, and because it
/// records every URL the downloader opened — which is how the tests show that
/// nothing but the base URL is ever contacted. The one thing it cannot express
/// is a genuine socket failure, and no test here needs one.
///
/// The bucket is static, as `URLProtocol` instances are made by the session
/// rather than by us, so the suite using it runs serialized.
final class StubBucket: URLProtocol {
    /// One object in the stand-in bucket.
    struct Route: Sendable {
        var body: Data
        var status = 200
        /// Seconds until the answer arrives. Only the cancellation test uses
        /// it, to hold a request open long enough to cancel it — a late answer
        /// rather than none at all, so that a cancellation which failed ends
        /// the test instead of hanging it.
        var delay: TimeInterval = 0
    }

    private struct Contents {
        var routes: [String: Route] = [:]
        var requests: [URL] = []
    }

    private static let contents = Mutex(Contents())

    /// Set in `stopLoading()`, read before a delayed answer is handed over: a
    /// cancelled request must not reach its client afterwards.
    private let stopped = Mutex(false)

    /// A session that reaches this bucket and nothing else. Ephemeral, so no
    /// answer survives into the next test.
    static func session() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubBucket.self]
        return URLSession(configuration: configuration)
    }

    /// Fills the bucket and forgets what the previous test asked for.
    static func fill(with routes: [String: Route]) {
        contents.withLock {
            $0.routes = routes
            $0.requests = []
        }
    }

    /// Replaces one object without forgetting the requests so far — a bucket
    /// that was broken while a download ran and is whole again for the retry.
    static func serve(_ key: String, _ route: Route) {
        contents.withLock { $0.routes[key] = route }
    }

    /// Every URL that was requested, in order.
    static var requests: [URL] {
        contents.withLock { $0.requests }
    }

    /// How often one bucket key was requested.
    static func requestCount(for key: String) -> Int {
        requests.count { $0.path(percentEncoded: false) == "/" + key }
    }

    // MARK: - URLProtocol

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else { return }
        let route = Self.contents.withLock { contents -> Route? in
            contents.requests.append(url)
            return contents.routes[String(url.path(percentEncoded: false).dropFirst())]
        }

        // A key nobody put there answers the way the bucket does: 404.
        let answer = route ?? Route(body: Data(), status: 404)
        guard
            let response = HTTPURLResponse(
                url: url,
                statusCode: answer.status,
                httpVersion: "HTTP/1.1",
                headerFields: nil,
            )
        else {
            return
        }

        let delivery = Delivery(bucket: self, response: response, body: answer.body)
        if answer.delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + answer.delay) { delivery.send() }
        } else {
            delivery.send()
        }
    }

    override func stopLoading() {
        stopped.withLock { $0 = true }
    }

    /// Carries an answer onto the delivery queue.
    ///
    /// Neither `URLProtocol` nor its client is `Sendable`, and their contract
    /// is that the protocol calls the client from whatever thread it loads on.
    /// The box states that rather than fighting it.
    private struct Delivery: @unchecked Sendable {
        let bucket: StubBucket
        let response: HTTPURLResponse
        let body: Data

        func send() {
            guard let client = bucket.client, !bucket.stopped.withLock({ $0 }) else { return }
            client.urlProtocol(bucket, didReceive: response, cacheStoragePolicy: .notAllowed)
            client.urlProtocol(bucket, didLoad: body)
            client.urlProtocolDidFinishLoading(bucket)
        }
    }
}

/// The pack the stand-in bucket serves, and the bytes behind it.
///
/// Generated rather than copied from `Fixtures/valid/basis.json`: that manifest
/// carries the digests of the real photos, and a download test needs bytes it
/// controls together with their true SHA-256. The shape is the base pack's —
/// two birds, the second with a call — so both kinds of medium are exercised.
enum StubPack {
    static let id = "deutschland"
    static let title = "Vögel in Deutschland"
    static let indexKey = "packs/index.json"
    static let manifestKey = "packs/\(id)/manifest.json"

    /// One medium of a manifest: the path it declares and the digest it promises.
    struct Asset {
        var file: String
        var sha256: String
    }

    /// Path relative to the manifest and the bytes behind it. Tiny on purpose:
    /// what a download has to get right is the digest, not that it is a PNG.
    static let media: [(file: String, bytes: Data)] = [
        ("photos/amsel.png", Data("amsel".utf8)),
        ("photos/zilpzalp.png", Data("zilpzalp".utf8)),
        ("calls/zilpzalp.m4a", Data("zilpzalp ruft".utf8)),
    ]

    static let assets = media.map { Asset(file: $0.file, sha256: sha256(of: $0.bytes)) }

    /// Where a medium sits in the bucket.
    static func key(for file: String) -> String {
        "packs/\(id)/\(file)"
    }

    static func sha256(of data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// The bucket as the downloader should find it: index, manifest, media.
    static func routes(manifest document: Data = manifest()) -> [String: StubBucket.Route] {
        var routes = [
            indexKey: StubBucket.Route(body: index(for: document)),
            manifestKey: StubBucket.Route(body: document),
        ]
        for medium in media {
            routes[key(for: medium.file)] = StubBucket.Route(body: medium.bytes)
        }
        return routes
    }

    /// What the index promises a download costs: every object of the pack,
    /// the manifest included, exactly as `tools/fetch_media/index.py` sums it.
    static func downloadSize(of document: Data) -> Int {
        document.count + media.reduce(0) { $0 + $1.bytes.count }
    }

    static func index(for document: Data) -> Data {
        Data("""
        {
          "packs": [
            {
              "id": "\(id)",
              "title": "\(title)",
              "speciesCount": 2,
              "downloadSize": \(downloadSize(of: document)),
              "manifest": "\(manifestKey)"
            }
          ]
        }
        """.utf8)
    }

    /// The entry a test hands to `download`, without going through the index.
    static func entry(
        id packID: String = id,
        manifest document: Data = manifest(),
    ) -> PackIndex.Entry {
        PackIndex.Entry(
            id: packID,
            title: title,
            speciesCount: 2,
            downloadSize: downloadSize(of: document),
            manifest: manifestKey,
        )
    }

    static func manifest(
        packID: String = id,
        amselPhoto: Asset = assets[0],
        zilpzalpPhoto: Asset = assets[1],
        zilpzalpCall: Asset = assets[2],
    ) -> Data {
        Data("""
        {
          "id": "\(packID)",
          "title": "\(title)",
          "birds": [
            {
              "id": "amsel",
              "name": "Amsel",
              "scientificName": "Turdus merula",
              "taxonID": 12716,
              "article": "die",
              "pronunciation": null,
              "photo": \(json(amselPhoto)),
              "call": null
            },
            {
              "id": "zilpzalp",
              "name": "Zilpzalp",
              "scientificName": "Phylloscopus collybita",
              "taxonID": 117016,
              "article": "der",
              "pronunciation": "Tsilp-Tsalp",
              "photo": \(json(zilpzalpPhoto)),
              "call": \(json(zilpzalpCall))
            }
          ]
        }
        """.utf8)
    }

    private static func json(_ asset: Asset) -> String {
        """
        {
              "file": "\(asset.file)",
              "sha256": "\(asset.sha256)",
              "license": "CC-BY-4.0",
              "attribution": "Alexis Tinker-Tsavalas",
              "sourceURL": "https://www.inaturalist.org/observations/20490738",
              "retrieved": "2026-07-31"
            }
        """
    }
}
