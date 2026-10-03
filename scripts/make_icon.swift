// Renders the MiniNotch app icon at every macOS icon size and packs it into
// Resources/AppIcon.icns. Run from the repo root: `swift scripts/make_icon.swift`
import AppKit

/// Draws the icon into a square context of `size` points, using a 1024-unit design grid.
func drawIcon(in context: CGContext, size: CGFloat) {
    let s = size / 1024
    context.saveGState()
    // Top-left origin to match the design grid.
    context.translateBy(x: 0, y: size)
    context.scaleBy(x: s, y: -s)

    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
        CGColor(
            srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }

    // Body: Apple's macOS grid places an 824 pt rounded square inside the 1024 canvas.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Drop shadow under the body.
    context.saveGState()
    context.setShadow(offset: CGSize(width: 0, height: 12), blur: 28, color: color(0x000000, 0.35))
    context.addPath(bodyPath)
    context.setFillColor(color(0x1B1F4B))
    context.fillPath()
    context.restoreGState()

    context.saveGState()
    context.addPath(bodyPath)
    context.clip()

    // Background gradient.
    let background = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(0x5B6CFF), color(0x3A2F9E), color(0x16133A)] as CFArray,
        locations: [0, 0.55, 1]
    )!
    context.drawLinearGradient(
        background,
        start: CGPoint(x: 512, y: 100),
        end: CGPoint(x: 512, y: 924),
        options: []
    )

    // Menu bar strip.
    context.setFillColor(color(0xFFFFFF, 0.14))
    context.fill(CGRect(x: 100, y: 100, width: 824, height: 96))

    // Soft glow beneath the notch.
    let glow = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(0x9FB0FF, 0.45), color(0x9FB0FF, 0)] as CFArray,
        locations: [0, 1]
    )!
    context.drawRadialGradient(
        glow,
        startCenter: CGPoint(x: 512, y: 250), startRadius: 0,
        endCenter: CGPoint(x: 512, y: 250), endRadius: 330,
        options: []
    )

    // Subtle top highlight for depth, drawn below the notch so it stays pure black.
    let highlight = CGGradient(
        colorsSpace: colorSpace,
        colors: [color(0xFFFFFF, 0.10), color(0xFFFFFF, 0)] as CFArray,
        locations: [0, 1]
    )!
    context.drawLinearGradient(
        highlight,
        start: CGPoint(x: 512, y: 100),
        end: CGPoint(x: 512, y: 520),
        options: []
    )

    // Notch with concave ears, flush with the top edge.
    let notchWidth: CGFloat = 470
    let notchHeight: CGFloat = 170
    let ear: CGFloat = 34
    let corner: CGFloat = 70
    let left = 512 - notchWidth / 2
    let right = 512 + notchWidth / 2
    let top: CGFloat = 100
    let bottom = top + notchHeight

    let notch = CGMutablePath()
    notch.move(to: CGPoint(x: left - ear, y: top))
    notch.addQuadCurve(to: CGPoint(x: left, y: top + ear), control: CGPoint(x: left, y: top))
    notch.addLine(to: CGPoint(x: left, y: bottom - corner))
    notch.addQuadCurve(to: CGPoint(x: left + corner, y: bottom), control: CGPoint(x: left, y: bottom))
    notch.addLine(to: CGPoint(x: right - corner, y: bottom))
    notch.addQuadCurve(to: CGPoint(x: right, y: bottom - corner), control: CGPoint(x: right, y: bottom))
    notch.addLine(to: CGPoint(x: right, y: top + ear))
    notch.addQuadCurve(to: CGPoint(x: right + ear, y: top), control: CGPoint(x: right, y: top))
    notch.closeSubpath()

    context.addPath(notch)
    context.setFillColor(color(0x000000))
    context.fillPath()

    // Camera-in-use dot.
    let centerY = top + notchHeight / 2 + 6
    context.setFillColor(color(0x34C759))
    context.fillEllipse(in: CGRect(x: left + 62, y: centerY - 20, width: 40, height: 40))

    // Battery glyph.
    let battery = CGRect(x: right - 62 - 104, y: centerY - 26, width: 104, height: 52)
    context.addPath(CGPath(roundedRect: battery, cornerWidth: 14, cornerHeight: 14, transform: nil))
    context.setStrokeColor(color(0xFFFFFF, 0.9))
    context.setLineWidth(7)
    context.strokePath()
    let level = battery.insetBy(dx: 11, dy: 11)
    context.addPath(CGPath(
        roundedRect: CGRect(x: level.minX, y: level.minY, width: level.width * 0.75, height: level.height),
        cornerWidth: 6, cornerHeight: 6, transform: nil
    ))
    context.setFillColor(color(0x34C759))
    context.fillPath()
    context.addPath(CGPath(
        roundedRect: CGRect(x: battery.maxX + 6, y: centerY - 12, width: 10, height: 24),
        cornerWidth: 4, cornerHeight: 4, transform: nil
    ))
    context.setFillColor(color(0xFFFFFF, 0.9))
    context.fillPath()

    context.restoreGState()
    context.restoreGState()
}

func renderPNG(pixels: Int, to url: URL) throws {
    let context = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    context.interpolationQuality = .high
    drawIcon(in: context, size: CGFloat(pixels))
    let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
    try rep.representation(using: .png, properties: [:])!.write(to: url)
}

let fileManager = FileManager.default
let root = URL(fileURLWithPath: fileManager.currentDirectoryPath)
let iconset = fileManager.temporaryDirectory.appendingPathComponent("AppIcon.iconset")
try? fileManager.removeItem(at: iconset)
try fileManager.createDirectory(at: iconset, withIntermediateDirectories: true)

for points in [16, 32, 128, 256, 512] {
    try renderPNG(pixels: points, to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try renderPNG(pixels: points * 2, to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}

let resources = root.appendingPathComponent("Resources")
try fileManager.createDirectory(at: resources, withIntermediateDirectories: true)
// Full-size preview, handy for reviewing the design.
try renderPNG(pixels: 1024, to: resources.appendingPathComponent("AppIcon-1024.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", resources.appendingPathComponent("AppIcon.icns").path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else { fatalError("iconutil failed") }
print("Wrote Resources/AppIcon.icns")
