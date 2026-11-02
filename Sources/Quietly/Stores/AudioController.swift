import AppKit
import Combine
import CoreAudio
import Foundation

@MainActor
final class AudioController: ObservableObject {
    @Published private(set) var applications: [AudioApplication] = []
    @Published private(set) var mutedIDs: Set<String> = []
    @Published private(set) var pinnedIDs: Set<String>
    @Published private(set) var isRefreshing = false
    @Published var notice: Notice?

    @Published var refreshInterval: Double {
        didSet {
            UserDefaults.standard.set(refreshInterval, forKey: Self.refreshIntervalKey)
            configureRefreshTimer()
        }
    }

    private let service = CoreAudioProcessService()
    private var taps: [String: ManagedTap] = [:]
    private var refreshTimer: AnyCancellable?
    private var noticeTimer: AnyCancellable?
    private var terminationObserver: AnyCancellable?

    private static let pinnedKey = "quietly.pinned-app-ids"
    private static let refreshIntervalKey = "quietly.refresh-interval"

    struct ManagedTap {
        let session: CoreAudioMuteSession
        let processObjectIDs: [AudioObjectID]
    }

    struct Notice: Identifiable, Equatable {
        enum Style {
            case success
            case warning
            case error
        }

        let id = UUID()
        let text: String
        let style: Style
    }

    var isSupported: Bool {
        if #available(macOS 14.2, *) {
            return true
        }
        return false
    }

    var canMuteAnything: Bool {
        isSupported && applications.contains { !mutedIDs.contains($0.id) }
    }

    init() {
        let savedPins = UserDefaults.standard.stringArray(forKey: Self.pinnedKey) ?? []
        pinnedIDs = Set(savedPins)

        let savedInterval = UserDefaults.standard.double(forKey: Self.refreshIntervalKey)
        refreshInterval = savedInterval >= 1 ? savedInterval : 2

        configureRefreshTimer()
        terminationObserver = NotificationCenter.default
            .publisher(for: NSApplication.willTerminateNotification)
            .sink { [weak self] _ in
                Task { @MainActor in
                    self?.restoreAll(showNotice: false)
                }
            }
        refresh()
    }

    func refresh() {
        guard isSupported, !isRefreshing else { return }
        isRefreshing = true

        do {
            let discovered = try service.discoverApplications()
            applications = discovered
            reconcileTaps(with: discovered)
        } catch {
            show(error.localizedDescription, style: .error)
        }

        isRefreshing = false
    }

    func toggleMute(_ application: AudioApplication) {
        if mutedIDs.contains(application.id) {
            unmute(application, showNotice: true)
        } else {
            _ = mute(application, showNotice: true)
        }
    }

    func muteAll() {
        let candidates = applications.filter { !mutedIDs.contains($0.id) }
        guard !candidates.isEmpty else { return }

        var mutedCount = 0
        for application in candidates {
            if mute(application, showNotice: false) {
                mutedCount += 1
            }
        }

        if mutedCount > 0 {
            show(
                mutedCount == 1 ? "Muted 1 app" : "Muted \(mutedCount) apps",
                style: .success
            )
        }
    }

    func restoreAll(showNotice: Bool = true) {
        let activeTaps = taps
        for (id, tap) in activeTaps {
            do {
                if #available(macOS 14.2, *) {
                    try service.destroyMuteSession(tap.session)
                }
                taps.removeValue(forKey: id)
                mutedIDs.remove(id)
            } catch {
                if showNotice {
                    self.show(error.localizedDescription, style: .error)
                }
            }
        }

        if showNotice, activeTaps.count > 0, taps.isEmpty {
            show("Restored audio for all apps", style: .success)
        }
    }

    func togglePin(_ application: AudioApplication) {
        if pinnedIDs.contains(application.id) {
            pinnedIDs.remove(application.id)
        } else {
            pinnedIDs.insert(application.id)
        }
        UserDefaults.standard.set(Array(pinnedIDs).sorted(), forKey: Self.pinnedKey)
    }

    private func mute(_ application: AudioApplication, showNotice: Bool) -> Bool {
        guard isSupported else {
            if showNotice {
                show("Per-app muting requires macOS 14.2 or later.", style: .warning)
            }
            return false
        }

        // The first process tap can trigger macOS's System Audio Recording
        // authorization flow. Some macOS releases temporarily order the
        // initiating SwiftUI window out while that flow is resolved. Retain
        // and restore the window that initiated this action.
        let initiatingWindow = NSApp.keyWindow ?? NSApp.mainWindow
        defer {
            if let initiatingWindow, !initiatingWindow.isVisible {
                initiatingWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            (NSApp.delegate as? AppDelegate)?
                .recoverMainWindowAfterAudioAuthorization()
        }

        do {
            if #available(macOS 14.2, *) {
                let session = try service.createMuteSession(for: application)
                taps[application.id] = ManagedTap(
                    session: session,
                    processObjectIDs: application.processObjectIDs
                )
                mutedIDs.insert(application.id)
                if showNotice {
                    show("Muted \(application.name)", style: .success)
                }
                return true
            }
        } catch {
            if showNotice {
                self.show(error.localizedDescription, style: .error)
            }
        }
        return false
    }

    private func unmute(_ application: AudioApplication, showNotice: Bool) {
        guard let tap = taps[application.id] else {
            mutedIDs.remove(application.id)
            return
        }

        do {
            if #available(macOS 14.2, *) {
                try service.destroyMuteSession(tap.session)
            }
            taps.removeValue(forKey: application.id)
            mutedIDs.remove(application.id)
            if showNotice {
                show("Restored \(application.name)", style: .success)
            }
        } catch {
            if showNotice {
                self.show(error.localizedDescription, style: .error)
            }
        }
    }

    private func reconcileTaps(with discovered: [AudioApplication]) {
        let applicationsByID = Dictionary(uniqueKeysWithValues: discovered.map { ($0.id, $0) })

        for id in Array(taps.keys) {
            guard let application = applicationsByID[id] else {
                if let tap = taps[id], #available(macOS 14.2, *) {
                    try? service.destroyMuteSession(tap.session)
                }
                taps.removeValue(forKey: id)
                mutedIDs.remove(id)
                continue
            }

            guard
                let tap = taps[id],
                tap.processObjectIDs != application.processObjectIDs
            else {
                continue
            }

            if #available(macOS 14.2, *) {
                try? service.destroyMuteSession(tap.session)
            }
            taps.removeValue(forKey: id)
            mutedIDs.remove(id)
            _ = mute(application, showNotice: false)
        }
    }

    private func configureRefreshTimer() {
        refreshTimer?.cancel()
        refreshTimer = Timer.publish(
            every: max(refreshInterval, 1),
            on: .main,
            in: .common
        )
        .autoconnect()
        .sink { [weak self] _ in
            self?.refresh()
        }
    }

    private func show(_ text: String, style: Notice.Style) {
        let newNotice = Notice(text: text, style: style)
        notice = newNotice
        noticeTimer?.cancel()
        noticeTimer = Just(())
            .delay(for: .seconds(3.2), scheduler: RunLoop.main)
            .sink { [weak self] in
                if self?.notice?.id == newNotice.id {
                    self?.notice = nil
                }
            }
    }
}
