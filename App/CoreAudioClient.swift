import Foundation
import CoreAudio

struct InputDevice: Identifiable, Equatable {
    let id: AudioDeviceID
    let name: String
    let canBeDefaultInput: Bool

    init(id: AudioDeviceID, name: String, canBeDefaultInput: Bool = true) {
        self.id = id
        self.name = name
        self.canBeDefaultInput = canBeDefaultInput
    }
}

enum CoreAudioClient {
    static let system = AudioObjectID(kAudioObjectSystemObject)
    static func address(_ selector: AudioObjectPropertySelector,
                        scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: kAudioObjectPropertyElementMain)
    }
    static func check(_ status: OSStatus, _ message: String) throws {
        guard status == noErr else {
            throw NSError(domain: "MicCycle.CoreAudio", code: Int(status),
                          userInfo: [NSLocalizedDescriptionKey: "\(message) (Core Audio \(status))."])
        }
    }
    static func deviceIDs() throws -> [AudioDeviceID] {
        var property = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        try check(AudioObjectGetPropertyDataSize(system, &property, 0, nil, &size), "Could not list audio devices")
        guard size > 0 else { return [] }
        guard size % UInt32(MemoryLayout<AudioDeviceID>.stride) == 0 else {
            throw failure("macOS returned an invalid audio device list.")
        }
        var ids = [AudioDeviceID](repeating: 0, count: Int(size) / MemoryLayout<AudioDeviceID>.stride)
        try ids.withUnsafeMutableBytes { bytes in
            try check(AudioObjectGetPropertyData(system, &property, 0, nil, &size, bytes.baseAddress!), "Could not read audio devices")
        }
        return Array(ids.prefix(Int(size) / MemoryLayout<AudioDeviceID>.stride))
    }
    static func supportsInput(_ id: AudioDeviceID) -> Bool {
        var property = address(kAudioDevicePropertyStreamConfiguration, scope: kAudioDevicePropertyScopeInput)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(id, &property, 0, nil, &size) == noErr,
              size >= MemoryLayout<AudioBufferList>.size else { return false }
        let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
        defer { raw.deallocate() }
        guard AudioObjectGetPropertyData(id, &property, 0, nil, &size, raw) == noErr else { return false }
        return UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self)).contains { $0.mNumberChannels > 0 }
    }
    static func isAlive(_ id: AudioDeviceID) -> Bool {
        var property = address(kAudioDevicePropertyDeviceIsAlive)
        var alive: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(id, &property, 0, nil, &size, &alive) == noErr && alive != 0
    }
    static func canBeDefaultInput(_ id: AudioDeviceID) -> Bool {
        var property = address(kAudioDevicePropertyDeviceCanBeDefaultDevice, scope: kAudioDevicePropertyScopeInput)
        var eligible: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        return AudioObjectGetPropertyData(id, &property, 0, nil, &size, &eligible) == noErr && eligible != 0
    }
    static func deviceName(_ id: AudioDeviceID) -> String {
        var property = address(kAudioObjectPropertyName)
        var name: Unmanaged<CFString>? = nil
        var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
        guard AudioObjectGetPropertyData(id, &property, 0, nil, &size, &name) == noErr else { return "Device \(id)" }
        return (name?.takeRetainedValue() as String?) ?? "Device \(id)"
    }
    static func inputDevices() throws -> [InputDevice] {
        try deviceIDs().filter { isAlive($0) && supportsInput($0) }
            .map { InputDevice(id: $0, name: deviceName($0), canBeDefaultInput: canBeDefaultInput($0)) }
            .sorted { lhs, rhs in
                let order = lhs.name.localizedStandardCompare(rhs.name)
                return order == .orderedSame ? lhs.id < rhs.id : order == .orderedAscending
            }
    }
    static func nextInput(in devices: [InputDevice], current: AudioDeviceID) -> InputDevice? {
        let eligible = devices.filter(\.canBeDefaultInput)
        guard !eligible.isEmpty else { return nil }
        let index = eligible.firstIndex(where: { $0.id == current }).map { ($0 + 1) % eligible.count } ?? 0
        return eligible[index]
    }
    static func defaultInput() throws -> AudioDeviceID {
        var property = address(kAudioHardwarePropertyDefaultInputDevice)
        var id = AudioDeviceID(kAudioDeviceUnknown)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        try check(AudioObjectGetPropertyData(system, &property, 0, nil, &size, &id), "Could not read the default microphone")
        return id
    }
    @discardableResult
    static func setDefaultInput(_ id: AudioDeviceID) async throws -> AudioDeviceID {
        try await switchAndVerify(id, devices: inputDevices, readDefault: defaultInput, writeDefault: { requested in
            var property = address(kAudioHardwarePropertyDefaultInputDevice)
            var settable = DarwinBoolean(false)
            try check(AudioObjectIsPropertySettable(system, &property, &settable), "Could not check microphone selection")
            guard settable.boolValue else { throw failure("The default microphone cannot be changed.") }
            var value = requested
            try check(AudioObjectSetPropertyData(system, &property, 0, nil,
                                                UInt32(MemoryLayout<AudioDeviceID>.size), &value), "Could not select the microphone")
        })
    }
    // This seam lets tests exercise the same verification path without changing hardware.
    @discardableResult
    static func switchAndVerify(_ id: AudioDeviceID,
                                devices: () throws -> [InputDevice],
                                readDefault: () throws -> AudioDeviceID,
                                writeDefault: (AudioDeviceID) throws -> Void,
                                attempts: Int = 41,
                                delayNanoseconds: UInt64 = 50_000_000) async throws -> AudioDeviceID {
        let available = try devices()
        guard let requested = available.first(where: { $0.id == id }) else { throw failure("That microphone (ID \(id)) is no longer available.") }
        guard requested.canBeDefaultInput else {
            throw failure("\(requested.name) (ID \(id)) cannot be the default microphone.")
        }
        try writeDefault(id)
        var actual = AudioDeviceID(kAudioDeviceUnknown)
        for attempt in 0..<max(1, attempts) {
            actual = try readDefault()
            if actual == id { return actual }
            if attempt + 1 < max(1, attempts) { try await Task.sleep(nanoseconds: delayNanoseconds) }
        }
        let actualName = available.first(where: { $0.id == actual })?.name ?? "Unknown device"
        throw failure("macOS did not confirm the requested microphone: \(requested.name) (ID \(id)). Actual: \(actualName) (ID \(actual)).")
    }
    static func failure(_ message: String) -> NSError {
        NSError(domain: "MicCycle.CoreAudio", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
