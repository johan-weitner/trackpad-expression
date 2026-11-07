import Foundation
import Observation

enum FaderMode: String, CaseIterable {
    case relative, absolute
}

enum OverlayCorner: String, CaseIterable {
    case topLeft, topRight, bottomLeft, bottomRight

    var label: String {
        switch self {
        case .topLeft: "Top left"
        case .topRight: "Top right"
        case .bottomLeft: "Bottom left"
        case .bottomRight: "Bottom right"
        }
    }
}

/// Immutable snapshot handed to the touch engine (which runs off the main thread).
struct EngineConfig {
    static let maxStrips = 4

    var stripCount = 4
    var ccNumbers: [UInt8] = [1, 11, 21, 2]
    var channel: UInt8 = 0 // 0-based
    var mode: FaderMode = .relative
    var sensitivity = 1.0
    var smoothing = 0.3
    var deviceID: UInt64? = nil // nil = automatic (prefer external)
}

/// Global, persisted settings. Every change is saved and reported through `onChange`.
@Observable
final class Settings {
    static let shared = Settings()

    @ObservationIgnored var onChange: (() -> Void)?
    @ObservationIgnored private let defaults = UserDefaults.standard

    var stripCount: Int { didSet { save() } }
    var ccNumbers: [Int] { didSet { save() } }
    var channel: Int { didSet { save() } }           // 1-16
    var mode: FaderMode { didSet { save() } }
    var sensitivity: Double { didSet { save() } }
    var smoothing: Double { didSet { save() } }
    var deviceID: String { didSet { save() } }       // hex id, "" = automatic
    var showOverlay: Bool { didSet { save() } }
    var overlayOpacity: Double { didSet { save() } }
    var overlayCorner: OverlayCorner { didSet { save() } }
    var sounds: Bool { didSet { save() } }
    var blockInput: Bool { didSet { save() } }

    private init() {
        let d = UserDefaults.standard
        d.register(defaults: [
            "stripCount": 4,
            "ccNumbers": [1, 11, 21, 2],
            "channel": 1,
            "mode": FaderMode.relative.rawValue,
            "sensitivity": 1.0,
            "smoothing": 0.3,
            "deviceID": "",
            "showOverlay": true,
            "overlayOpacity": 0.85,
            "overlayCorner": OverlayCorner.bottomRight.rawValue,
            "sounds": true,
            "blockInput": false,
        ])
        stripCount = d.integer(forKey: "stripCount")
        var ccs = (d.array(forKey: "ccNumbers") as? [Int]) ?? [1, 11, 21, 2]
        while ccs.count < EngineConfig.maxStrips { ccs.append(1) }
        ccNumbers = Array(ccs.prefix(EngineConfig.maxStrips))
        channel = d.integer(forKey: "channel")
        mode = FaderMode(rawValue: d.string(forKey: "mode") ?? "") ?? .relative
        sensitivity = d.double(forKey: "sensitivity")
        smoothing = d.double(forKey: "smoothing")
        deviceID = d.string(forKey: "deviceID") ?? ""
        showOverlay = d.bool(forKey: "showOverlay")
        overlayOpacity = d.double(forKey: "overlayOpacity")
        overlayCorner = OverlayCorner(rawValue: d.string(forKey: "overlayCorner") ?? "") ?? .bottomRight
        sounds = d.bool(forKey: "sounds")
        blockInput = d.bool(forKey: "blockInput")
    }

    private func save() {
        defaults.set(stripCount, forKey: "stripCount")
        defaults.set(ccNumbers, forKey: "ccNumbers")
        defaults.set(channel, forKey: "channel")
        defaults.set(mode.rawValue, forKey: "mode")
        defaults.set(sensitivity, forKey: "sensitivity")
        defaults.set(smoothing, forKey: "smoothing")
        defaults.set(deviceID, forKey: "deviceID")
        defaults.set(showOverlay, forKey: "showOverlay")
        defaults.set(overlayOpacity, forKey: "overlayOpacity")
        defaults.set(overlayCorner.rawValue, forKey: "overlayCorner")
        defaults.set(sounds, forKey: "sounds")
        defaults.set(blockInput, forKey: "blockInput")
        onChange?()
    }

    /// CC numbers clamped to 0-127 (text fields may hold anything).
    var clampedCCs: [Int] { ccNumbers.map { min(max($0, 0), 127) } }

    var engineConfig: EngineConfig {
        EngineConfig(
            stripCount: min(max(stripCount, 1), EngineConfig.maxStrips),
            ccNumbers: clampedCCs.map { UInt8($0) },
            channel: UInt8(min(max(channel, 1), 16) - 1),
            mode: mode,
            sensitivity: sensitivity,
            smoothing: min(max(smoothing, 0), 0.95),
            deviceID: deviceID.isEmpty ? nil : UInt64(deviceID, radix: 16)
        )
    }
}
