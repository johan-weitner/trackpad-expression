import AppKit
import Observation
import SwiftUI

@Observable
final class OverlayModel {
    var values = [Double](repeating: 64, count: EngineConfig.maxStrips)
    var active: Set<Int> = []
    var stripCount = 4
    var ccNumbers = [1, 11, 21, 2]
}

/// Click-through, always-on-top panel showing one bar per strip. Purely visual feedback.
final class OverlayController {
    let model = OverlayModel()
    private let panel: NSPanel
    private let hosting: NSHostingView<OverlayView>
    private var visible = false

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                        backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hosting = NSHostingView(rootView: OverlayView(model: model))
        panel.contentView = hosting
    }

    func update(values: [Double], active: Set<Int>) {
        model.values = values
        model.active = active
    }

    func configure(stripCount: Int, ccNumbers: [Int], opacity: Double, corner: OverlayCorner) {
        model.stripCount = stripCount
        model.ccNumbers = ccNumbers
        hosting.layout()
        let size = hosting.fittingSize
        let screen = (NSScreen.main ?? NSScreen.screens.first)?.visibleFrame ?? .zero
        let m: CGFloat = 20
        let x = (corner == .topLeft || corner == .bottomLeft) ? screen.minX + m : screen.maxX - size.width - m
        let y = (corner == .bottomLeft || corner == .bottomRight) ? screen.minY + m : screen.maxY - size.height - m
        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        targetOpacity = opacity
        if visible { panel.alphaValue = opacity }
    }
    private var targetOpacity = 0.85

    func show() {
        visible = true
        if !panel.isVisible { panel.alphaValue = 0 }
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.15
            panel.animator().alphaValue = targetOpacity
        }
    }

    func hide() {
        visible = false
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, !self.visible else { return }
            self.panel.orderOut(nil)
        })
    }
}

struct OverlayView: View {
    let model: OverlayModel

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<model.stripCount, id: \.self) { i in
                StripBar(value: model.values[i], cc: model.ccNumbers[i], active: model.active.contains(i))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color.black.opacity(0.72)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color.white.opacity(0.12)))
        .foregroundStyle(.white)
        .fixedSize()
    }
}

private struct StripBar: View {
    let value: Double
    let cc: Int
    let active: Bool

    var body: some View {
        VStack(spacing: 6) {
            Text("\(Int(value.rounded()))")
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .frame(width: 34)
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white.opacity(0.12))
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(active ? Color.accentColor : Color.white.opacity(0.8))
                    .frame(height: max(4, 160 * value / 127))
            }
            .frame(width: 28, height: 160)
            Text("CC\(cc)")
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.75))
        }
    }
}
