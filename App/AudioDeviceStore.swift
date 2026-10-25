import Foundation
import CoreAudio
import Combine

private final class AudioListener {
    let object: AudioObjectID
    var property: AudioObjectPropertyAddress
    let block: AudioObjectPropertyListenerBlock
    init(object: AudioObjectID, property: AudioObjectPropertyAddress, changed: @escaping () -> Void) throws {
        self.object = object
        self.property = property
        self.block = { _, _ in changed() }
        try CoreAudioClient.check(AudioObjectAddPropertyListenerBlock(object, &self.property, .main, block), "Could not observe audio changes")
    }
    deinit { AudioObjectRemovePropertyListenerBlock(object, &property, .main, block) }
}

@MainActor
final class AudioDeviceStore: ObservableObject {
    @Published private(set) var devices: [InputDevice] = []
    @Published private(set) var currentID: AudioDeviceID = kAudioDeviceUnknown
    @Published private(set) var error: String?
    @Published private(set) var isSwitching = false
    var confirmation: ((String, Bool) -> Void)?
    private var systemListeners: [AudioListener] = []
    private var deviceListeners: [AudioListener] = []
    private var observedIDs: [AudioDeviceID] = []
    private var observationError: String?
    private var lastSwitchFailure: String?

    var hasEligibleInput: Bool { devices.contains(where: \.canBeDefaultInput) }

    func diagnostics() -> String {
        refresh()
        let rows = devices.map {
            "- \($0.name) | ID \($0.id) | default eligible: \($0.canBeDefaultInput ? "yes" : "no or unavailable")\($0.id == currentID ? " | CURRENT" : "")"
        }
        return (["Mic Cycle 1.3.0 diagnostics", "Current default: \(currentName) (ID \(currentID))", "Input devices:"] + rows +
                ["Last switch failure: \(lastSwitchFailure ?? "none")", "Observation/read error: \(error ?? "none")"]).joined(separator: "\n")
    }

    var currentName: String {
        if let device = devices.first(where: { $0.id == currentID }) { return device.name }
        return currentID == kAudioDeviceUnknown ? "No microphone" : CoreAudioClient.deviceName(currentID)
    }

    init() {
        do {
            for selector in [kAudioHardwarePropertyDevices, kAudioHardwarePropertyDefaultInputDevice] {
                systemListeners.append(try listener(CoreAudioClient.system, selector))
            }
        } catch { observationError = error.localizedDescription }
        refresh()
    }

    private func listener(_ object: AudioObjectID, _ selector: AudioObjectPropertySelector,
                          scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal) throws -> AudioListener {
        try AudioListener(object: object, property: CoreAudioClient.address(selector, scope: scope)) { [weak self] in
            // Core Audio invokes this block on the registered main queue.
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    func refresh() {
        do {
            let allIDs = try CoreAudioClient.deviceIDs()
            // Observe all devices, including those that acquire input streams later.
            if allIDs != observedIDs {
                deviceListeners.removeAll()
                observedIDs = allIDs
                for id in allIDs {
                    for (selector, scope) in [(kAudioObjectPropertyName, kAudioObjectPropertyScopeGlobal),
                                               (kAudioDevicePropertyDeviceIsAlive, kAudioObjectPropertyScopeGlobal),
                                               (kAudioDevicePropertyDeviceCanBeDefaultDevice, kAudioDevicePropertyScopeInput),
                                               (kAudioDevicePropertyStreamConfiguration, kAudioDevicePropertyScopeInput)] {
                        do { deviceListeners.append(try listener(id, selector, scope: scope)) }
                        catch { observationError = error.localizedDescription }
                    }
                }
            }
            devices = try CoreAudioClient.inputDevices()
            currentID = try CoreAudioClient.defaultInput()
            error = observationError
        } catch {
            // Do not display a stale checkmark after a failed system read.
            currentID = kAudioDeviceUnknown
            devices = []
            self.error = error.localizedDescription
        }
    }

    func cycle() {
        guard !isSwitching else { return }
        // Always derive the next choice from Core Audio now, not cached menu state.
        do {
            let available = try CoreAudioClient.inputDevices()
            let actual = try CoreAudioClient.defaultInput()
            guard let next = CoreAudioClient.nextInput(in: available, current: actual) else {
                throw CoreAudioClient.failure("No microphones can be the default input.")
            }
            select(next.id)
        } catch { report(error) }
    }

    func select(_ id: AudioDeviceID) {
        guard !isSwitching else { return }
        let requestedName = devices.first(where: { $0.id == id })?.name ?? CoreAudioClient.deviceName(id)
        isSwitching = true
        Task {
            defer { isSwitching = false }
            do {
                try await CoreAudioClient.setDefaultInput(id)
                refresh()
                // The default may have changed again while the menu refreshed.
                guard currentID == id else { throw CoreAudioClient.failure("The default microphone changed again.") }
                confirmation?(currentName, true)
            } catch {
                refresh()
                report(CoreAudioClient.failure("\(error.localizedDescription) Requested: \(requestedName) (ID \(id)). Actual: \(currentName) (ID \(currentID))."))
            }
        }
    }

    private func report(_ failure: Error) {
        error = failure.localizedDescription
        lastSwitchFailure = failure.localizedDescription
        confirmation?(failure.localizedDescription, false)
    }
}
