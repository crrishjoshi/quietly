import AppKit
import SwiftUI

struct ContentView: View {
    @ObservedObject var controller: AudioController
    @State private var searchText = ""
    @State private var selectedFilter: AppListFilter = .all

    private var filteredApplications: [AudioApplication] {
        controller.applications
            .filter {
                selectedFilter.includes(
                    $0,
                    mutedIDs: controller.mutedIDs,
                    pinnedIDs: controller.pinnedIDs,
                    searchText: searchText
                )
            }
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
    }

    var body: some View {
        ZStack {
            QuietlyBackground()

            VStack(spacing: 0) {
                HeaderView(controller: controller)
                    .padding(.horizontal, 26)
                    .padding(.top, 22)
                    .padding(.bottom, 18)

                ScrollView {
                    LazyVStack(spacing: 18) {
                        HeroCard(controller: controller)

                        if !controller.isSupported {
                            CompatibilityCard()
                        } else {
                            SearchAndFilterBar(
                                searchText: $searchText,
                                selectedFilter: $selectedFilter
                            )

                            ApplicationList(
                                applications: filteredApplications,
                                totalApplicationCount: controller.applications.count,
                                searchText: searchText,
                                selectedFilter: selectedFilter,
                                controller: controller
                            )

                            PrivacyFooter()
                        }
                    }
                    .padding(.horizontal, 26)
                    .padding(.bottom, 34)
                }
                .scrollIndicators(.hidden)
            }
        }
        .overlay(alignment: .bottom) {
            if let notice = controller.notice {
                NoticeBanner(notice: notice)
                    .padding(.bottom, 18)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.22), value: controller.notice)
        .tint(.quietlyIndigo)
        .background(MainWindowAccessor())
        .onAppear {
            controller.refresh()
        }
    }
}

private struct MainWindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        registerWindow(for: view)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        registerWindow(for: nsView)
    }

    private func registerWindow(for view: NSView) {
        DispatchQueue.main.async {
            guard
                let window = view.window,
                let delegate = NSApp.delegate as? AppDelegate
            else {
                return
            }
            delegate.registerMainWindow(window)
        }
    }
}

private struct QuietlyBackground: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)

            LinearGradient(
                colors: [
                    Color.quietlyIndigo.opacity(colorScheme == .dark ? 0.20 : 0.13),
                    Color.quietlyMint.opacity(colorScheme == .dark ? 0.08 : 0.06),
                    .clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .ignoresSafeArea()
    }
}

private struct HeaderView: View {
    @ObservedObject var controller: AudioController

    var body: some View {
        HStack(spacing: 13) {
            QuietlyLogo(size: 42)

            VStack(alignment: .leading, spacing: 2) {
                Text("Quietly")
                    .font(.system(size: 21, weight: .bold, design: .rounded))
                Text("Your Mac, app by app.")
                    .font(.system(size: 12.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            EngineStatusPill(isSupported: controller.isSupported)

            Button {
                controller.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 13, weight: .semibold))
                    .rotationEffect(.degrees(controller.isRefreshing ? 360 : 0))
                    .animation(
                        controller.isRefreshing
                            ? .linear(duration: 0.8).repeatForever(autoreverses: false)
                            : .default,
                        value: controller.isRefreshing
                    )
            }
            .buttonStyle(QuietIconButtonStyle())
            .help("Refresh audio apps")

            SettingsButton()
        }
    }
}

private struct SettingsButton: View {
    var body: some View {
        Group {
            if #available(macOS 14.0, *) {
                SettingsLink {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
            } else {
                Button {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 13, weight: .semibold))
                }
            }
        }
        .buttonStyle(QuietIconButtonStyle())
        .help("Settings")
    }
}

private struct EngineStatusPill: View {
    let isSupported: Bool

    var body: some View {
        HStack(spacing: 7) {
            Circle()
                .fill(isSupported ? Color.quietlyMint : Color.orange)
                .frame(width: 7, height: 7)
                .shadow(color: (isSupported ? Color.quietlyMint : Color.orange).opacity(0.65), radius: 4)
            Text(isSupported ? "Audio engine ready" : "Compatibility mode")
                .font(.system(size: 11.5, weight: .semibold))
        }
        .padding(.horizontal, 11)
        .padding(.vertical, 7)
        .background(.thinMaterial, in: Capsule())
        .overlay {
            Capsule()
                .strokeBorder(Color.primary.opacity(0.08))
        }
    }
}

