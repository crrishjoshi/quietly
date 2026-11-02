import AppKit
import SwiftUI

struct MenuBarContent: View {
    @ObservedObject var controller: AudioController
    @Environment(\.openWindow) private var openWindow

    private var quickApplications: [AudioApplication] {
        controller.applications
            .sorted { lhs, rhs in
                let lhsPinned = controller.pinnedIDs.contains(lhs.id)
                let rhsPinned = controller.pinnedIDs.contains(rhs.id)
                if lhsPinned != rhsPinned {
                    return lhsPinned && !rhsPinned
                }
                if lhs.isProducingAudio != rhs.isProducingAudio {
                    return lhs.isProducingAudio && !rhs.isProducingAudio
                }
                return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
            .prefix(8)
            .map { $0 }
    }

    var body: some View {
        Button("Open Quietly") {
            openMainWindow()
        }

        Divider()

        if !controller.isSupported {
            Text("Requires macOS 14.2+")
        } else if quickApplications.isEmpty {
            Text("Play audio to detect apps")
            Button("Refresh") {
                controller.refresh()
            }
        } else {
            ForEach(quickApplications) { application in
                Button {
                    controller.toggleMute(application)
                } label: {
                    Label(
                        menuTitle(for: application.name),
                        systemImage: controller.mutedIDs.contains(application.id)
                            ? "speaker.slash.fill"
                            : "speaker.wave.2.fill"
                    )
                }
            }

            if controller.applications.count > quickApplications.count {
                Button("Show all \(controller.applications.count) apps…") {
                    openMainWindow()
                }
            }

            Divider()

            Button("Mute All") {
                controller.muteAll()
            }
            .disabled(!controller.canMuteAnything)

            Button("Restore All") {
                controller.restoreAll()
            }
            .disabled(controller.mutedIDs.isEmpty)
        }

        Divider()

        Button("Quit Quietly") {
            controller.restoreAll(showNotice: false)
            NSApplication.shared.terminate(nil)
        }
    }

    private func openMainWindow() {
        openWindow(id: "main")
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func menuTitle(for title: String) -> String {
        guard title.count > 30 else { return title }
        return String(title.prefix(27)) + "…"
    }
}
