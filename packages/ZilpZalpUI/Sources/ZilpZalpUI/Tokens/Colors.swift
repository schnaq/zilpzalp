import SwiftUI

// Palette ramps from `design/tokens/colors.css`.
//
// Every hue is derived from the ZilpZalp reference photograph of a Wiedehopf
// (`design/assets/reference/wiedehopf-reference.png`): crest orange, meadow
// olive, feather clay, bark, and the sooty black of the crest tips. The system
// is WARM ONLY — there is no blue, no teal, no neutral grey, no red.
//
// Names map 1:1 onto the CSS custom properties: `olive500` is `--olive-500`,
// `sand200` is `--sand-200`. The ramps below are complete and in CSS order, so
// this file diffs against `colors.css` line by line. The semantic aliases,
// surfaces, text colours and rubric colours live in `ColorsSemantic.swift`.

/// The ZilpZalp colour tokens.
public enum ZColor {
    // MARK: - Olive / meadow (primary): the grass behind the bird

    public static let olive50 = Color(hex: 0xF1F4DE)
    public static let olive100 = Color(hex: 0xE5EBBE)
    public static let olive200 = Color(hex: 0xDCE3AE)
    public static let olive300 = Color(hex: 0xC3CE86)
    public static let olive400 = Color(hex: 0xA1AB53)
    public static let olive500 = Color(hex: 0x6E7A21)
    public static let olive600 = Color(hex: 0x5B6519)
    public static let olive700 = Color(hex: 0x4C5413)
    public static let olive800 = Color(hex: 0x3B4218)

    // MARK: - Hoopoe crest (accent): sampled #ED9156, deepened for contrast

    public static let orange50 = Color(hex: 0xFDEBDC)
    public static let orange100 = Color(hex: 0xF9D6BB)
    public static let orange200 = Color(hex: 0xF0B27A)
    public static let orange300 = Color(hex: 0xEF9A45)
    public static let orange400 = Color(hex: 0xE8802F)
    public static let orange500 = Color(hex: 0xDD6E22)
    public static let orange600 = Color(hex: 0xC25C16)
    /// Darkened from the `#A64B12` of `colors.css` — the one ramp entry that
    /// deviates from the export, and the deviation is measured.
    ///
    /// It is the only orange the system writes words in: `HomeTile`'s hoopoe
    /// tile — "Erkenne den Vogel", game 1 — and `Badge.Tone.hoopoe` both set
    /// it on `orange100`. At the export's value that pair is 4.22:1, and a
    /// tile label drops to `body` 20 pt on a phone, where SC 1.4.3 asks for
    /// 4.5:1. `#9C4410` is 4.73:1 and the smallest step down that clears the
    /// threshold with room to spare. Everywhere else the token is an edge, a
    /// ledge or a rim (`--color-accent-shadow`, `ChoiceTile.Tone.rufe`,
    /// `RewardSticker.Tone.hoopoe`), where darker only reads better —
    /// the sticker's glyph goes from 3.12:1 to 3.50:1 with it, over the 3:1
    /// SC 1.4.11 asks of a graphic. See `ContrastTests` and issue #238.
    public static let orange700 = Color(hex: 0x9C4410)

    // MARK: - Sun (reward, "try again")

    public static let sun100 = Color(hex: 0xFBEBC4)
    public static let sun200 = Color(hex: 0xFBE6B0)
    public static let sun300 = Color(hex: 0xF5CF63)
    public static let sun400 = Color(hex: 0xE9B21C)
    public static let sun500 = Color(hex: 0xCE9A0E)
    public static let sun600 = Color(hex: 0xB08000)

    // MARK: - Clay (feathers) — replaces the old cool "sky" ramp

    public static let clay50 = Color(hex: 0xFBE9E1)
    public static let clay100 = Color(hex: 0xF6D6C8)
    public static let clay200 = Color(hex: 0xE9AE94)
    public static let clay300 = Color(hex: 0xDC8A67)
    public static let clay400 = Color(hex: 0xD26E42)
    public static let clay500 = Color(hex: 0xC9552B)
    public static let clay600 = Color(hex: 0xAC4520)
    public static let clay700 = Color(hex: 0x97350F)

    // MARK: - Bark & earth

    public static let bark100 = Color(hex: 0xEFDCC4)
    public static let bark300 = Color(hex: 0xC79A6A)
    public static let bark500 = Color(hex: 0x9A6234)
    public static let bark700 = Color(hex: 0x6E3F1C)

    // MARK: - Berry (rare finds)

    public static let berry100 = Color(hex: 0xF4E2EF)
    public static let berry300 = Color(hex: 0xD9A6CC)
    public static let berry500 = Color(hex: 0x9E5A8E)
    public static let berry700 = Color(hex: 0x74406A)

    // MARK: - Marsh (wetland topics)

    public static let marsh100 = Color(hex: 0xE3EDD2)
    public static let marsh300 = Color(hex: 0xB7CB95)
    public static let marsh500 = Color(hex: 0x7E9B4E)
    public static let marsh700 = Color(hex: 0x5A7332)

    // MARK: - Warm neutrals: oat paper, sand lines, soot ink

    public static let cream50 = Color(hex: 0xFFFCF3)
    public static let cream100 = Color(hex: 0xFBF3E4)
    public static let sand200 = Color(hex: 0xF2E6CE)
    public static let sand300 = Color(hex: 0xEADCC0)
    public static let sand400 = Color(hex: 0xD9C7A4)

    public static let ink900 = Color(hex: 0x2A2213)
    public static let ink700 = Color(hex: 0x544730)
    public static let ink500 = Color(hex: 0x7D6E51)
    public static let ink300 = Color(hex: 0x9C8C6D)

    /// `--white` — the warm white of the system. Deliberately the same value
    /// as ``cream50`` (`#FFFCF3`); there is no pure `#FFFFFF` in ZilpZalp.
    public static let white = Color(hex: 0xFFFCF3)
    /// `--soot` — the sooty black of the crest tips, darker than ``ink900``.
    public static let soot = Color(hex: 0x17140F)
}

extension Color {
    /// Builds a colour from a 24-bit RGB literal, so the Swift tokens can be
    /// read against the hex values in `design/tokens/colors.css` without
    /// arithmetic.
    ///
    /// - Parameters:
    ///   - hex: Red, green and blue as `0xRRGGBB`.
    ///   - opacity: Alpha channel, `1` for the opaque palette entries.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity,
        )
    }
}
