// Feasibility test:
//   1. Read raw touches from all trackpads via MultitouchSupport (no focus needed).
//   2. While ENABLED, map the first finger's vertical position on the controller trackpad
//      to a CC (default CC11), sent on a virtual CoreMIDI source "Trackpad Expression".
//   3. While ENABLED, swallow cursor/click/scroll/gesture events while only the controller
//      trackpad is touched, so it stops driving the cursor.
//   4. Global shortcuts toggle ENABLED: ⌃⌥⌘E = on, ⌃⌥⌘D = off. Default is off.
//
// Needs Accessibility permission (event tap for suppression + shortcuts).
//
// Usage: swift run touchtest [--builtin] [--cc N] [--channel 1-16] [--verbose]
//                            [--no-suppress] [--no-sound] [--start-enabled]
//   default device = the first non-built-in trackpad (Magic Trackpad), falling back to built-in.

import Foundation
import AppKit
import CoreMIDI
import CoreGraphics
import ApplicationServices
import Carbon
import MTShim

// MARK: - Options

var useBuiltin = false
var ccNumber: UInt8 = 11
var midiChannel: UInt8 = 0 // 0-based
var verbose = false
var suppress = true
var sound = true
var startEnabled = false

var args = CommandLine.arguments.dropFirst().makeIterator()
while let a = args.next() {
    switch a {
    case "--builtin": useBuiltin = true
    case "--cc": ccNumber = UInt8(max(0, min(127, args.next().flatMap { Int($0) } ?? 11)))
    case "--channel": midiChannel = UInt8(max(1, min(16, args.next().flatMap { Int($0) } ?? 1)) - 1)
    case "--verbose": verbose = true
    case "--no-suppress": suppress = false
    case "--no-sound": sound = false
    case "--start-enabled": startEnabled = true
    default: print("unknown option \(a)"); exit(2)
    }
}

// MARK: - Permission

let axOpts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
if !AXIsProcessTrustedWithOptions(axOpts) {
    print("""
    ✗ Needs Accessibility permission for the app running this binary
      (e.g. Terminal / iTerm / Ghostty). Grant it in System Settings → Privacy & Security
      → Accessibility, then quit and reopen that terminal app and run again.
    """)
    exit(1)
}

// MARK: - MIDI

var client = MIDIClientRef()
var source = MIDIEndpointRef()

func check(_ status: OSStatus, _ what: String) {
    if status != noErr { print("✗ \(what) failed: \(status)"); exit(1) }
}

check(MIDIClientCreateWithBlock("TouchpadExpression" as CFString, &client, nil), "MIDIClientCreate")
check(MIDISourceCreateWithProtocol(client, "Trackpad Expression" as CFString, ._1_0, &source),
      "MIDISourceCreate")
print("✓ Virtual MIDI source \"Trackpad Expression\" created (CC\(ccNumber), channel \(midiChannel + 1))")

func sendCC(_ value: UInt8) {
    // UMP type 2 = MIDI 1.0 channel voice message, group 0.
    let word: UInt32 = 0x2000_0000
        | (UInt32(0xB0 | midiChannel) << 16)
        | (UInt32(ccNumber) << 8)
        | UInt32(value)
    var list = MIDIEventList()
    var packet = MIDIEventListInit(&list, ._1_0)
    var w = word
    packet = MIDIEventListAdd(&list, MemoryLayout<MIDIEventList>.size, packet, mach_absolute_time(), 1, &w)
    MIDIReceivedEventList(source, &list)
}

// MARK: - Multitouch

var errBuf = [CChar](repeating: 0, count: 256)
guard mt_load(&errBuf, Int32(errBuf.count)) else {
    print("✗ MultitouchSupport: \(String(cString: errBuf))"); exit(1)
}

guard let cfList = mt_device_list(), CFArrayGetCount(cfList) > 0 else {
    print("✗ No multitouch devices found"); exit(1)
}
let devices: [MTDeviceRef] = (0..<CFArrayGetCount(cfList)).map {
    UnsafeMutableRawPointer(mutating: CFArrayGetValueAtIndex(cfList, $0)!)
}

