import SwiftUI
import AppKit
import ServiceManagement

@MainActor
final class AppController: ObservableObject {
    let audio = AudioDeviceStore()
    private let overlay = ConfirmationOverlay()
    private var hotKey: GlobalHotKey?
    @Published private(set) var shortcutError: String?
    @Published private(set) var opensAtLogin = SMAppService.mainApp.status == .enabled
    @Published private(set) var loginItemError: String?

    init() {
        audio.confirmation = { [weak self] text, success in self?.overlay.show(text, success: success) }
        do {
            hotKey = try GlobalHotKey { [weak self] in
                MainActor.assumeIsolated { self?.audio.cycle() }
            }
        } catch { shortcutError = error.localizedDescription }
    }

    func setOpensAtLogin(_ enabled: Bool) {
        do {
            if enabled { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            loginItemError = nil
        } catch { loginItemError = "Open at Login failed: \(error.localizedDescription)" }
        // Re-read so the checkbox reflects what macOS actually did.
        opensAtLogin = SMAppService.mainApp.status == .enabled
    }
}

@main
struct MicCycleApp: App {
    @StateObject private var controller = AppController()
    var body: some Scene {
        MenuBarExtra {
            DeviceMenu(controller: controller, audio: controller.audio)
        } label: {
            Label("Mic Cycle", systemImage: "mic.fill")
        }
        .menuBarExtraStyle(.menu)
    }
}

struct DeviceMenu: View {
    @ObservedObject var controller: AppController
    @ObservedObject var audio: AudioDeviceStore

    var body: some View {
        Text("Input: \(audio.currentName)")
        Divider()
        if !audio.hasEligibleInput { Text("No microphones available as default input") }
        ForEach(audio.devices.filter(\.canBeDefaultInput)) { device in
            Button { audio.select(device.id) } label: {
                if device.id == audio.currentID {
                    Label(device.name, systemImage: "checkmark")
                } else { Text(device.name) }
            }
            .disabled(audio.isSwitching)
        }
        Divider()
        Button("Next Microphone    ⌃⌥M") { audio.cycle() }
            .disabled(!audio.hasEligibleInput || audio.isSwitching)
        if let error = audio.error { Text(error) }
        if let error = controller.shortcutError { Text(error) }
        Divider()
        Toggle("Open at Login", isOn: Binding(
            get: { controller.opensAtLogin },
            set: { controller.setOpensAtLogin($0) }
        ))
        if let error = controller.loginItemError { Text(error) }
        Button("Copy Diagnostics") {
            let text = audio.diagnostics()
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
        }
        Button("Quit Mic Cycle") { NSApplication.shared.terminate(nil) }
            .keyboardShortcut("q")
    }

}
