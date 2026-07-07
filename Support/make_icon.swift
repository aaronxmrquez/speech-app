// Genera Support/AppIcon.icns: cuadrado redondeado negro con waveform blanco.
// Uso: swiftc -sdk <sdk> -o /tmp/make_icon Support/make_icon.swift && /tmp/make_icon <dir-proyecto>
import AppKit

let projectDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let iconsetURL = URL(fileURLWithPath: projectDir).appendingPathComponent("build/Dicta.iconset")
let icnsURL = URL(fileURLWithPath: projectDir).appendingPathComponent("Support/AppIcon.icns")

try? FileManager.default.removeItem(at: iconsetURL)
try! FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

func drawIcon(pixels: Int) -> NSBitmapImageRep {
    let s = CGFloat(pixels)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)

    // Silueta estándar de icono macOS: cuadrado redondeado con margen.
    let margin = s * 0.098
    let rect = NSRect(x: margin, y: margin, width: s - margin * 2, height: s - margin * 2)
    let radius = rect.width * 0.225
    NSColor(calibratedWhite: 0.04, alpha: 1).setFill()
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()

    // Borde interior sutil para que no se pierda sobre fondos oscuros.
    let strokeInset = max(0.5, s * 0.006)
    let strokeRect = rect.insetBy(dx: strokeInset / 2, dy: strokeInset / 2)
    let stroke = NSBezierPath(roundedRect: strokeRect,
                              xRadius: radius - strokeInset / 2,
                              yRadius: radius - strokeInset / 2)
    stroke.lineWidth = strokeInset
    NSColor(calibratedWhite: 1, alpha: 0.10).setStroke()
    stroke.stroke()

    // Waveform de 5 barras blancas.
    let heights: [CGFloat] = [0.16, 0.30, 0.44, 0.30, 0.16].map { $0 * s }
    let barWidth = s * 0.055
    let gap = s * 0.048
    let totalWidth = barWidth * 5 + gap * 4
    var x = (s - totalWidth) / 2
    NSColor.white.setFill()
    for height in heights {
        let bar = NSRect(x: x, y: (s - height) / 2, width: barWidth, height: height)
        NSBezierPath(roundedRect: bar, xRadius: barWidth / 2, yRadius: barWidth / 2).fill()
        x += barWidth + gap
    }

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let entries: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for entry in entries {
    let rep = drawIcon(pixels: entry.pixels)
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: iconsetURL.appendingPathComponent("\(entry.name).png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try! iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "✓ \(icnsURL.path)" : "✗ iconutil falló")
