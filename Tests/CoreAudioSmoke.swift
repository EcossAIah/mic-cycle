import Foundation
import CoreAudio

private enum SmokeError: Error, CustomStringConvertible {
    case failed(String)
    var description: String {
        switch self { case .failed(let message): return message }
    }
}

// Deliberately independent of the application's getter and setter.
private func readDefault() throws -> AudioDeviceID {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    var value = AudioDeviceID(kAudioDeviceUnknown)
    var size = UInt32(MemoryLayout<AudioDeviceID>.size)
    let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                           &address, 0, nil, &size, &value)
    guard status == noErr else { throw SmokeError.failed("Independent read failed: \(status)") }
    return value
}

private func restoreDefault(_ id: AudioDeviceID) async throws {
    var address = AudioObjectPropertyAddress(
        mSelector: kAudioHardwarePropertyDefaultInputDevice,
        mScope: kAudioObjectPropertyScopeGlobal,
        mElement: kAudioObjectPropertyElementMain)
    var value = id
    let status = AudioObjectSetPropertyData(AudioObjectID(kAudioObjectSystemObject),
                                           &address, 0, nil,
                                           UInt32(MemoryLayout<AudioDeviceID>.size), &value)
    guard status == noErr else { throw SmokeError.failed("RESTORE FAILED: \(status)") }
    for _ in 0..<41 {
        if try readDefault() == id { return }
        try await Task.sleep(nanoseconds: 50_000_000)
    }
    throw SmokeError.failed("RESTORE FAILED: default did not return to \(id)")
}

private final class ChangeCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0
    func increment() { lock.lock(); value += 1; lock.unlock() }
    func count() -> Int { lock.lock(); defer { lock.unlock() }; return value }
}

@main
struct CoreAudioSmoke {
    static func main() async {
        do {
            let devices = try CoreAudioClient.inputDevices()
            let original = try readDefault()
            print("Original default input: \(original)")
            for device in devices {
                print("Input: \(device.id) \(device.name); can be default input: \(device.canBeDefaultInput)")
            }
            let eligible = devices.filter { $0.canBeDefaultInput }
            guard !eligible.isEmpty else { throw SmokeError.failed("No eligible default-input devices available") }
            guard original != kAudioDeviceUnknown, eligible.contains(where: { $0.id == original }) else {
                throw SmokeError.failed("No restorable original input; refusing to change the default")
            }

            var address = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain)
            let counter = ChangeCounter()
            let queue = DispatchQueue(label: "mic-cycle.smoke.observer")
            let listener: AudioObjectPropertyListenerBlock = { _, _ in counter.increment() }
            let listenerStatus = AudioObjectAddPropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject), &address, queue, listener)
            guard listenerStatus == noErr else {
                throw SmokeError.failed("Unable to install independent listener: \(listenerStatus)")
            }
            defer {
                AudioObjectRemovePropertyListenerBlock(
                    AudioObjectID(kAudioObjectSystemObject), &address, queue, listener)
            }

            var failure: Error?
            do {
                var changed = false
                for device in eligible {
                    let before = try readDefault()
                    let returned = try await CoreAudioClient.setDefaultInput(device.id)
                    let observed = try readDefault()
                    guard returned == device.id, observed == device.id else {
                        throw SmokeError.failed("Switch mismatch: target \(device.id), returned \(returned), independently read \(observed)")
                    }
                    changed = changed || before != observed
                    print("PASS switch: \(device.name) (\(observed)); independent readback matches")
                }
                do {
                    _ = try await CoreAudioClient.setDefaultInput(AudioDeviceID(kAudioDeviceUnknown))
                    throw SmokeError.failed("Invalid device was unexpectedly accepted")
                } catch let error as SmokeError { throw error }
                catch { print("PASS invalid-device rejection: \(error)") }
                if changed {
                    for _ in 0..<30 {
                        if counter.count() > 0 { break }
                        try await Task.sleep(nanoseconds: 50_000_000)
                    }
                    guard counter.count() > 0 else {
                        throw SmokeError.failed("No default-input change notification received")
                    }
                    print("PASS independent default-input listener: \(counter.count()) notification(s)")
                } else {
                    print("SKIP change notification assertion: only the existing default was selected")
                }
            } catch { failure = error }

            // Run cleanup on every normal error path, using raw Core Audio calls.
            do {
                try await restoreDefault(original)
                print("PASS restored original default input: \(original)")
            } catch {
                fputs("\(error)\n", stderr)
                exit(2)
            }
            if let failure { throw failure }
            print("PASS Core Audio integration checks. Physical microphone capture was not tested.")
        } catch {
            fputs("FAIL: \(error)\n", stderr)
            exit(1)
        }
    }
}