private struct HeroCard: View {
    @ObservedObject var controller: AudioController

    var body: some View {
        HStack(spacing: 24) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Control sound,\none app at a time.")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .tracking(-0.5)
                    .fixedSize(horizontal: false, vertical: true)

                Text("Instantly quiet the apps you choose without touching your Mac's master volume.")
                    .font(.system(size: 14.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineSpacing(3)
                    .frame(maxWidth: 450, alignment: .leading)

                HStack(spacing: 10) {
                    Button {
                        controller.muteAll()
                    } label: {
                        Label("Mute all", systemImage: "speaker.slash.fill")
                    }
                    .buttonStyle(QuietPrimaryButtonStyle())
                    .disabled(!controller.canMuteAnything)

                    Button {
                        controller.restoreAll()
                    } label: {
                        Label("Restore all", systemImage: "speaker.wave.2.fill")
                    }
                    .buttonStyle(QuietSecondaryButtonStyle())
                    .disabled(controller.mutedIDs.isEmpty)
                }
                .padding(.top, 2)
            }

            Spacer(minLength: 10)

            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.11))
                    .frame(width: 134, height: 134)
                Circle()
                    .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                    .frame(width: 106, height: 106)
                Image(systemName: controller.mutedIDs.isEmpty ? "waveform.circle.fill" : "speaker.slash.circle.fill")
                    .font(.system(size: 72, weight: .light))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.white)
            }
            .accessibilityHidden(true)
        }
        .padding(28)
        .foregroundStyle(.white)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.29, green: 0.25, blue: 0.78),
                            Color(red: 0.25, green: 0.48, blue: 0.86),
                            Color(red: 0.18, green: 0.62, blue: 0.68)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(Color.white.opacity(0.17))
        }
        .shadow(color: Color.quietlyIndigo.opacity(0.20), radius: 22, y: 10)
    }
}

private struct SearchAndFilterBar: View {
    @Binding var searchText: String
    @Binding var selectedFilter: AppListFilter

    var body: some View {
        HStack(spacing: 14) {
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search audio apps", text: $searchText)
                    .textFieldStyle(.plain)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 13)
            .frame(height: 36)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.08))
            }

            Picker("Filter", selection: $selectedFilter) {
                ForEach(AppListFilter.allCases) { filter in
                    Text(filter.rawValue).tag(filter)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 310)
        }
    }
}

private struct ApplicationList: View {
    let applications: [AudioApplication]
    let totalApplicationCount: Int
    let searchText: String
    let selectedFilter: AppListFilter
    @ObservedObject var controller: AudioController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("AUDIO APPS")
                    .font(.system(size: 11, weight: .bold))
                    .tracking(1.1)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(totalApplicationCount) detected")
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 3)

            if applications.isEmpty {
                EmptyAppsView(
                    hasDetectedApps: totalApplicationCount > 0,
                    hasSearch: !searchText.isEmpty,
                    filter: selectedFilter
                )
            } else {
                LazyVStack(spacing: 9) {
                    ForEach(applications) { application in
                        AppAudioRow(
                            application: application,
                            isMuted: controller.mutedIDs.contains(application.id),
                            isPinned: controller.pinnedIDs.contains(application.id),
                            onToggleMute: { controller.toggleMute(application) },
                            onTogglePin: { controller.togglePin(application) }
                        )
                    }
                }
            }
        }
    }
}

