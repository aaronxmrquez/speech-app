// Genera los assets de icono de Dicta.
//
// - AppIcon.icns: si se pasa <arte-dock.png> (tile ya diseñado, p. ej. el
//   blanco con borde outline del branding), se usa tal cual centrado en la
//   retícula estándar de macOS. Si no, se monta el logo (procesado por
//   luminancia) sobre un cuadrado redondeado negro.
// - MenuBarIcon.png y LogoWhite.png: variantes blancas del logo para la app.
//
// Uso: swiftc -sdk <sdk> -o /tmp/make_icon Support/make_icon.swift
//      /tmp/make_icon <logo.png> <dir-proyecto> [arte-dock.png] [arte-menubar.png]
import AppKit

guard CommandLine.arguments.count > 2 else {
    print("uso: make_icon <logo.png> <dir-proyecto> [arte-dock.png] [arte-menubar.png]")
    exit(1)
}
let logoPath = CommandLine.arguments[1]
let projectDir = CommandLine.arguments[2]
let dockArtPath = CommandLine.arguments.count > 3 ? CommandLine.arguments[3] : nil
let menuBarArtPath = CommandLine.arguments.count > 4 ? CommandLine.arguments[4] : nil

guard let logoImage = NSImage(contentsOfFile: logoPath),
      let logoCG = logoImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    print("✗ No se pudo abrir el logo: \(logoPath)")
    exit(1)
}

/// Trazos oscuros → blanco opaco; zonas claras → transparente.
func whitened(_ source: CGImage) -> CGImage {
    let width = source.width
    let height = source.height
    let context = CGContext(data: nil, width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.draw(source, in: CGRect(x: 0, y: 0, width: width, height: height))
    let buffer = context.data!.bindMemory(to: UInt8.self, capacity: width * height * 4)
    for i in 0..<(width * height) {
        let p = i * 4
        let alpha = Float(buffer[p + 3]) / 255
        guard alpha > 0 else { continue }
        // des-premultiplicar para leer la luminancia real
        let r = Float(buffer[p]) / 255 / alpha
        let g = Float(buffer[p + 1]) / 255 / alpha
        let b = Float(buffer[p + 2]) / 255 / alpha
        let luminance = 0.2126 * r + 0.7152 * g + 0.0722 * b
        let newAlpha = alpha * max(0, min(1, (1 - luminance)))
        buffer[p] = UInt8(newAlpha * 255)     // blanco premultiplicado
        buffer[p + 1] = UInt8(newAlpha * 255)
        buffer[p + 2] = UInt8(newAlpha * 255)
        buffer[p + 3] = UInt8(newAlpha * 255)
    }
    return context.makeImage()!
}

let whiteLogo = whitened(logoCG)
let logoAspect = CGFloat(whiteLogo.width) / CGFloat(whiteLogo.height)

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

    // Logo blanco centrado, ocupando ~56 % del ancho del icono.
    let logoWidth = s * 0.56
    let logoHeight = logoWidth / logoAspect
    let logoRect = NSRect(x: (s - logoWidth) / 2,
                          y: (s - logoHeight) / 2,
                          width: logoWidth,
                          height: logoHeight)
    NSGraphicsContext.current?.cgContext.draw(whiteLogo, in: logoRect)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

let iconsetURL = URL(fileURLWithPath: projectDir).appendingPathComponent("build/Dicta.iconset")
let icnsURL = URL(fileURLWithPath: projectDir).appendingPathComponent("Support/AppIcon.icns")
let previewURL = URL(fileURLWithPath: projectDir).appendingPathComponent("build/icon-preview.png")

try? FileManager.default.removeItem(at: iconsetURL)
try! FileManager.default.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

// Arte de dock ya diseñado: usarlo tal cual, centrado en la retícula
// estándar de macOS (margen ~9.8 % por lado, como todos los íconos).
func drawFromArt(pixels: Int, art: CGImage) -> NSBitmapImageRep {
    let s = CGFloat(pixels)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let context = NSGraphicsContext.current!.cgContext
    context.interpolationQuality = .high
    let margin = s * 0.098
    context.draw(art, in: CGRect(x: margin, y: margin,
                                 width: s - margin * 2, height: s - margin * 2))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

var dockArt: CGImage?
if let dockArtPath {
    guard let artImage = NSImage(contentsOfFile: dockArtPath),
          let artCG = artImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("✗ No se pudo abrir el arte de dock: \(dockArtPath)")
        exit(1)
    }
    dockArt = artCG
}

let entries: [(name: String, pixels: Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]

for entry in entries {
    let rep = dockArt.map { drawFromArt(pixels: entry.pixels, art: $0) }
        ?? drawIcon(pixels: entry.pixels)
    let png = rep.representation(using: .png, properties: [:])!
    try! png.write(to: iconsetURL.appendingPathComponent("\(entry.name).png"))
}

// Vista previa a 512 para revisión rápida.
let previewRep = dockArt.map { drawFromArt(pixels: 512, art: $0) } ?? drawIcon(pixels: 512)
try! previewRep.representation(using: .png, properties: [:])!
    .write(to: previewURL)

// Variantes blancas-sobre-transparente del logo para usar dentro de la app:
// icono de barra de menús (36 px de ancho, @2x de ~18 pt) y logo del onboarding.
func writeWhiteLogo(width: Int, to url: URL) {
    let height = Int(CGFloat(width) / logoAspect)
    let context = CGContext(data: nil, width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    context.draw(whiteLogo, in: CGRect(x: 0, y: 0, width: width, height: height))
    let image = context.makeImage()!
    let rep = NSBitmapImageRep(cgImage: image)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

let supportURL = URL(fileURLWithPath: projectDir).appendingPathComponent("Support")
writeWhiteLogo(width: 256, to: supportURL.appendingPathComponent("LogoWhite.png"))

// Icono de barra de menús: arte propio si se pasó (procesado por luminancia
// para que funcione como template), o la silueta del logo como antes.
if let menuBarArtPath {
    guard let artImage = NSImage(contentsOfFile: menuBarArtPath),
          let artCG = artImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("✗ No se pudo abrir el arte de barra de menús: \(menuBarArtPath)")
        exit(1)
    }
    let processed = whitened(artCG)
    let width = 36
    let height = Int(CGFloat(width) * CGFloat(processed.height) / CGFloat(processed.width))
    let context = CGContext(data: nil, width: width, height: height,
                            bitsPerComponent: 8, bytesPerRow: width * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    context.interpolationQuality = .high
    context.draw(processed, in: CGRect(x: 0, y: 0, width: width, height: height))
    let rep = NSBitmapImageRep(cgImage: context.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!
        .write(to: supportURL.appendingPathComponent("MenuBarIcon.png"))
} else {
    writeWhiteLogo(width: 36, to: supportURL.appendingPathComponent("MenuBarIcon.png"))
}

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconsetURL.path, "-o", icnsURL.path]
try! iconutil.run()
iconutil.waitUntilExit()
print(iconutil.terminationStatus == 0 ? "✓ \(icnsURL.path)" : "✗ iconutil falló")