print("✓ Found \(devices.count) multitouch device(s):")
for (i, d) in devices.enumerated() {
    var w: Int32 = 0, h: Int32 = 0
    let size = mt_surface_size(d, &w, &h) ? String(format: "%.0f×%.0f mm", Double(w) / 100, Double(h) / 100) : "size ?"
    print("   [\(i)] \(mt_is_builtin(d) ? "built-in" : "external") · \(size) · id \(String(mt_device_id(d), radix: 16))")
}

let target: MTDeviceRef = devices.first(where: { mt_is_builtin($0) == useBuiltin }) ?? devices[0]
print("→ Controller device: [\(devices.firstIndex(of: target)!)]")

// MARK: - Shared state
// Written from the MultitouchSupport thread and the main thread (event tap). Word-sized,
// aligned values; good enough for a prototype — the real app will use proper atomics.

nonisolated(unsafe) var enabled = false
nonisolated(unsafe) var controllerDevice = target
nonisolated(unsafe) var lastValue: Int = -1
nonisolated(unsafe) var lastLog: Double = 0
nonisolated(unsafe) var frameCount = 0
nonisolated(unsafe) var controllerFingers = 0
nonisolated(unsafe) var otherFingers = 0
nonisolated(unsafe) var controllerLastTouchNs: UInt64 = 0
nonisolated(unsafe) var suppressedCount = 0
nonisolated(unsafe) var ccSentCount = 0

func nowNs() -> UInt64 { DispatchTime.now().uptimeNanoseconds }

func setEnabled(_ on: Bool, via: String) {
    guard on != enabled else { return }
    enabled = on
    lastValue = -1 // so the first touch after enabling always sends
    if sound { NSSound(named: on ? "Tink" : "Pop")?.play() }
    print((on ? "● ENABLED  — Magic Trackpad is now an expression fader"
              : "○ DISABLED — trackpad works normally") + "  [\(via)]")
}

// MARK: - Touch callback

let callback: MTContactCallback = { device, touches, count, timestamp, _ in
    frameCount += 1
    let isController = device == controllerDevice
    if isController {
        controllerFingers = Int(count)
        if count > 0 { controllerLastTouchNs = nowNs() }
    } else {
        otherFingers = Int(count)
    }

    if enabled, isController, count > 0, let t = touches?.pointee {
        let v = Int((max(0, min(1, t.normalized.position.y)) * 127).rounded())
        if v != lastValue {
            lastValue = v
            sendCC(UInt8(v))
            ccSentCount += 1
        }
    }

    if verbose, timestamp - lastLog > 0.1 || count == 0 {
        lastLog = timestamp
        let tag = isController ? "CTRL" : "    "
        let idx = devices.firstIndex(of: device!) ?? -1
        if count == 0 {
            print("\(tag) dev\(idx)  (no touches)")
        } else if let touches {
            let desc = (0..<Int(count)).map { i -> String in
                let t = touches[i]
                return String(format: "#%d x=%.2f y=%.2f st=%d", t.identifier,
                              t.normalized.position.x, t.normalized.position.y, t.state)
            }.joined(separator: "  ")
            let cc = isController && enabled ? "  → CC\(ccNumber)=\(lastValue)" : ""
            print("\(tag) dev\(idx)  \(count)f  \(desc)\(cc)")
        }
    }
    return 0
}

for d in devices {
    mt_register(d, callback)
    mt_start(d)
}

// MARK: - Event tap: shortcuts + cursor suppression

/// Grace period after the last controller frame, to catch trailing cursor deltas / taps.
let graceNs: UInt64 = 150_000_000
let keyE: Int64 = 0x0E, keyD: Int64 = 0x02 // kVK_ANSI_E, kVK_ANSI_D (physical positions)
let hotkeyMods: CGEventFlags = [.maskControl, .maskAlternate, .maskCommand]
nonisolated(unsafe) var suppressingScroll = false
nonisolated(unsafe) var eventTap: CFMachPort?

func controllerOwnsInput() -> Bool {
    enabled && suppress && otherFingers == 0
        && (controllerFingers > 0 || nowNs() &- controllerLastTouchNs < graceNs)
}

