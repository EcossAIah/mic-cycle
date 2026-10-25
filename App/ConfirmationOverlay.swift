import AppKit
import SwiftUI

@MainActor
final class ConfirmationOverlay {
    private var panel: NSPanel?
    private var dismissal: Task<Void, Never>?

    func show(_ text: String, success: Bool) {
        dismissal?.cancel()
        panel?.orderOut(nil)
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 340, height: 100),
                            styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.contentView = NSHostingView(rootView:
            HStack(spacing: 12) {
                Image(systemName: success ? "mic.fill" : "exclamationmark.triangle.fill")
                    .font(.system(size: 26)).foregroundStyle(success ? Color.accentColor : .orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text(success ? "Microphone selected" : "Could not confirm microphone").font(.headline)
                    Text(text).font(.subheadline).lineLimit(3)
                }
                Spacer(minLength: 0)
            }
            .padding(18).frame(width: 340, height: 100)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        )
        let screen = NSScreen.screens.first(where: { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }) ?? NSScreen.main
        if let frame = screen?.visibleFrame {
            panel.setFrameOrigin(NSPoint(x: frame.midX - 170, y: frame.maxY - 140))
        }
        self.panel = panel
        panel.orderFrontRegardless()
        dismissal = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: success ? 1_800_000_000 : 3_500_000_000) }
            catch { return }
            self?.panel?.orderOut(nil)
            self?.panel = nil
        }
    }
}
