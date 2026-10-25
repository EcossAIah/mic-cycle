import Carbon

final class GlobalHotKey {
    private var hotKey: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let action: () -> Void
    private static let signature: OSType = 0x4D494343 // MICC

    init(action: @escaping () -> Void) throws {
        self.action = action
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let installed = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                           MemoryLayout<EventHotKeyID>.size, nil, &id)
            guard status == noErr, id.signature == GlobalHotKey.signature, id.id == 1 else { return OSStatus(eventNotHandledErr) }
            Unmanaged<GlobalHotKey>.fromOpaque(context).takeUnretainedValue().action()
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
        try CoreAudioClient.check(installed, "Could not install the keyboard shortcut")
        let id = EventHotKeyID(signature: Self.signature, id: 1)
        let status = RegisterEventHotKey(UInt32(kVK_ANSI_M), UInt32(controlKey | optionKey), id,
                                         GetApplicationEventTarget(), 0, &hotKey)
        if status != noErr {
            if let handler { RemoveEventHandler(handler); self.handler = nil }
            try CoreAudioClient.check(status, "Control+Option+M is unavailable; another app may already use it")
        }
    }
    deinit {
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let handler { RemoveEventHandler(handler) }
    }
}
