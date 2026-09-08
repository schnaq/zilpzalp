import CoreText
import Foundation

/// Registers the two variable fonts once for the whole test run — Swift
/// Testing runs cases in parallel, and registering the same URL twice fails.
///
/// The package ships no fonts; the app target does, through `UIAppFonts`. A
/// test that measures type has to reach for those files itself, or CoreText
/// hands back the system face and its ~1.2 box quietly stands in for the
/// design's.
enum BundledFonts {
    static let registered: Bool = {
        let fonts = URL(fileURLWithPath: #filePath)
            // …/packages/ZilpZalpUI/Tests/ZilpZalpUITests/BundledFonts.swift
            .deletingLastPathComponent() // ZilpZalpUITests
            .deletingLastPathComponent() // Tests
            .deletingLastPathComponent() // ZilpZalpUI
            .deletingLastPathComponent() // packages
            .deletingLastPathComponent() // repository root
            .appending(path: "apps/ZilpZalp/Resources/Fonts")

        return [
            "Baloo2/Baloo2-VariableFont_wght.ttf",
            "Nunito/Nunito-VariableFont_wght.ttf",
        ].allSatisfy { relativePath in
            var error: Unmanaged<CFError>?
            let url = fonts.appending(path: relativePath) as CFURL
            if CTFontManagerRegisterFontsForURL(url, .process, &error) {
                return true
            }
            // The app target registers the same files through `UIAppFonts`,
            // so on a host that already has them this is a success. A
            // failure without an error is not — and `CFErrorGetCode` takes
            // its argument implicitly unwrapped, so it has to be checked.
            guard let failure = error?.takeRetainedValue() else { return false }
            return CFErrorGetCode(failure) == CTFontManagerError.alreadyRegistered.rawValue
        }
    }()

    /// The width one line of `text` typesets to, in points.
    static func width(of text: String, postScriptName: String, size: CGFloat) -> CGFloat {
        let font = CTFontCreateWithName(postScriptName as CFString, size, nil)
        let line = CTLineCreateWithAttributedString(
            NSAttributedString(string: text, attributes: [.font: font]),
        )
        return CGFloat(CTLineGetTypographicBounds(line, nil, nil, nil))
    }
}
