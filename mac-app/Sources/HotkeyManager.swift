import Cocoa
import Carbon

public final class HotkeyManager {
    public static let shared = HotkeyManager()

    public typealias Handler = () -> Void

    private var eventHandlerRef: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var handlers: [UInt32: Handler] = [:]

    private let signature: FourCharCode = 0x424E474C // 'BNGL'
    private let banglaHotKeyID: UInt32 = 1001
    private let englishHotKeyID: UInt32 = 1002

    private var lastTriggerTime: TimeInterval = 0

    private init() {}

    deinit {
        unregister()
    }

    /// Registers the global shortcuts: Command+Shift+B (Bangla) and Command+Shift+E (English).
    /// Returns the display names of any shortcuts that could not be registered.
    @discardableResult
    public func registerShortcuts(bangla: @escaping Handler, english: @escaping Handler) -> [String] {
        unregister()
        handlers = [banglaHotKeyID: bangla, englishHotKeyID: english]

        // 1. Install Carbon event handler
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        let handlerUPP: EventHandlerUPP = { _, theEvent, userData in
            guard let theEvent = theEvent, let userData = userData else {
                return OSStatus(eventNotHandledErr)
            }

            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                theEvent,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )

            guard status == noErr else { return status }

            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

            if hotKeyID.signature == manager.signature, let handler = manager.handlers[hotKeyID.id] {
                // Debounce guard (500ms)
                let now = Date().timeIntervalSince1970
                if now - manager.lastTriggerTime > 0.5 {
                    manager.lastTriggerTime = now
                    DispatchQueue.main.async {
                        handler()
                    }
                }
                return noErr
            }

            return OSStatus(eventNotHandledErr)
        }

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            handlerUPP,
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        guard installStatus == noErr else {
            return ["⌘⇧B", "⌘⇧E"]
        }

        // 2. Register the key combinations
        let modifiers = UInt32(cmdKey | shiftKey)
        let shortcuts: [(id: UInt32, keyCode: Int, name: String)] = [
            (banglaHotKeyID, kVK_ANSI_B, "⌘⇧B"),
            (englishHotKeyID, kVK_ANSI_E, "⌘⇧E")
        ]

        var failed: [String] = []
        for shortcut in shortcuts {
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(
                UInt32(shortcut.keyCode),
                modifiers,
                EventHotKeyID(signature: signature, id: shortcut.id),
                GetApplicationEventTarget(),
                0,
                &ref
            )
            if status == noErr, let ref = ref {
                hotKeyRefs.append(ref)
            } else {
                failed.append(shortcut.name)
            }
        }
        return failed
    }

    public func unregister() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs = []
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
        handlers = [:]
    }
}
