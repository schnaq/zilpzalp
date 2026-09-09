import CryptoKit
import Foundation

/// The lowercase hex SHA-256 of a file, spelled the way a manifest records it.
///
/// Every suite that resolves a medium ends in this comparison — photos, calls
/// and recorded sentences, in the bundled pack and in the fixtures — so it is
/// written once.
func sha256(of url: URL) throws -> String {
    let data = try Data(contentsOf: url)
    return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
}
