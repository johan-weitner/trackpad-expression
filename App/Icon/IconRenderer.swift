// Renders app-icon concepts with CoreGraphics.
// Usage: swift App/Icon/IconRenderer.swift <concept a|b|c|sheet> <out.png> [size]
import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

func gradient(_ ctx: CGContext, _ colors: [CGColor], from: CGPoint, to: CGPoint) {
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.sRGB), colors: colors as CFArray, locations: nil)!
    ctx.drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

func rounded(_ r: CGRect, _ radius: CGFloat) -> CGPath {
    CGPath(roundedRect: r, cornerWidth: radius, cornerHeight: radius, transform: nil)
}

/// macOS icon grid on a 1024 canvas: 824×824 body, ~185 corner radius, soft drop shadow.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = rounded(body, 185)

func drawBody(_ ctx: CGContext, _ top: CGColor, _ bottom: CGColor) {
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: rgb(0x000000, 0.35))
    ctx.addPath(bodyPath); ctx.setFillColor(bottom); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(bodyPath); ctx.clip()
    gradient(ctx, [top, bottom], from: CGPoint(x: 512, y: 924), to: CGPoint(x: 512, y: 100))
    ctx.restoreGState()
}

// A — "Faders": the overlay itself. Three amber fader bars on a dark trackpad slab.
func conceptA(_ ctx: CGContext) {
    drawBody(ctx, rgb(0x2B2F4A), rgb(0x12131F))
    ctx.saveGState(); ctx.addPath(bodyPath); ctx.clip()
    // trackpad slab
    let pad = CGRect(x: 192, y: 232, width: 640, height: 560)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 20, color: rgb(0x000000, 0.5))
    ctx.addPath(rounded(pad, 56)); ctx.setFillColor(rgb(0x3A3F5C)); ctx.fillPath()
    ctx.restoreGState()
    ctx.addPath(rounded(pad, 56)); ctx.clip()
    gradient(ctx, [rgb(0x474D6E), rgb(0x30344C)], from: CGPoint(x: 512, y: pad.maxY), to: CGPoint(x: 512, y: pad.minY))
    ctx.resetClip(); ctx.addPath(bodyPath); ctx.clip()
    ctx.addPath(rounded(pad.insetBy(dx: 1.5, dy: 1.5), 55)); ctx.setStrokeColor(rgb(0xFFFFFF, 0.14)); ctx.setLineWidth(3); ctx.strokePath()
    // faders
    let levels: [CGFloat] = [0.45, 0.82, 0.6]
    let w: CGFloat = 96, gap: CGFloat = 64
    let x0 = 512 - (3 * w + 2 * gap) / 2
    let trackY: CGFloat = 300, trackH: CGFloat = 424
    for (i, lv) in levels.enumerated() {
        let x = x0 + CGFloat(i) * (w + gap)
        let track = CGRect(x: x, y: trackY, width: w, height: trackH)
        ctx.addPath(rounded(track, 26)); ctx.setFillColor(rgb(0x000000, 0.28)); ctx.fillPath()
        let fill = CGRect(x: x, y: trackY, width: w, height: trackH * lv)
        ctx.saveGState()
        ctx.addPath(rounded(fill, 26)); ctx.clip()
        gradient(ctx, [rgb(0xFFD27A), rgb(0xFF7A45)], from: CGPoint(x: x, y: fill.maxY), to: CGPoint(x: x, y: trackY))
        ctx.restoreGState()
        // glow at top of the active fader
        if i == 1 {
            ctx.saveGState()
            ctx.setShadow(offset: .zero, blur: 40, color: rgb(0xFFB35C, 0.9))
            ctx.addPath(rounded(CGRect(x: x, y: fill.maxY - 20, width: w, height: 20), 10)); ctx.setFillColor(rgb(0xFFE3A8)); ctx.fillPath()
            ctx.restoreGState()
        }
    }
    ctx.restoreGState()
}

// B — "Hairpin": the musical crescendo mark, turned upright, rising from a fingertip.
func conceptB(_ ctx: CGContext) {
    drawBody(ctx, rgb(0xFBF6EC), rgb(0xEDE3D0))
    ctx.saveGState(); ctx.addPath(bodyPath); ctx.clip()
    // faint staff lines
    ctx.setStrokeColor(rgb(0x8A7A5E, 0.13)); ctx.setLineWidth(5)
    for i in 0..<5 { let y = 360 + CGFloat(i) * 76; ctx.move(to: CGPoint(x: 100, y: y)); ctx.addLine(to: CGPoint(x: 924, y: y)) }
    ctx.strokePath()
    // hairpin
    let tip = CGPoint(x: 512, y: 250)
    ctx.setStrokeColor(rgb(0x1E1B2E)); ctx.setLineWidth(42); ctx.setLineCap(.round); ctx.setLineJoin(.round)
    ctx.move(to: CGPoint(x: 330, y: 790)); ctx.addLine(to: tip); ctx.addLine(to: CGPoint(x: 694, y: 790))
    ctx.strokePath()
    // fingertip
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 46, color: rgb(0xE8553A, 0.75))
    ctx.addEllipse(in: CGRect(x: tip.x - 62, y: tip.y - 62, width: 124, height: 124)); ctx.setFillColor(rgb(0xE8553A)); ctx.fillPath()
    ctx.restoreGState()
    ctx.addEllipse(in: CGRect(x: tip.x - 26, y: tip.y - 4, width: 52, height: 52)); ctx.setFillColor(rgb(0xFFFFFF, 0.35)); ctx.fillPath()
    ctx.restoreGState()
}

