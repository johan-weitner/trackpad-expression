import ApplicationServices
import CoreGraphics
import Foundation

/// Optional: while enabled, swallow clicks, taps, scrolling and gestures coming from the
/// controller trackpad. The pointer itself keeps moving. Needs Accessibility permission.
final class InputBlocker {
    static let shared = InputBlocker()

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    fileprivate var suppressingScroll = false

    var isRunning: Bool { tap != nil }

    static func hasPermission(prompt: Bool) -> Bool {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt] as CFDictionary
        return AXIsProcessTrustedWithOptions(opts)
    }

    /// Returns false if permission is missing (the system prompt is shown).
    @discardableResult
    func start() -> Bool {
        guard tap == nil else { return true }
        guard Self.hasPermission(prompt: true) else { return false }

        // NSEvent gesture types without CGEventType constants: rotate 18, begin 19, end 20,
        // gesture 29, magnify 30, swipe 31, smartMagnify 32, pressure 34.
        let types: [UInt32] = [
            CGEventType.leftMouseDown, .leftMouseUp, .leftMouseDragged,
            .rightMouseDown, .rightMouseUp, .rightMouseDragged,
            .otherMouseDown, .otherMouseUp, .otherMouseDragged, .scrollWheel,
        ].map(\.rawValue) + [18, 19, 20, 29, 30, 31, 32, 34]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1)) }

        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                          options: .defaultTap, eventsOfInterest: mask,
                                          callback: blockerCallback, userInfo: nil) else { return false }
        self.tap = tap
        source = CFMachPortCreateRunLoopSource(nil, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        guard let tap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        CFMachPortInvalidate(tap)
        self.tap = nil
        source = nil
        suppressingScroll = false
    }

    fileprivate func reenable() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
    }
}

private let blockerCallback: CGEventTapCallBack = { _, type, event, _ in
    let blocker = InputBlocker.shared
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        blocker.reenable()
    case .scrollWheel:
        let drop: Bool
        if event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0 {
            drop = blocker.suppressingScroll // follow the gesture the momentum came from
        } else {
            drop = TouchEngine.shared.controllerOwnsInput()
            blocker.suppressingScroll = drop
        }
        if drop { return nil }
    default:
        if TouchEngine.shared.controllerOwnsInput() { return nil }
    }
    return Unmanaged.passUnretained(event)
}
