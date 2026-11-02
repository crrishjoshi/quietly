import AppKit
import CoreAudio
import Darwin
import Foundation

func propertyAddress(_ selector: AudioObjectPropertySelector) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(
        mSelector: selector,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain
    )
}

func scalarProperty<T>(
    objectID: AudioObjectID,
    selector: AudioObjectPropertySelector,
    initialValue: T
) -> T? {
    var address = propertyAddress(selector)
    var value = initialValue
    var size = UInt32(MemoryLayout<T>.size)
    let status = withUnsafeMutablePointer(to: &value) {
        AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, $0)
    }
    return status == noErr ? value : nil
}

func stringProperty(
    objectID: AudioObjectID,
    selector: AudioObjectPropertySelector
) -> String? {
    var address = propertyAddress(selector)
    var value: CFString = "" as CFString
    var size = UInt32(MemoryLayout<CFString>.stride)
    let status = withUnsafeMutablePointer(to: &value) {
        AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, $0)
    }
    return status == noErr ? value as String : nil
}

func audioProcessObjectIDs() -> [AudioObjectID] {
    var address = propertyAddress(kAudioHardwarePropertyProcessObjectList)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(
        AudioObjectID(kAudioObjectSystemObject),
        &address,
        0,
        nil,
        &size
    ) == noErr else {
        return []
    }

    var values = Array(
        repeating: AudioObjectID(kAudioObjectUnknown),
        count: Int(size) / MemoryLayout<AudioObjectID>.stride
    )
    let status = values.withUnsafeMutableBytes {
        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            0,
            nil,
            &size,
            $0.baseAddress!
        )
    }
    return status == noErr ? values : []
}

func parentPID(_ pid: pid_t) -> pid_t {
    var info = proc_bsdinfo()
    let size = Int32(MemoryLayout<proc_bsdinfo>.size)
    guard proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &info, size) == size else {
        return 0
    }
    return pid_t(info.pbi_ppid)
}

func processPath(_ pid: pid_t) -> String {
    var buffer = Array(repeating: CChar(0), count: 4096)
    let length = proc_pidpath(pid, &buffer, UInt32(buffer.count))
    guard length > 0 else { return "" }
    return String(cString: buffer)
}

print("object\tpid\tppid\tactive\tHAL bundle\tNS name\tNS bundle\tpolicy\tpath")

for objectID in audioProcessObjectIDs() {
    let pid: pid_t = scalarProperty(
        objectID: objectID,
        selector: kAudioProcessPropertyPID,
        initialValue: 0
    ) ?? 0
    let running: UInt32 = scalarProperty(
        objectID: objectID,
        selector: kAudioProcessPropertyIsRunningOutput,
        initialValue: 0
    ) ?? 0
    let halBundle = stringProperty(
        objectID: objectID,
        selector: kAudioProcessPropertyBundleID
    ) ?? ""
    let runningApplication = NSRunningApplication(processIdentifier: pid)
    let policy = runningApplication.map { String(describing: $0.activationPolicy) } ?? ""

    print([
        String(objectID),
        String(pid),
        String(parentPID(pid)),
        running == 0 ? "no" : "YES",
        halBundle,
        runningApplication?.localizedName ?? "",
        runningApplication?.bundleIdentifier ?? "",
        policy,
        processPath(pid)
    ].joined(separator: "\t"))
}
