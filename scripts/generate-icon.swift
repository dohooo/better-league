import AppKit

let directory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        let transform = AffineTransform(scale: CGFloat(pixels) / 1024)
        (transform as NSAffineTransform).concat()
        let background = NSBezierPath(roundedRect: NSRect(x: 72, y: 72, width: 880, height: 880), xRadius: 200, yRadius: 200)
        NSColor(calibratedRed: 0.17, green: 0.36, blue: 0.29, alpha: 1).setFill()
        background.fill()
        let cursor = NSBezierPath()
        cursor.move(to: NSPoint(x: 328, y: 770))
        cursor.line(to: NSPoint(x: 328, y: 290))
        cursor.line(to: NSPoint(x: 447, y: 405))
        cursor.line(to: NSPoint(x: 550, y: 215))
        cursor.line(to: NSPoint(x: 648, y: 269))
        cursor.line(to: NSPoint(x: 545, y: 451))
        cursor.line(to: NSPoint(x: 715, y: 474))
        cursor.close()
        NSColor(calibratedRed: 0.95, green: 0.96, blue: 0.89, alpha: 1).setFill()
        cursor.fill()
        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        try bitmap.representation(using: .png, properties: [:])!
            .write(to: directory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
