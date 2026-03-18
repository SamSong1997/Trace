import Carbon
import Foundation

final class GlobalHotKeyManager {
    private var eventHandler: EventHandlerRef?
    private var hotKeyRef: EventHotKeyRef?
    private var action: (() -> Void)?

    private var hotKeyID = EventHotKeyID(signature: OSType(0x464E4F54), id: 1)

    func register(keyCode: UInt32, modifiers: UInt32, action: @escaping () -> Void) -> Bool {
        unregister()
        self.action = action

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            Self.hotKeyHandler,
            1,
            &eventType,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &eventHandler
        )

        guard installStatus == noErr else {
            NSLog("InstallEventHandler failed: \(installStatus)")
            return false
        }

        let registerStatus = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            NSLog("RegisterEventHotKey failed: \(registerStatus)")
            unregister()
            return false
        }

        return true
    }

    func unregister() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }

        action = nil
    }

    deinit {
        unregister()
    }

    private static let hotKeyHandler: EventHandlerUPP = { _, event, userData in
        guard let event,
              let userData else {
            return noErr
        }

        let manager = Unmanaged<GlobalHotKeyManager>.fromOpaque(userData).takeUnretainedValue()

        var pressedHotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &pressedHotKeyID
        )

        guard status == noErr else { return status }

        if pressedHotKeyID.signature == manager.hotKeyID.signature,
           pressedHotKeyID.id == manager.hotKeyID.id {
            manager.action?()
        }

        return noErr
    }
}