private struct AppAudioRow: View {
    let application: AudioApplication
    let isMuted: Bool
    let isPinned: Bool
    let onToggleMute: () -> Void
    let onTogglePin: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            AppIconView(application: application)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 7) {
                    Text(application.name)
                        .font(.system(size: 14.5, weight: .semibold))
                        .lineLimit(1)

                    if application.isProducingAudio {
                        HStack(spacing: 2) {
                            ForEach(0..<3, id: \.self) { index in
                                Capsule()
                                    .fill(isMuted ? Color.secondary : Color.quietlyMint)
                                    .frame(width: 2.5, height: CGFloat(5 + index * 3))
                            }
                        }
                        .frame(height: 12, alignment: .bottom)
                        .accessibilityLabel("Playing audio")
                    }
                }

                Text(statusText)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundStyle(isMuted ? Color.orange : Color.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 12)

            Button(action: onTogglePin) {
                Image(systemName: isPinned ? "star.fill" : "star")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(isPinned ? Color.yellow : Color.secondary)
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .help(isPinned ? "Unpin \(application.name)" : "Pin \(application.name)")

            Button(action: onToggleMute) {
                HStack(spacing: 7) {
                    Image(systemName: isMuted ? "speaker.wave.2.fill" : "speaker.slash.fill")
                    Text(isMuted ? "Unmute" : "Mute")
                }
                .font(.system(size: 12.5, weight: .semibold))
                .frame(width: 78)
                .padding(.vertical, 8)
                .foregroundStyle(isMuted ? Color.primary : Color.white)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isMuted ? Color.primary.opacity(0.08) : Color.quietlyIndigo)
                }
            }
            .buttonStyle(.plain)
            .help(isMuted ? "Restore \(application.name)" : "Mute only \(application.name)")
            .accessibilityLabel(isMuted ? "Unmute \(application.name)" : "Mute \(application.name)")
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    isMuted ? Color.orange.opacity(0.28) : Color.primary.opacity(0.075),
                    lineWidth: 1
                )
        }
        .shadow(color: Color.black.opacity(0.035), radius: 8, y: 3)
    }

    private var statusText: String {
        if isMuted {
            return "Muted by Quietly"
        }
        if application.isProducingAudio {
            return "Playing now · \(application.processCountLabel)"
        }
        return "Connected to audio · \(application.processCountLabel)"
    }
}

private struct AppIconView: View {
    let application: AudioApplication

    var body: some View {
        Group {
            if let icon = application.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .padding(4)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 21, weight: .medium))
                    .foregroundStyle(Color.quietlyIndigo)
            }
        }
        .frame(width: 42, height: 42)
        .background(Color.primary.opacity(0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}

private struct EmptyAppsView: View {
    let hasDetectedApps: Bool
    let hasSearch: Bool
    let filter: AppListFilter

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: hasDetectedApps ? "line.3.horizontal.decrease.circle" : "waveform.slash")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(Color.quietlyIndigo)

            Text(title)
                .font(.system(size: 15, weight: .semibold))

            Text(message)
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 38)
        .quietCard(cornerRadius: 18)
    }

    private var title: String {
        if hasSearch { return "No matching audio apps" }
        if hasDetectedApps { return "Nothing in \(filter.rawValue.lowercased())" }
        return "No audio apps detected yet"
    }

    private var message: String {
        if hasSearch { return "Try another app name or clear the search." }
        if hasDetectedApps { return "Choose All to see every app connected to macOS audio." }
        return "Start playing sound in an app. Quietly will detect it automatically."
    }
}

private struct CompatibilityCard: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.12))
                    .frame(width: 58, height: 58)
                Image(systemName: "macbook.and.iphone")
                    .font(.system(size: 25, weight: .medium))
                    .foregroundStyle(Color.orange)
            }

            Text("This Mac is in compatibility mode")
                .font(.system(size: 18, weight: .bold, design: .rounded))

            Text("Quietly opens on macOS 13 and later, but Apple's secure per-app audio mute API requires macOS 14.2 or newer. Update macOS to enable individual app controls.")
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .frame(maxWidth: 520)

            Button("Open Software Update") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.Software-Update-Settings.extension") {
                    NSWorkspace.shared.open(url)
                }
            }
            .buttonStyle(QuietSecondaryButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .quietCard(cornerRadius: 20)
    }
}

private struct PrivacyFooter: View {
    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(Color.quietlyMint)
            Text("Private by design")
                .fontWeight(.semibold)
            Text("Quietly never records, saves, or uploads audio.")
                .foregroundStyle(.secondary)
            Spacer()
            Text("Core Audio · Local only")
                .foregroundStyle(.tertiary)
        }
        .font(.system(size: 11.5, weight: .medium))
        .padding(.horizontal, 4)
    }
}

private struct NoticeBanner: View {
    let notice: AudioController.Notice

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(notice.text)
                .font(.system(size: 12.5, weight: .semibold))
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .background(.ultraThickMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(Color.primary.opacity(0.10))
        }
        .shadow(color: Color.black.opacity(0.14), radius: 14, y: 5)
    }

    private var icon: String {
        switch notice.style {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    private var color: Color {
        switch notice.style {
        case .success: return .quietlyMint
        case .warning: return .orange
        case .error: return .red
        }
    }
}
