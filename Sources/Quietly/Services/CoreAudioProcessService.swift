import AppKit
import CoreAudio
import Darwin
import Foundation

enum QuietlyAudioError: LocalizedError {
    case unsupportedSystem
    case propertyRead(selector: AudioObjectPropertySelector, status: OSStatus)
    case noAudioProcess(String)
    case audioOperation(name: String, status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .unsupportedSystem:
            return "Per-app muting requires macOS 14.2 or later."
        case let .propertyRead(selector, status):
            return "Could not read audio process data (\(fourCharacterCode(selector)) / \(fourCharacterCode(status)))."
        case let .noAudioProcess(name):
            return "\(name) is not connected to macOS audio yet. Play audio in the app, then refresh."
        case let .audioOperation(name, status):
            if status == kAudioDevicePermissionsError {
                return "macOS blocked system audio access. Allow Quietly in Privacy & Security, then try again."
            }
            return "\(name) failed (\(fourCharacterCode(status)))."
        }
    }
}

struct CoreAudioMuteSession {
    let tapID: AudioObjectID
    let aggregateDeviceID: AudioObjectID
    let ioProcID: AudioDeviceIOProcID
}

func fourCharacterCode<T: BinaryInteger>(_ value: T) -> String {
    let unsigned = UInt32(truncatingIfNeeded: value)
    let bytes: [UInt8] = [
        UInt8((unsigned >> 24) & 0xff),
        UInt8((unsigned >> 16) & 0xff),
        UInt8((unsigned >> 8) & 0xff),
        UInt8(unsigned & 0xff)
    ]

    if bytes.allSatisfy({ $0 >= 32 && $0 <= 126 }) {
        return "'\(String(bytes: bytes, encoding: .ascii) ?? "????")'"
    }

    return String(value)
}

final class CoreAudioProcessService {
    func discoverApplications() throws -> [AudioApplication] {
        guard #available(macOS 14.2, *) else {
            throw QuietlyAudioError.unsupportedSystem
        }

        let objectIDs = try audioProcessObjectIDs()
        let resolved = objectIDs.compactMap(resolveProcess)
        let grouped = Dictionary(grouping: resolved, by: \.stableID)