// NSEvent gesture types (no CGEventType constants): rotate 18, begin 19, end 20,
// gesture 29, magnify 30, swipe 31, smartMagnify 32, pressure 34.
let tapTypes: [UInt32] = [
    CGEventType.mouseMoved, .leftMouseDown, .leftMouseUp, .leftMouseDragged,
    .rightMouseDown, .rightMouseUp, .rightMouseDragged,
    .otherMouseDown, .otherMouseUp, .otherMouseDragged, .scrollWheel, .keyDown,
].map { $0.rawValue } + [18, 19, 20, 29, 30, 31, 32, 34]
let tapMask = tapTypes.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << CGEventMask($1)) }

let tapCallback: CGEventTapCallBack = { _, type, event, _ in
    switch type {
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
        if let eventTap { CGEvent.tapEnable(tap: eventTap, enable: true) }
        return Unmanaged.passUnretained(event)

    case .keyDown:
        // Fallback path; normally the Carbon hotkey consumes these before the tap sees them.
        let flags = event.flags
        let key = event.getIntegerValueField(.keyboardEventKeycode)
        if verbose {
            print(String(format: "key seen by tap: code=%lld flags=0x%llx", key, flags.rawValue))
        }
        guard flags.contains(hotkeyMods), !flags.contains(.maskShift) else { break }
        guard key == keyE || key == keyD else { break }
        if event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            setEnabled(key == keyE, via: "event tap")
        }
        return nil // swallow the shortcut so the DAW never sees it

    case .scrollWheel:
        let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase)
        let drop: Bool
        if momentum != 0 {
            drop = suppressingScroll // follow the decision of the gesture it came from
        } else {
            drop = controllerOwnsInput()
            suppressingScroll = drop
        }
        if drop { suppressedCount += 1; return nil }

    default:
        if controllerOwnsInput() { suppressedCount += 1; return nil }
    }
    return Unmanaged.passUnretained(event)
}

guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                                  options: .defaultTap, eventsOfInterest: tapMask,
                                  callback: tapCallback, userInfo: nil) else {
    print("✗ Could not create event tap (permission?)"); exit(1)
}
eventTap = tap
CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, tap, 0), .commonModes)
CGEvent.tapEnable(tap: tap, enable: true)

// MARK: - Global hotkeys (Carbon RegisterEventHotKey — no permission needed, works under secure input)

let app = NSApplication.shared
app.setActivationPolicy(.accessory) // no Dock icon; needed so Carbon hotkey events get dispatched

let hotkeySig: OSType = 0x5450_4558 // 'TPEX'
var hotkeySpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
    var id = EventHotKeyID()
    GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
                      nil, MemoryLayout<EventHotKeyID>.size, nil, &id)
    setEnabled(id.id == 1, via: "hotkey")
    return noErr
}, 1, &hotkeySpec, nil, nil)

let carbonMods = UInt32(controlKey | optionKey | cmdKey)
for (id, key, label) in [(UInt32(1), UInt32(kVK_ANSI_E), "⌃⌥⌘E"), (UInt32(2), UInt32(kVK_ANSI_D), "⌃⌥⌘D")] {
    var ref: EventHotKeyRef?
    let st = RegisterEventHotKey(key, carbonMods, EventHotKeyID(signature: hotkeySig, id: id),
                                 GetApplicationEventTarget(), 0, &ref)
    print(st == noErr ? "✓ Hotkey \(label) registered"
                      : "✗ Hotkey \(label) registration failed (\(st))\(st == eventHotKeyExistsErr ? " — already taken by another app" : "")")
}

// Diagnostics: report secure input changes (it blocks event taps from seeing keys).
nonisolated(unsafe) var lastSecure = false
Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    let s = IsSecureEventInputEnabled()
    if s != lastSecure { lastSecure = s; print("ⓘ Secure keyboard input is now \(s ? "ON" : "off")") }
}

print("✓ Shortcuts: ⌃⌥⌘E = enable, ⌃⌥⌘D = disable" + (suppress ? "" : "  (cursor suppression off)"))
print("✓ Running. Ctrl-C to quit.\n")
if startEnabled { setEnabled(true, via: "startup") } else { print("○ DISABLED — trackpad works normally") }

signal(SIGINT) { _ in
    print("\nframes: \(frameCount), CC messages sent: \(ccSentCount), events suppressed: \(suppressedCount)")
    exit(0)
}

app.run()
