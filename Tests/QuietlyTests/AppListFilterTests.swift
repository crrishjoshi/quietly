import Testing
@testable import Quietly

private let music = AudioApplication(
    id: "com.apple.Music",
    name: "Music",
    bundleIdentifier: "com.apple.Music",
    processObjectIDs: [10],
    processIdentifiers: [100],
    icon: nil,
    isProducingAudio: true
)

@Test
func searchMatchesNameAndBundleIdentifier() {
    #expect(
        AppListFilter.all.includes(
            music,
            mutedIDs: [],
            pinnedIDs: [],
            searchText: "mus"
        )
    )
    #expect(
        AppListFilter.all.includes(
            music,
            mutedIDs: [],
            pinnedIDs: [],
            searchText: "apple.music"
        )
    )
    #expect(
        !AppListFilter.all.includes(
            music,
            mutedIDs: [],
            pinnedIDs: [],
            searchText: "safari"
        )
    )
}

@Test
func statusFiltersUseControllerState() {
    #expect(
        AppListFilter.active.includes(
            music,
            mutedIDs: [],
            pinnedIDs: [],
            searchText: ""
        )
    )
    #expect(
        AppListFilter.muted.includes(
            music,
            mutedIDs: [music.id],
            pinnedIDs: [],
            searchText: ""
        )
    )
    #expect(
        AppListFilter.pinned.includes(
            music,
            mutedIDs: [],
            pinnedIDs: [music.id],
            searchText: ""
        )
    )
}

@Test
func fourCharacterCodeFormatsPrintableStatus() {
    #expect(fourCharacterCode(UInt32(0x6E6F7065)) == "'nope'")
    #expect(fourCharacterCode(0) == "0")
}

@Test
func webKitHelperNameMapsToLongestForegroundHost() {
    #expect(
        matchingHostApplicationName(
            for: "Safari Graphics and Media",
            candidates: ["Safari", "Safari Technology Preview", "Music"]
        ) == "Safari"
    )
    #expect(
        matchingHostApplicationName(
            for: "ChatGPT Classic Graphics and Media",
            candidates: ["ChatGPT", "ChatGPT Classic"]
        ) == "ChatGPT Classic"
    )
    #expect(
        matchingHostApplicationName(
            for: "WebKit Graphics and Media",
            candidates: ["Safari", "Music"]
        ) == nil
    )
}