        return grouped.values
            .compactMap(makeApplication)
            .sorted {
                if $0.isProducingAudio != $1.isProducingAudio {
                    return $0.isProducingAudio && !$1.isProducingAudio
                }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    @available(macOS 14.2, *)
    func createMuteSession(for application: AudioApplication) throws -> CoreAudioMuteSession {
        guard !application.processObjectIDs.isEmpty else {
            throw QuietlyAudioError.noAudioProcess(application.name)
        }

        let description = CATapDescription(
            stereoMixdownOfProcesses: application.processObjectIDs
        )
        description.name = "Quietly · \(application.name)"
        description.isPrivate = true
        description.muteBehavior = .muted

        var tapID = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateProcessTap(description, &tapID)
        guard status == noErr else {
            throw QuietlyAudioError.audioOperation(
                name: "Creating the mute tap",
                status: status
            )
        }

        var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        var ioProcID: AudioDeviceIOProcID?

        do {
            let tapUID = try tapUID(for: tapID)
            aggregateDeviceID = try createAggregateDevice(
                tapUID: tapUID,
                applicationName: application.name
            )
            ioProcID = try createAndStartIO(on: aggregateDeviceID)

            guard let ioProcID else {
                throw QuietlyAudioError.audioOperation(
                    name: "Starting the mute engine",
                    status: kAudioHardwareUnspecifiedError
                )
            }

            return CoreAudioMuteSession(
                tapID: tapID,
                aggregateDeviceID: aggregateDeviceID,
                ioProcID: ioProcID
            )
        } catch {
            if let ioProcID {
                AudioDeviceStop(aggregateDeviceID, ioProcID)
                AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
            }
            if aggregateDeviceID != kAudioObjectUnknown {
                AudioHardwareDestroyAggregateDevice(aggregateDeviceID)
            }
            AudioHardwareDestroyProcessTap(tapID)
            throw error
        }
    }

    @available(macOS 14.2, *)
    func destroyMuteSession(_ session: CoreAudioMuteSession) throws {
        var firstError: QuietlyAudioError?

        let stopStatus = AudioDeviceStop(
            session.aggregateDeviceID,
            session.ioProcID
        )
        if stopStatus != noErr, stopStatus != kAudioHardwareNotRunningError {
            firstError = .audioOperation(
                name: "Stopping the mute engine",
                status: stopStatus
            )
        }

        let destroyIOStatus = AudioDeviceDestroyIOProcID(
            session.aggregateDeviceID,
            session.ioProcID
        )
        if destroyIOStatus != noErr, firstError == nil {
            firstError = .audioOperation(
                name: "Removing the mute engine",
                status: destroyIOStatus
            )
        }

        let aggregateStatus = AudioHardwareDestroyAggregateDevice(
            session.aggregateDeviceID
        )
        if aggregateStatus != noErr,
           aggregateStatus != kAudioHardwareBadObjectError,
           firstError == nil {
            firstError = .audioOperation(
                name: "Removing the private audio device",
                status: aggregateStatus
            )
        }

        let tapStatus = AudioHardwareDestroyProcessTap(session.tapID)
        if tapStatus != noErr,
           tapStatus != kAudioHardwareBadObjectError,
           firstError == nil {
            firstError = .audioOperation(
                name: "Removing the mute tap",
                status: tapStatus
            )
        }

        if let firstError {
            throw firstError
        }
    }

    @available(macOS 14.2, *)
    private func tapUID(for tapID: AudioObjectID) throws -> String {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioTapPropertyUID,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize = UInt32(MemoryLayout<CFString>.stride)
        var uid: CFString = "" as CFString
        let status = withUnsafeMutablePointer(to: &uid) {
            AudioObjectGetPropertyData(
                tapID,
                &address,
                0,
                nil,
                &dataSize,
                $0
            )
        }

        guard status == noErr else {
            throw QuietlyAudioError.propertyRead(
                selector: address.mSelector,
                status: status
            )
        }
        return uid as String
    }

    @available(macOS 14.2, *)
    private func createAggregateDevice(
        tapUID: String,
        applicationName: String
    ) throws -> AudioObjectID {
        let subTap: [String: Any] = [
            kAudioSubTapUIDKey: tapUID,
            kAudioSubTapDriftCompensationKey: true
        ]
        let aggregateUID = "com.crrish.quietly.mute.\(UUID().uuidString)"
        let aggregateDescription: [String: Any] = [
            kAudioAggregateDeviceNameKey: "Quietly · \(applicationName)",
            kAudioAggregateDeviceUIDKey: aggregateUID,
            kAudioAggregateDeviceIsPrivateKey: true,
            kAudioAggregateDeviceTapAutoStartKey: true,
            kAudioAggregateDeviceTapListKey: [subTap]
        ]

        var aggregateDeviceID = AudioObjectID(kAudioObjectUnknown)
        let status = AudioHardwareCreateAggregateDevice(
            aggregateDescription as CFDictionary,
            &aggregateDeviceID
        )
        guard status == noErr else {
            throw QuietlyAudioError.audioOperation(
                name: "Creating the private audio device",
                status: status
            )
        }
        return aggregateDeviceID
    }

    @available(macOS 14.2, *)
    private func createAndStartIO(
        on aggregateDeviceID: AudioObjectID
    ) throws -> AudioDeviceIOProcID {
        var ioProcID: AudioDeviceIOProcID?
        let createStatus = AudioDeviceCreateIOProcIDWithBlock(
            &ioProcID,
            aggregateDeviceID,
            nil
        ) { _, _, _, _, _ in
            // The HAL requires an active reader for a muted process tap.
            // Audio samples are intentionally discarded without inspection.
        }

        guard createStatus == noErr, let ioProcID else {
            throw QuietlyAudioError.audioOperation(
                name: "Creating the mute engine",
                status: createStatus
            )
        }

        let startStatus = AudioDeviceStart(aggregateDeviceID, ioProcID)
        guard startStatus == noErr else {
            AudioDeviceDestroyIOProcID(aggregateDeviceID, ioProcID)
            throw QuietlyAudioError.audioOperation(
                name: "Starting the mute engine",
                status: startStatus
            )
        }

        return ioProcID
    }

    @available(macOS 14.2, *)
    private func audioProcessObjectIDs() throws -> [AudioObjectID] {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyProcessObjectList,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &dataSize
        )

        guard status == noErr else {
            throw QuietlyAudioError.propertyRead(selector: address.mSelector, status: status)
        }

        let count = Int(dataSize) / MemoryLayout<AudioObjectID>.stride
        guard count > 0 else { return [] }

        var objectIDs = Array(repeating: AudioObjectID(kAudioObjectUnknown), count: count)
        status = objectIDs.withUnsafeMutableBytes { buffer in
            AudioObjectGetPropertyData(
                AudioObjectID(kAudioObjectSystemObject),
                &address,
                0,
                nil,
                &dataSize,
                buffer.baseAddress!
            )
        }

        guard status == noErr else {
            throw QuietlyAudioError.propertyRead(selector: address.mSelector, status: status)
        }

        return objectIDs
    }

