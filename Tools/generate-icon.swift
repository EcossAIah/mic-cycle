#!/usr/bin/env swift
import AppKit

// Run from the project root: swift Tools/generate-icon.swift
// All artwork is original vector geometry, rendered with macOS built-ins.
let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = root.appendingPathComponent("Assets")
try FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: r, green: g, blue: b, alpha: a)
}
func stroke(_ path: NSBezierPath, _ width: CGFloat, _ ink: NSColor) {
    path.lineWidth = width
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    ink.setStroke()
    path.stroke()
}

func render(_ pixels: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)

    let tile = NSBezierPath(roundedRect: NSRect(x: 80, y: 80, width: 864, height: 864),
                            xRadius: 194, yRadius: 194)
    NSGraphicsContext.saveGraphicsState()
    let shadow = NSShadow()
    shadow.shadowColor = color(0.01, 0.12, 0.20, 0.28)
    shadow.shadowBlurRadius = 22
    shadow.shadowOffset = NSSize(width: 0, height: -12)
    shadow.set()
    color(0.02, 0.41, 0.66).setFill()
    tile.fill()
    NSGraphicsContext.restoreGraphicsState()
    NSGradient(colors: [color(0.02, 0.35, 0.65), color(0.01, 0.64, 0.68)])!
        .draw(in: tile, angle: 65)
    NSGraphicsContext.saveGraphicsState()
    tile.addClip()
    let glow = NSBezierPath(ovalIn: NSRect(x: -60, y: 590, width: 1100, height: 600))
    color(0.54, 1, 0.96, 0.07).setFill()
    glow.fill()
    NSGraphicsContext.restoreGraphicsState()
    stroke(NSBezierPath(roundedRect: NSRect(x: 82, y: 82, width: 860, height: 860),
                        xRadius: 192, yRadius: 192), 3, color(1, 1, 1, 0.20))

    // Microphone, with broad shapes that remain legible at Finder's small sizes.
    NSGraphicsContext.saveGraphicsState()
    let micShadow = NSShadow()
    micShadow.shadowColor = color(0, 0.15, 0.27, 0.18)
    micShadow.shadowBlurRadius = 12
    micShadow.shadowOffset = NSSize(width: 0, height: -8)
    micShadow.set()
    let capsule = NSBezierPath(roundedRect: NSRect(x: 380, y: 450, width: 196, height: 320),
                              xRadius: 98, yRadius: 98)
    NSColor.white.setFill()
    capsule.fill()
    let cradle = NSBezierPath()
    cradle.move(to: NSPoint(x: 306, y: 565))
    cradle.line(to: NSPoint(x: 306, y: 479))
    cradle.curve(to: NSPoint(x: 650, y: 479), controlPoint1: NSPoint(x: 306, y: 250),
                 controlPoint2: NSPoint(x: 650, y: 250))
    cradle.line(to: NSPoint(x: 650, y: 565))
    stroke(cradle, 43, .white)
    let stand = NSBezierPath()
    stand.move(to: NSPoint(x: 478, y: 308))
    stand.line(to: NSPoint(x: 478, y: 242))
    stand.move(to: NSPoint(x: 398, y: 242))
    stand.line(to: NSPoint(x: 558, y: 242))
    stroke(stand, 43, .white)
    NSGraphicsContext.restoreGraphicsState()

    // A compact cycle mark, offset from the microphone silhouette.
    let badge = NSBezierPath(ovalIn: NSRect(x: 618, y: 190, width: 224, height: 224))
    color(0.01, 0.29, 0.41).setFill()
    badge.fill()
    stroke(badge, 3, color(0.63, 1, 0.94, 0.20))
    let mint = color(0.69, 1, 0.93)
    let top = NSBezierPath()
    top.move(to: NSPoint(x: 675, y: 315))
    top.curve(to: NSPoint(x: 786, y: 325), controlPoint1: NSPoint(x: 681, y: 376),
              controlPoint2: NSPoint(x: 762, y: 386))
    stroke(top, 17, mint)
    let topArrow = NSBezierPath()
    topArrow.move(to: NSPoint(x: 757, y: 334))
    topArrow.line(to: NSPoint(x: 787, y: 321))
    topArrow.line(to: NSPoint(x: 797, y: 352))
    stroke(topArrow, 17, mint)
    let bottom = NSBezierPath()
    bottom.move(to: NSPoint(x: 785, y: 287))
    bottom.curve(to: NSPoint(x: 674, y: 277), controlPoint1: NSPoint(x: 779, y: 226),
                 controlPoint2: NSPoint(x: 698, y: 216))
    stroke(bottom, 17, mint)
    let bottomArrow = NSBezierPath()
    bottomArrow.move(to: NSPoint(x: 703, y: 268))
    bottomArrow.line(to: NSPoint(x: 673, y: 281))
    bottomArrow.line(to: NSPoint(x: 663, y: 250))
    stroke(bottomArrow, 17, mint)

    context.flushGraphics()
    NSGraphicsContext.restoreGraphicsState()
    return stripMetadata(bitmap.representation(using: .png, properties: [:])!)
}

// AppKit adds an eXIf chunk to every PNG it writes. Keep only the chunks needed
// to decode the image so the assets carry no metadata.
func stripMetadata(_ png: Data) -> Data {
    let bytes = [UInt8](png)
    let keep: Set<String> = ["IHDR", "PLTE", "tRNS", "sRGB", "gAMA", "cHRM", "IDAT", "IEND"]
    var output = Data(bytes[0..<8])
    var offset = 8
    while offset + 12 <= bytes.count {
        let length = bytes[offset..<offset + 4].reduce(0) { $0 << 8 | Int($1) }
        let end = offset + 12 + length
        let type = String(decoding: bytes[offset + 4..<offset + 8], as: UTF8.self)
        if keep.contains(type) { output.append(contentsOf: bytes[offset..<end]) }
        offset = end
    }
    return output
}

// ICNS stores PNG representations inside a simple length-prefixed container.
// Write it directly so regeneration also works without iconutil's UI services.
func bigEndian(_ value: Int) -> Data {
    var bytes = UInt32(value).bigEndian
    return withUnsafeBytes(of: &bytes) { Data($0) }
}
var chunks = Data()
let representations: [(String, Int)] = [
    ("icp4", 16), ("icp5", 32), ("icp6", 64), ("ic07", 128),
    ("ic08", 256), ("ic09", 512), ("ic10", 1024),
    ("ic11", 32), ("ic12", 64), ("ic13", 256), ("ic14", 512)
]
for (type, size) in representations {
    let png = try render(size)
    chunks.append(Data(type.utf8))
    chunks.append(bigEndian(png.count + 8))
    chunks.append(png)
}
var icns = Data("icns".utf8)
icns.append(bigEndian(chunks.count + 8))
icns.append(chunks)
try icns.write(to: assets.appendingPathComponent("AppIcon.icns"))
try render(256).write(to: assets.appendingPathComponent("AppIcon.png"))
print("Generated Assets/AppIcon.png and Assets/AppIcon.icns")
