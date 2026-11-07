import Carbon
import Foundation

/// System-wide shortcuts via Carbon RegisterEventHotKey: no permissions needed,
/// works under secure input. ⌃⌥⌘E = enable, ⌃⌥⌘D = disable.
enum Hotkeys {
    static let enableLabel = "⌃⌥⌘E"
    static let disableLabel = "⌃⌥⌘D"

    private static var handler: ((Bool) -> Void)?
    private static var refs: [EventHotKeyRef?] = []

    /// Returns human-readable errors for shortcuts that could not be registered.
    @discardableResult
    static func register(_ onToggle: @escaping (Bool) -> Void) -> [String] {
        handler = onToggle
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                              nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
            let on = id.id == 1
            DispatchQueue.main.async { Hotkeys.handler?(on) }
            return noErr
        }, 1, &spec, nil, nil)

        let mods = UInt32(controlKey | optionKey | cmdKey)
        let sig: OSType = 0x5450_4558 // 'TPEX'
        var errors: [String] = []
        for (id, key, label) in [(UInt32(1), kVK_ANSI_E, enableLabel), (UInt32(2), kVK_ANSI_D, disableLabel)] {
            var ref: EventHotKeyRef?
            let status = RegisterEventHotKey(UInt32(key), mods, EventHotKeyID(signature: sig, id: id),
                                             GetApplicationEventTarget(), 0, &ref)
            if status == noErr { refs.append(ref) } else {
                errors.append("\(label) could not be registered (\(status))"
                              + (status == eventHotKeyExistsErr ? " — another app is using it" : ""))
            }
        }
        return errors
    }
}
