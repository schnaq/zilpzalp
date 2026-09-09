import Foundation

extension URL {
    /// The file a manifest names relative to the directory it lies in, `nil`
    /// when it is not on disk.
    ///
    /// The one rule every medium follows — a photo, a call, a recorded
    /// sentence, in a pack or in the fixed set — so ``PackCatalog`` and
    /// ``SpeechCatalog`` both resolve through it rather than each spelling it
    /// out. `nil` rather than a URL that fails later: a tile then draws its
    /// placeholder and the player stays silent.
    func mediaFile(_ relative: String) -> URL? {
        let file = appending(path: relative)
        guard FileManager.default.fileExists(atPath: file.path(percentEncoded: false)) else {
            return nil
        }
        return file
    }
}