    @available(macOS 14.2, *)
    private func resolveProcess(_ objectID: AudioObjectID) -> ResolvedAudioProcess? {
        guard
            let pid: pid_t = property(
                objectID: objectID,
                selector: kAudioProcessPropertyPID,
                initialValue: 0
            ),
            pid != ProcessInfo.processInfo.processIdentifier,
            let processApplication = NSRunningApplication(processIdentifier: pid),
            let runningApplication = userFacingApplication(
                startingAt: processApplication,
                processIdentifier: pid
            )
        else {
            return nil
        }

        let parentBundle = parentApplicationBundle(for: runningApplication)
        let bundle = parentBundle ?? runningApplication.bundleURL.flatMap(Bundle.init(url:))
        let rawBundleIdentifier = bundle?.bundleIdentifier ?? runningApplication.bundleIdentifier
        let stableID = rawBundleIdentifier ?? "pid:\(pid)"
        let name = bundleDisplayName(bundle)
            ?? runningApplication.localizedName
            ?? "Audio Process \(pid)"
        let iconURL = parentBundle?.bundleURL ?? runningApplication.bundleURL
        let icon = iconURL.map { NSWorkspace.shared.icon(forFile: $0.path) }
        let runningOutput: UInt32 = property(
            objectID: objectID,
            selector: kAudioProcessPropertyIsRunningOutput,
            initialValue: 0
        ) ?? 0

        return ResolvedAudioProcess(
            stableID: stableID,
            name: name,
            bundleIdentifier: rawBundleIdentifier,
            processObjectID: objectID,
            processIdentifier: pid,
            icon: icon,
            isProducingAudio: runningOutput != 0
        )
    }

    private func makeApplication(_ processes: [ResolvedAudioProcess]) -> AudioApplication? {
        guard let first = processes.first else { return nil }
        return AudioApplication(
            id: first.stableID,
            name: first.name,
            bundleIdentifier: first.bundleIdentifier,
            processObjectIDs: processes.map(\.processObjectID).sorted(),
            processIdentifiers: processes.map(\.processIdentifier).sorted(),
            icon: first.icon,
            isProducingAudio: processes.contains(where: \.isProducingAudio)
        )
    }

