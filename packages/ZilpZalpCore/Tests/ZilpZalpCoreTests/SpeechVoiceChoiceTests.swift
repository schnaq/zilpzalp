import Testing
import ZilpZalpCore

/// One voice, spelled out only where a case cares. The identifier is derived
/// from the name so that every voice in a set is distinct without every test
/// having to say so.
private func voice(
    _ name: String,
    _ language: String = "de-DE",
    _ quality: SpeechVoiceQuality = .standard,
    isNovelty: Bool = false,
    isPersonal: Bool = false,
) -> SpeechVoiceDescription {
    SpeechVoiceDescription(
        identifier: "com.apple.voice.\(quality).\(language).\(name)",
        name: name,
        language: language,
        quality: quality,
        isNovelty: isNovelty,
        isPersonal: isPersonal,
    )
}

@Test("A device without a single voice has nothing to choose")
func noVoicesAtAll() {
    #expect(SpeechVoiceChoice.best(from: []) == nil)
}

@Test("A device with no German voice has nothing to choose either")
func noGermanVoice() {
    let voices = [
        voice("Samantha", "en-US", .premium),
        voice("Amélie", "fr-CA", .enhanced),
    ]
    #expect(SpeechVoiceChoice.best(from: voices) == nil)
}

@Test("Premium beats enhanced beats standard")
func qualityDecides() {
    let anna = voice("Anna", "de-DE", .standard)
    let helena = voice("Helena", "de-DE", .enhanced)
    let markus = voice("Markus", "de-DE", .premium)

    #expect(SpeechVoiceChoice.best(from: [anna, helena, markus]) == markus)
    #expect(SpeechVoiceChoice.best(from: [anna, helena]) == helena)
    #expect(SpeechVoiceChoice.best(from: [anna]) == anna)
}

@Test("de-DE wins over another German region even when that one is better")
func regionBeatsQuality() {
    let anna = voice("Anna", "de-DE", .standard)
    let helena = voice("Helena", "de-AT", .premium)

    #expect(SpeechVoiceChoice.best(from: [anna, helena]) == anna)
}

@Test("Another German region is used when de-DE is missing")
func otherGermanRegionAsFallback() {
    let helena = voice("Helena", "de-AT", .standard)
    let petra = voice("Petra", "de-CH", .enhanced)

    #expect(SpeechVoiceChoice.best(from: [helena, petra]) == petra)
}

@Test("A bare 'de' counts as German", arguments: ["de", "DE", "de_DE", "De-de"])
func languageTagsThatStillMeanGerman(tag: String) {
    let anna = voice("Anna", tag, .standard)
    #expect(SpeechVoiceChoice.best(from: [anna]) == anna)
}

@Test("A novelty voice is never chosen, however good it is")
func noveltyExcluded() {
    let bahh = voice("Bahh", "de-DE", .premium, isNovelty: true)
    let anna = voice("Anna", "de-DE", .standard)

    #expect(SpeechVoiceChoice.best(from: [bahh, anna]) == anna)
    #expect(SpeechVoiceChoice.best(from: [bahh]) == nil)
}

@Test("A personal voice is never chosen — that needs authorisation first")
func personalVoiceExcluded() {
    let mum = voice("Mama", "de-DE", .premium, isPersonal: true)
    let anna = voice("Anna", "de-DE", .standard)

    #expect(SpeechVoiceChoice.best(from: [mum, anna]) == anna)
    #expect(SpeechVoiceChoice.best(from: [mum]) == nil)
}

@Test("The order the system lists the voices in does not change the choice")
func choiceIsStableAcrossOrderings() {
    let voices = [
        voice("Anna", "de-DE", .standard),
        voice("Helena", "de-DE", .premium),
        voice("Markus", "de-DE", .premium),
        voice("Petra", "de-AT", .premium),
        voice("Bahh", "de-DE", .premium, isNovelty: true),
        voice("Samantha", "en-US", .premium),
    ]
    let expected = SpeechVoiceChoice.best(from: voices)

    // Name is the tiebreak, so the two premium de-DE voices resolve to the
    // alphabetically first one rather than to whichever came first.
    #expect(expected?.name == "Helena")

    var generator = SplitMix64(seed: 0x5EED)
    for _ in 0 ..< 50 {
        #expect(SpeechVoiceChoice.best(from: voices.shuffled(using: &generator)) == expected)
    }
}

@Test("Two voices that differ only in name are settled by the name")
func nameIsTheLastTiebreak() {
    let ada = voice("Ada", "de-DE", .enhanced)
    let zoe = voice("Zoe", "de-DE", .enhanced)

    #expect(SpeechVoiceChoice.best(from: [zoe, ada]) == ada)
    #expect(SpeechVoiceChoice.best(from: [ada, zoe]) == ada)
}
