import Foundation
import MTShim

struct DeviceInfo: Identifiable, Hashable {
    let id: UInt64
    let builtIn: Bool
    let widthMM: Double
    let heightMM: Double

    var hexID: String { String(id, radix: 16) }
    var label: String {
        builtIn ? "Built-in trackpad"
                : String(format: "External trackpad (%.0f × %.0f mm)", widthMM, heightMM)
    }
}

enum TouchEngineError: LocalizedError {
    case frameworkUnavailable(String)
    case noDevices

    var errorDescription: String? {
        switch self {
        case .frameworkUnavailable(let msg): "MultitouchSupport could not be loaded: \(msg)"
        case .noDevices: "No trackpads were found."
        }
    }
}

/// Turns raw trackpad touches into CC values. Touch frames arrive on a MultitouchSupport
/// thread; all mutable state is guarded by `lock`. UI updates are coalesced onto main.
final class TouchEngine: @unchecked Sendable {
    static let shared = TouchEngine()

    private struct Finger {
        var strip: Int   // -1 = ignored (strip already owned by another finger)
        var filtY: Double
    }

    private let lock = NSLock()
    private let midi = MIDIOut()

    private var config = EngineConfig()
    private var enabled = false
    private var deviceRefs: [(ref: MTDeviceRef, info: DeviceInfo)] = []
    private var controller: MTDeviceRef?
    private var fingers: [Int: Finger] = [:]
    private var values = [Double](repeating: 64, count: EngineConfig.maxStrips)
    private var lastSent = [Int](repeating: 64, count: EngineConfig.maxStrips)
    private var controllerFingers = 0
    private var otherFingers = 0
    private var controllerLastTouchNs: UInt64 = 0
    private var uiPending = false

    /// Called on the main thread with (values 0-127, strips currently touched).
    var onUpdate: (([Double], Set<Int>) -> Void)?

    private(set) var devices: [DeviceInfo] = []

    func start() throws {
        var err = [CChar](repeating: 0, count: 256)
        guard mt_load(&err, Int32(err.count)) else {
            throw TouchEngineError.frameworkUnavailable(String(cString: err))
        }
        guard let list = mt_device_list(), CFArrayGetCount(list) > 0 else { throw TouchEngineError.noDevices }
        for i in 0..<CFArrayGetCount(list) {
            let ref = UnsafeMutableRawPointer(mutating: CFArrayGetValueAtIndex(list, i)!)
            var w: Int32 = 0, h: Int32 = 0
            _ = mt_surface_size(ref, &w, &h)
            let info = DeviceInfo(id: mt_device_id(ref), builtIn: mt_is_builtin(ref),
                                  widthMM: Double(w) / 100, heightMM: Double(h) / 100)
            deviceRefs.append((ref, info))
        }
        devices = deviceRefs.map(\.info)
        resolveController()
        for d in deviceRefs {
            mt_register(d.ref, touchCallback)
            mt_start(d.ref)
        }
        // Keep the CFArray (and the device objects it owns) alive for the app's lifetime.
        retainedList = list
    }
    private var retainedList: CFArray?

    func apply(_ newConfig: EngineConfig) {
        lock.lock()
        config = newConfig
        resolveController()
        fingers.removeAll()
        lock.unlock()
        scheduleUI()
    }

    func setEnabled(_ on: Bool) {
        lock.lock()
        enabled = on
        fingers.removeAll()
        // Only send values that actually change from here on — never jump on enable.
        lastSent = values.map { Int($0.rounded()) }
        lock.unlock()
        scheduleUI()
    }

    var controllerInfo: DeviceInfo? {
        lock.lock(); defer { lock.unlock() }
        return deviceRefs.first { $0.ref == controller }?.info
    }

    /// True while only the controller trackpad is being touched (plus a short grace period).
    func controllerOwnsInput() -> Bool {
        lock.lock(); defer { lock.unlock() }
        let grace: UInt64 = 150_000_000
        return enabled && otherFingers == 0
            && (controllerFingers > 0 || DispatchTime.now().uptimeNanoseconds &- controllerLastTouchNs < grace)
    }

    // Caller holds the lock (or is in start()).
    private func resolveController() {
        if let id = config.deviceID, let match = deviceRefs.first(where: { $0.info.id == id }) {
            controller = match.ref
        } else {
            controller = (deviceRefs.first { !$0.info.builtIn } ?? deviceRefs.first)?.ref
        }
    }

    fileprivate func handle(device: MTDeviceRef?, touches: UnsafePointer<MTTouch>?, count: Int) {
        lock.lock()
        guard device == controller else {
            otherFingers = count
            lock.unlock()
            return
        }
        controllerFingers = count
        if count > 0 { controllerLastTouchNs = DispatchTime.now().uptimeNanoseconds }
        guard enabled else { lock.unlock(); return }

        let n = config.stripCount
        let follow = 1 - config.smoothing
        var changed = false
        var seen = Set<Int>()

        for i in 0..<count {
            guard let t = touches?[i] else { break }
            // 3 = make-touch, 4 = touching. Ignore hover / lift-off frames.
            guard t.state == 3 || t.state == 4 else { continue }
            let id = Int(t.identifier)
            let x = Double(t.normalized.position.x)
            let y = Double(t.normalized.position.y)
            seen.insert(id)

            if var f = fingers[id] {
                guard f.strip >= 0 else { continue }
                let prev = f.filtY
                f.filtY += (y - prev) * follow
                fingers[id] = f
                switch config.mode {
                case .relative:
                    values[f.strip] = clamp(values[f.strip] + (f.filtY - prev) * 127 * config.sensitivity)
                case .absolute:
                    values[f.strip] = absoluteValue(f.filtY)
                }
            } else {
                var strip = min(max(Int(x * Double(n)), 0), n - 1)
                if fingers.values.contains(where: { $0.strip == strip }) { strip = -1 }
                fingers[id] = Finger(strip: strip, filtY: y)
                if strip >= 0, config.mode == .absolute { values[strip] = absoluteValue(y) }
                changed = true
            }
        }
        if fingers.count != seen.count {
            fingers = fingers.filter { seen.contains($0.key) }
            changed = true
        }
        for s in 0..<n {
            let v = Int(values[s].rounded())
            if v != lastSent[s] {
                lastSent[s] = v
                midi.sendCC(channel: config.channel, cc: config.ccNumbers[s], value: UInt8(v))
                changed = true
            }
        }
        let needUI = changed && !uiPending
        if needUI { uiPending = true }
        lock.unlock()
        if needUI { DispatchQueue.main.async { self.flushUI() } }
    }

    private func scheduleUI() {
        lock.lock()
        let needUI = !uiPending
        uiPending = true
        lock.unlock()
        if needUI { DispatchQueue.main.async { self.flushUI() } }
    }

    private func flushUI() {
        lock.lock()
        uiPending = false
        let v = values
        let active = Set(fingers.values.map(\.strip).filter { $0 >= 0 })
        lock.unlock()
        onUpdate?(v, active)
    }

    private func clamp(_ v: Double) -> Double { min(max(v, 0), 127) }

    /// Maps finger height to 0-127 with a small margin so both ends are easy to reach.
    private func absoluteValue(_ y: Double) -> Double {
        let margin = 0.06
        return clamp((y - margin) / (1 - 2 * margin) * 127)
    }
}

private let touchCallback: MTContactCallback = { device, touches, count, _, _ in
    TouchEngine.shared.handle(device: device, touches: touches, count: Int(count))
    return 0
}
