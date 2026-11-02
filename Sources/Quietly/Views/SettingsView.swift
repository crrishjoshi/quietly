import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @ObservedObject var controller: AudioController
    @StateObject private var launchAtLogin = LaunchAtLoginController()

    var body: some View {
        TabView {
            Form {
                Section("Startup") {
                    Toggle(
                        "Launch Quietly at login",
                        isOn: Binding(
                            get: { launchAtLogin.isEnabled },
                            set: { launchAtLogin.setEnabled($0) }
                        )
                    )

                    if let message = launchAtLogin.message {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Detection") {
                    Picker("Refresh audio apps", selection: $controller.refreshInterval) {
                        Text("Every second").tag(1.0)
                        Text("Every 2 seconds").tag(2.0)
                        Text("Every 5 seconds").tag(5.0)
                    }
                    .pickerStyle(.menu)
                }

                Section("Privacy") {
                    Label(
                        "Audio taps stay private to Quietly and are removed when you quit.",
                        systemImage: "lock.shield"
                    )
                    .foregroundStyle(.secondary)
                }
            }
            .padding(22)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }

            VStack(spacing: 14) {
                QuietlyLogo(size: 74)
                Text("Quietly")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("Individual app audio control for macOS")
                    .foregroundStyle(.secondary)
                Text("Version 0.1.2")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                Divider()
                    .frame(width: 260)
                    .padding(.vertical, 4)

                Text("Runs on macOS 13+. Per-app muting is available on macOS 14.2+ on both Apple Silicon and Intel Macs.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 360)
            }
            .padding(30)
            .tabItem {
                Label("About", systemImage: "info.circle")
            }
        }
        .frame(width: 500, height: 360)
    }
}

@MainActor
private final class LaunchAtLoginController: ObservableObject {
    @Published private(set) var isEnabled = false
    @Published private(set) var message: String?

    init() {
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    func setEnabled(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            isEnabled = SMAppService.mainApp.status == .enabled
            message = nil
        } catch {
            isEnabled = SMAppService.mainApp.status == .enabled
            message = "Install Quietly in Applications before enabling launch at login."
        }
    }
}
