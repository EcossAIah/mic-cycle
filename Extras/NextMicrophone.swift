import Foundation
import CoreAudio

let system = AudioObjectID(kAudioObjectSystemObject)
let element = kAudioObjectPropertyElementMain

func address(_ selector: AudioObjectPropertySelector,
             _ scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) -> AudioObjectPropertyAddress {
    AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
}

func audioDevices() throws -> [AudioDeviceID] {
    var property = address(kAudioHardwarePropertyDevices)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(system, &property, 0, nil, &size) == noErr else {
        throw NSError(domain: "MicrophoneCycle", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to list audio devices"])
    }
    let count = Int(size) / MemoryLayout<AudioDeviceID>.stride
    var ids = [AudioDeviceID](repeating: 0, count: count)
    guard AudioObjectGetPropertyData(system, &property, 0, nil, &size, &ids) == noErr else {
        throw NSError(domain: "MicrophoneCycle", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unable to read audio device list"])
    }
    return ids
}

func supportsInput(_ id: AudioDeviceID) -> Bool {
    var property = address(kAudioDevicePropertyStreamConfiguration, kAudioDevicePropertyScopeInput)
    var size: UInt32 = 0
    guard AudioObjectGetPropertyDataSize(id, &property, 0, nil, &size) == noErr,
          size >= MemoryLayout<UInt32>.size else { return false }
    let raw = UnsafeMutableRawPointer.allocate(byteCount: Int(size), alignment: MemoryLayout<AudioBufferList>.alignment)
    defer { raw.deallocate() }
    guard AudioObjectGetPropertyData(id, &property, 0, nil, &size, raw) == noErr else { return false }
    let buffers = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
    return buffers.contains { $0.mNumberChannels > 0 }
}

func deviceName(_ id: AudioDeviceID) -> String {
    var property = address(kAudioObjectPropertyName)
    var name: Unmanaged<CFString>? = nil
    var size = UInt32(MemoryLayout<Unmanaged<CFString>?>.size)
    guard AudioObjectGetPropertyData(id, &property, 0, nil, &size, &name) == noErr else {
        return "Device \(id)"
    }
    return (name?.takeRetainedValue() as String?) ?? "Device \(id)"
}

func defaultInput() throws -> AudioDeviceID {
    var property = address(kAudioHardwarePropertyDefaultInputDevice)
    var id = AudioDeviceID(kAudioDeviceUnknown)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    guard AudioObjectGetPropertyData(system, &property, 0, nil, &size, &id) == noErr else {
        throw NSError(domain: "MicrophoneCycle", code: 3, userInfo: [NSLocalizedDescriptionKey: "Unable to read current microphone"])
    }
    return id
}

func setDefaultInput(_ id: AudioDeviceID) throws {
    var property = address(kAudioHardwarePropertyDefaultInputDevice)
    var newID = id
    let status = AudioObjectSetPropertyData(system, &property, 0, nil,
                                            UInt32(MemoryLayout<AudioDeviceID>.size), &newID)
    guard status == noErr else {
        throw NSError(domain: "MicrophoneCycle", code: Int(status), userInfo: [NSLocalizedDescriptionKey: "Unable to select \(deviceName(id)) (Core Audio error \(status))"])
    }
}

do {
    let inputs = try audioDevices().filter(supportsInput)
    guard !inputs.isEmpty else {
        fputs("No audio input devices available.\n", stderr)
        exit(1)
    }
    if CommandLine.arguments.contains("--list") {
        let current = try defaultInput()
        for id in inputs { print("\(id == current ? "*" : " ") \(deviceName(id))") }
    } else {
        let current = try defaultInput()
        let next = inputs.firstIndex(of: current).map { inputs[($0 + 1) % inputs.count] } ?? inputs[0]
        try setDefaultInput(next)
        print("Microphone: \(deviceName(next))")
    }
} catch {
    fputs("Error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
