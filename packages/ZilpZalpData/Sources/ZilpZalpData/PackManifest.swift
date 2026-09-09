import Foundation

/// Decodes the pack manifests that live under `data/packs/`.
///
/// The single place that knows how a manifest is spelled. Whoever builds
/// their own `JSONDecoder` for it will sooner or later parse the dates
/// differently.
public enum PackManifest {
    /// One decoder for every manifest.
    private static let decoder: JSONDecoder = {
        let formatter = DateFormatter()
        // Fixed locale and time zone: with the device's own, the same
        // manifest would yield different dates, and a non-Gregorian calendar
        // would not parse `retrieved` at all.
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(identifier: "UTC")
        formatter.dateFormat = "yyyy-MM-dd"

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .formatted(formatter)
        // The default, spelled out: the JSON keys are the property names
        // (`sourceURL`, `taxonID`), and no key mapping may rewrite them.
        decoder.keyDecodingStrategy = .useDefaultKeys
        return decoder
    }()

    /// Decodes one pack manifest.
    ///
    /// - Parameter data: the manifest's UTF-8 bytes.
    /// - Returns: the decoded pack.
    /// - Throws: `DecodingError` naming the field at fault — a missing
    ///   required key, a licence outside `License`, or a `retrieved` value
    ///   that is not a `YYYY-MM-DD` date.
    public static func decode(_ data: Data) throws -> Pack {
        try decode(Pack.self, from: data)
    }

    /// Decodes any manifest with the one decoder above.
    ///
    /// The fixed sentences under `data/speech/` are a manifest too — the same
    /// dates, the same keys, no birds — and reading them through a second
    /// decoder is exactly the drift this type exists to prevent.
    static func decode<Document: Decodable>(
        _ type: Document.Type,
        from data: Data,
    ) throws -> Document {
        try decoder.decode(type, from: data)
    }
}
