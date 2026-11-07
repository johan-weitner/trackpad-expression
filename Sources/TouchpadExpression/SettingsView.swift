import SwiftUI

struct SettingsView: View {
    @Bindable var settings: Settings
    let devices: [DeviceInfo]

    var body: some View {
        Form {
            Section("Input") {
                Picker("Trackpad", selection: $settings.deviceID) {
                    Text("Automatic (prefer external)").tag("")
                    ForEach(devices) { Text($0.label).tag($0.hexID) }
                }
                Picker("Mode", selection: $settings.mode) {
                    Text("Relative").tag(FaderMode.relative)
                    Text("Absolute").tag(FaderMode.absolute)
                }
                .pickerStyle(.segmented)
                Text(settings.mode == .relative
                     ? "Swipes nudge the value up or down from where it is."
                     : "Finger height sets the value directly.")
                    .font(.caption).foregroundStyle(.secondary)
                if settings.mode == .relative {
                    LabeledContent("Sensitivity") {
                        HStack {
                            Slider(value: $settings.sensitivity, in: 0.25...3)
                            Text(String(format: "%.2f×", settings.sensitivity))
                                .monospacedDigit().frame(width: 48, alignment: .trailing)
                        }
                    }
                }
                LabeledContent("Smoothing") {
                    HStack {
                        Slider(value: $settings.smoothing, in: 0...0.9)
                        Text("\(Int(settings.smoothing * 100))%")
                            .monospacedDigit().frame(width: 48, alignment: .trailing)
                    }
                }
            }

            Section("MIDI") {
                Picker("Channel", selection: $settings.channel) {
                    ForEach(1...16, id: \.self) { Text("\($0)").tag($0) }
                }
                Stepper("Strips: \(settings.stripCount)", value: $settings.stripCount, in: 1...EngineConfig.maxStrips)
                ForEach(0..<min(settings.stripCount, settings.ccNumbers.count), id: \.self) { i in
                    LabeledContent("Strip \(i + 1)") {
                        HStack(spacing: 4) {
                            Text("CC")
                            TextField("", value: $settings.ccNumbers[i], format: .number)
                                .frame(width: 48)
                                .multilineTextAlignment(.trailing)
                            Stepper("", value: $settings.ccNumbers[i], in: 0...127).labelsHidden()
                        }
                    }
                }
                Text("Strips are laid out left to right across the trackpad.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Feedback") {
                Toggle("Show overlay while enabled", isOn: $settings.showOverlay)
                LabeledContent("Overlay opacity") {
                    HStack {
                        Slider(value: $settings.overlayOpacity, in: 0.2...1)
                        Text("\(Int(settings.overlayOpacity * 100))%")
                            .monospacedDigit().frame(width: 48, alignment: .trailing)
                    }
                }
                .disabled(!settings.showOverlay)
                Picker("Overlay position", selection: $settings.overlayCorner) {
                    ForEach(OverlayCorner.allCases, id: \.self) { Text($0.label).tag($0) }
                }
                .disabled(!settings.showOverlay)
                Toggle("Play sound when enabling / disabling", isOn: $settings.sounds)
            }

            Section("While enabled") {
                Toggle("Block clicks, taps and scrolling from the controller trackpad", isOn: $settings.blockInput)
                Text("The pointer still moves. Requires Accessibility permission.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Shortcuts") {
                LabeledContent("Enable", value: Hotkeys.enableLabel)
                LabeledContent("Disable", value: Hotkeys.disableLabel)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }
}
