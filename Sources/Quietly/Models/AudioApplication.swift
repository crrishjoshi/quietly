import AppKit
import CoreAudio
import Foundation

struct AudioApplication: Identifiable {
    let id: String
    let name: String
    let bundleIdentifier: String?
    let processObjectIDs: [AudioObjectID]
    let processIdentifiers: [pid_t]
    let icon: NSImage?
    let isProducingAudio: Bool

    var processCountLabel: String {
        let count = processObjectIDs.count
        return count == 1 ? "1 audio process" : "\(count) audio processes"
    }
}

enum AppListFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case active = "Playing"
    case muted = "Muted"
    case pinned = "Pinned"

    var id: String { rawValue }

    func includes(
        _ app: AudioApplication,
        mutedIDs: Set<String>,
        pinnedIDs: Set<String>,
        searchText: String
    ) -> Bool {
        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let matchesSearch = normalizedSearch.isEmpty
            || app.name.localizedCaseInsensitiveContains(normalizedSearch)
            || (app.bundleIdentifier?.localizedCaseInsensitiveContains(normalizedSearch) ?? false)

        guard matchesSearch else { return false }

        switch self {
        case .all:
            return true
        case .active:
            return app.isProducingAudio
        case .muted:
            return mutedIDs.contains(app.id)
        case .pinned:
            return pinnedIDs.contains(app.id)
        }
    }
}

struct ResolvedAudioProcess {
    let stableID: String
    let name: String
    let bundleIdentifier: String?
    let processObjectID: AudioObjectID
    let processIdentifier: pid_t
    let icon: NSImage?
    let isProducingAudio: Bool
}

func matchingHostApplicationName(
    for helperName: String,
    candidates: [String]
) -> String? {
    candidates
        .filter { candidate in
            helperName == candidate
                || helperName.localizedCaseInsensitiveContains(candidate + " ")
                    && helperName.range(
                        of: candidate + " ",
                        options: [.caseInsensitive, .anchored]
                    ) != nil
        }
        .max { $0.count < $1.count }
}
