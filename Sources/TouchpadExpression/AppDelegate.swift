import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let settings = Settings.shared
    private let engine = TouchEngine.shared
    private let overlay = OverlayController()

    private var statusItem: NSStatusItem!
    private var toggleItem: NSMenuItem!
    private var infoItem: NSMenuItem!
    private var warningItem: NSMenuItem!
    private var settingsWindow: NSWindow?
    private var enabled = false
    private var engineError: String?
    private var hotkeyErrors: [String] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildStatusItem()

        engine.onUpdate = { [weak self] values, active in
            self?.overlay.update(values: values, active: active)
        }
        do {
            try engine.start()
        } catch {
            engineError = error.localizedDescription
        }
        engine.apply(settings.engineConfig)
        configureOverlay()

        settings.onChange = { [weak self] in self?.settingsChanged() }
        hotkeyErrors = Hotkeys.register { [weak self] on in self?.setEnabled(on) }

        refreshUI()
    }

    // MARK: - Enable / disable

    private func setEnabled(_ on: Bool) {
        guard on != enabled, engineError == nil else { return }
        enabled = on
        engine.setEnabled(on)
        if settings.sounds { NSSound(named: on ? "Tink" : "Pop")?.play() }
        if on, settings.showOverlay { overlay.show() } else { overlay.hide() }
        updateBlocker()
        refreshUI()
    }

    private func updateBlocker() {
        if enabled && settings.blockInput {
            InputBlocker.shared.start()
        } else {
            InputBlocker.shared.stop()
        }
    }

    private func settingsChanged() {
        engine.apply(settings.engineConfig)
        configureOverlay()
        if enabled {
            if settings.showOverlay { overlay.show() } else { overlay.hide() }
        }
        updateBlocker()
        refreshUI()
    }

    private func configureOverlay() {
        let c = settings.engineConfig
        overlay.configure(stripCount: c.stripCount, ccNumbers: settings.clampedCCs,
                          opacity: settings.overlayOpacity, corner: settings.overlayCorner)
    }

    // MARK: - Menu bar

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "slider.vertical.3",
                                           accessibilityDescription: "Trackpad Expression")

        let menu = NSMenu()
        menu.delegate = self
        toggleItem = NSMenuItem(title: "Enable", action: #selector(toggleFromMenu), keyEquivalent: "")
        toggleItem.target = self
        menu.addItem(toggleItem)
        menu.addItem(.separator())
        infoItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        infoItem.isEnabled = false
        menu.addItem(infoItem)
        warningItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        warningItem.isEnabled = false
        menu.addItem(warningItem)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(NSMenuItem(title: "Quit Trackpad Expression", action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) { refreshUI() }

    private func refreshUI() {
        statusItem.button?.appearsDisabled = !enabled
        statusItem.button?.contentTintColor = enabled ? .controlAccentColor : nil

        toggleItem.title = enabled ? "Disable   \(Hotkeys.disableLabel)" : "Enable   \(Hotkeys.enableLabel)"
        toggleItem.isEnabled = engineError == nil

        if let engineError {
            infoItem.title = engineError
        } else {
            let device = engine.controllerInfo?.label ?? "No trackpad"
            let ccs = settings.clampedCCs.prefix(settings.engineConfig.stripCount).map { "CC\($0)" }
            infoItem.title = "\(device) · ch \(settings.channel) · \(ccs.joined(separator: " "))"
        }

        var warnings = hotkeyErrors
        if settings.blockInput && !InputBlocker.hasPermission(prompt: false) {
            warnings.append("Blocking needs Accessibility permission")
        }
        warningItem.title = warnings.map { "⚠︎ \($0)" }.joined(separator: "\n")
        warningItem.isHidden = warnings.isEmpty
    }

    @objc private func toggleFromMenu() { setEnabled(!enabled) }

    @objc private func openSettings() {
        if settingsWindow == nil {
            let controller = NSHostingController(rootView: SettingsView(settings: settings, devices: engine.devices))
            controller.sizingOptions = .preferredContentSize
            let window = NSWindow(contentViewController: controller)
            window.title = "Trackpad Expression"
            window.styleMask = [.titled, .closable]
            window.isReleasedWhenClosed = false
            window.center()
            settingsWindow = window
        }
        NSApp.activate()
        settingsWindow?.makeKeyAndOrderFront(nil)
    }
}