    @available(macOS 14.2, *)
    private func property<T>(
        objectID: AudioObjectID,
        selector: AudioObjectPropertySelector,
        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
        initialValue: T
    ) -> T? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: scope,
            mElement: kAudioObjectPropertyElementMain
        )
        var value = initialValue
        var dataSize = UInt32(MemoryLayout<T>.size)
        let status = withUnsafeMutablePointer(to: &value) {
            AudioObjectGetPropertyData(
                objectID,
                &address,
                0,
                nil,
                &dataSize,
                $0
            )
        }
        return status == noErr ? value : nil
    }

    private func parentApplicationBundle(for application: NSRunningApplication) -> Bundle? {
        guard let bundleURL = application.bundleURL else { return nil }
        let components = bundleURL.standardizedFileURL.pathComponents
        guard let appIndex = components.firstIndex(where: { $0.hasSuffix(".app") }) else {
            return nil
        }

        let appPath = NSString.path(withComponents: Array(components.prefix(through: appIndex)))
        guard appPath != bundleURL.path else { return nil }
        return Bundle(path: appPath)
    }

    private func userFacingApplication(
        startingAt application: NSRunningApplication,
        processIdentifier: pid_t
    ) -> NSRunningApplication? {
        var currentApplication: NSRunningApplication? = application
        var currentPID = processIdentifier
        var visited: Set<pid_t> = []

        for _ in 0..<10 {
            guard currentPID > 1, visited.insert(currentPID).inserted else {
                break
            }

            if let candidate = currentApplication {
                if let host = webKitHostApplication(for: candidate) {
                    return host
                }

                if candidate.activationPolicy == .regular {
                    return candidate
                }

                if let parentBundle = parentApplicationBundle(for: candidate),
                   isUserApplicationBundle(parentBundle) {
                    return candidate
                }

                if candidate.activationPolicy == .accessory,
                   let bundleURL = candidate.bundleURL,
                   isUserApplicationPath(bundleURL.path) {
                    return candidate
                }
            }

            guard let nextPID = parentProcessIdentifier(of: currentPID) else {
                break
            }
            currentPID = nextPID
            currentApplication = NSRunningApplication(processIdentifier: nextPID)
        }

        return nil
    }

    private func webKitHostApplication(
        for helperApplication: NSRunningApplication
    ) -> NSRunningApplication? {
        guard
            helperApplication.bundleIdentifier?.hasPrefix("com.apple.WebKit.") == true,
            let helperName = helperApplication.localizedName
        else {
            return nil
        }

        let foregroundApplications = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
        let applicationsByName = Dictionary(
            foregroundApplications.compactMap { application -> (String, NSRunningApplication)? in
                guard let name = application.localizedName else { return nil }
                return (name, application)
            },
            uniquingKeysWith: { first, _ in first }
        )
        guard let hostName = matchingHostApplicationName(
            for: helperName,
            candidates: Array(applicationsByName.keys)
        ) else {
            return nil
        }
        return applicationsByName[hostName]
    }

    private func parentProcessIdentifier(of processIdentifier: pid_t) -> pid_t? {
        var info = proc_bsdinfo()
        let expectedSize = Int32(MemoryLayout<proc_bsdinfo>.size)
        let result = proc_pidinfo(
            processIdentifier,
            PROC_PIDTBSDINFO,
            0,
            &info,
            expectedSize
        )
        guard result == expectedSize, info.pbi_ppid > 1 else { return nil }
        return pid_t(info.pbi_ppid)
    }

    private func isUserApplicationBundle(_ bundle: Bundle) -> Bool {
        guard let bundleURL = bundle.bundleURL as URL? else { return false }
        return isUserApplicationPath(bundleURL.path)
    }

    private func isUserApplicationPath(_ path: String) -> Bool {
        path.hasPrefix("/Applications/")
            || path.hasPrefix("/System/Applications/")
            || path.contains("/Applications/")
    }

    private func bundleDisplayName(_ bundle: Bundle?) -> String? {
        guard let bundle else { return nil }
        return bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
    }
}
