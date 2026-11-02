import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var mainWindow: NSWindow?
    private var mainWindowObserver: NSObjectProtocol?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        mainWindowObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeMainNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard
                let window = notification.object as? NSWindow,
                window.title == "Quietly"
            else {
                return
            }
            self?.registerMainWindow(window)
        }

        DispatchQueue.main.async { [weak self] in
            if let window = NSApp.windows.first(where: { $0.title == "Quietly" }) {
                self?.registerMainWindow(window)
            }
        }
    }

    func registerMainWindow(_ window: NSWindow) {
        mainWindow = window
        window.isReleasedWhenClosed = false
    }

    func recoverMainWindowAfterAudioAuthorization() {
        for delay in [0.15, 0.6, 1.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                guard let window = self?.mainWindow, !window.isVisible else {
                    return
                }
                window.orderFrontRegardless()
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        guard !flag, let mainWindow else { return true }
        mainWindow.makeKeyAndOrderFront(nil)
        sender.activate(ignoringOtherApps: true)
        return true
    }

    deinit {
        if let mainWindowObserver {
            NotificationCenter.default.removeObserver(mainWindowObserver)
        }
    }
}

@main
struct QuietlyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var audioController = AudioController()

    var body: some Scene {
        WindowGroup("Quietly", id: "main") {
            ContentView(controller: audioController)
                .frame(minWidth: 680, minHeight: 580)
        }
        .defaultSize(width: 780, height: 680)
        .windowStyle(.hiddenTitleBar)
        .commands {
            QuietlyCommands(controller: audioController)
        }

        Settings {
            SettingsView(controller: audioController)
        }
    }
}

private struct QuietlyCommands: Commands {
    @ObservedObject var controller: AudioController

    var body: some Commands {
        CommandMenu("Audio") {
            Button("Mute All Active Apps") {
                controller.muteAll()
            }
            .keyboardShortcut("m", modifiers: [.command, .option])
            .disabled(!controller.canMuteAnything)

            Button("Restore All Audio") {
                controller.restoreAll()
            }
            .keyboardShortcut("r", modifiers: [.command, .option])
            .disabled(controller.mutedIDs.isEmpty)

            Divider()

            Button("Refresh Audio Apps") {
                controller.refresh()
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
        }
    }
}