// C — "Swipe": a fingertip leaving an upward trail on a silver trackpad.
func conceptC(_ ctx: CGContext) {
    drawBody(ctx, rgb(0x3FB8C9), rgb(0x2A5CC4))
    ctx.saveGState(); ctx.addPath(bodyPath); ctx.clip()
    let pad = CGRect(x: 212, y: 212, width: 600, height: 600)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 34, color: rgb(0x0A1A4A, 0.45))
    ctx.addPath(rounded(pad, 70)); ctx.setFillColor(rgb(0xE9EDF2)); ctx.fillPath()
    ctx.restoreGState()
    ctx.saveGState(); ctx.addPath(rounded(pad, 70)); ctx.clip()
    gradient(ctx, [rgb(0xFAFBFD), rgb(0xD5DBE3)], from: CGPoint(x: 512, y: pad.maxY), to: CGPoint(x: 512, y: pad.minY))
    ctx.restoreGState()
    // trail
    let trail = CGRect(x: 462, y: 330, width: 100, height: 380)
    ctx.saveGState(); ctx.addPath(rounded(trail, 50)); ctx.clip()
    gradient(ctx, [rgb(0x2A6BE0, 0.0), rgb(0x2A6BE0, 0.55)], from: CGPoint(x: 512, y: 330), to: CGPoint(x: 512, y: 710))
    ctx.restoreGState()
    // fingertip
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 22, color: rgb(0x0A1A4A, 0.4))
    ctx.addEllipse(in: CGRect(x: 452, y: 610, width: 120, height: 120)); ctx.setFillColor(rgb(0x2A6BE0)); ctx.fillPath()
    ctx.restoreGState()
    // tick marks (fader scale)
    ctx.setStrokeColor(rgb(0x5A6A80, 0.45)); ctx.setLineWidth(8); ctx.setLineCap(.round)
    for i in 0..<6 {
        let y = 330 + CGFloat(i) * 76
        ctx.move(to: CGPoint(x: 612, y: y)); ctx.addLine(to: CGPoint(x: i % 5 == 0 ? 680 : 656, y: y))
    }
    ctx.strokePath()
    ctx.restoreGState()
}

func render(size: Int, _ draw: (CGContext) -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    draw(ctx)
    return ctx.makeImage()!
}

func save(_ img: CGImage, _ path: String) {
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, img, nil)
    CGImageDestinationFinalize(dest)
}

let args = CommandLine.arguments
let concepts: [String: (CGContext) -> Void] = ["a": conceptA, "b": conceptB, "c": conceptC]
let which = args.count > 1 ? args[1] : "sheet"
let out = args.count > 2 ? args[2] : "icon.png"
let size = args.count > 3 ? Int(args[3])! : 1024

if which == "sheet" {
    // Contact sheet: each concept large + small (menu/Finder size) on light and dark backgrounds.
    let w = 1800, h = 1300
    let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(rgb(0xECECEC)); ctx.fill(CGRect(x: 0, y: 650, width: w, height: 650))
    ctx.setFillColor(rgb(0x1E1E1E)); ctx.fill(CGRect(x: 0, y: 0, width: w, height: 650))
    for (i, key) in ["a", "b", "c"].enumerated() {
        let big = render(size: 512, concepts[key]!)
        let small = render(size: 64, concepts[key]!)
        let x = CGFloat(60 + i * 590)
        ctx.draw(big, in: CGRect(x: x, y: 720, width: 512, height: 512))
        ctx.draw(big, in: CGRect(x: x + 40, y: 130, width: 256, height: 256))
        ctx.draw(small, in: CGRect(x: x + 340, y: 226, width: 64, height: 64))
        ctx.draw(small, in: CGRect(x: x + 430, y: 242, width: 32, height: 32))
        let label = NSAttributedString(string: ["A — Faders", "B — Hairpin", "C — Swipe"][i],
                                       attributes: [.font: NSFont.systemFont(ofSize: 40, weight: .semibold),
                                                    .foregroundColor: NSColor.white])
        NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)
        label.draw(at: CGPoint(x: x + 40, y: 470))
    }
    save(ctx.makeImage()!, out)
} else {
    save(render(size: size, concepts[which]!), out)
}
