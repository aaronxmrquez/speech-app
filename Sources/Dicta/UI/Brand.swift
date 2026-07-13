import SwiftUI
import AppKit

// Componentes compartidos del branding de Dicta.

/// Patrón de puntos tipo halftone, animado: halo elíptico alrededor del
/// centro (donde vive el logo del splash) con una onda lenta de brillo y
/// titileo orgánico por punto.
struct DotPatternView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let spacing: CGFloat = 14
                let dotRadius: CGFloat = 1.1
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radiusX = size.width * 0.46
                let radiusY = size.height * 0.52

                let columns = Int(size.width / spacing) + 1
                let rows = Int(size.height / spacing) + 1
                for row in 0...rows {
                    for column in 0...columns {
                        let x = CGFloat(column) * spacing + spacing / 2
                        let y = CGFloat(row) * spacing + spacing / 2

                        // Halo elíptico: brillo máximo cerca del logo, cae
                        // suave hacia el borde de la elipse.
                        let dx = (x - center.x) / radiusX
                        let dy = (y - center.y) / radiusY
                        let elliptic = dx * dx + dy * dy
                        let falloff = max(0, 1 - elliptic)

                        // titileo determinista por punto + onda radial lenta
                        let distance = hypot(x - center.x, y - center.y)
                        let seed = Double(column) * 12.9898 + Double(row) * 78.233
                        let phase = (sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1)
                        let wave = sin(time * 1.6 - Double(distance) * 0.045 + phase * .pi * 2)
                        let twinkle = 0.55 + 0.45 * wave

                        let opacity = Double(falloff * falloff) * twinkle * 0.55
                        guard opacity > 0.04 else { continue }

                        let rect = CGRect(x: x - dotRadius, y: y - dotRadius,
                                          width: dotRadius * 2, height: dotRadius * 2)
                        context.fill(Path(ellipseIn: rect), with: .color(.white.opacity(opacity)))
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Tile blanco redondeado con el logo (la cara) en negro, como en el branding.
struct LogoTileView: View {
    var size: CGFloat = 56

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .fill(Color.white)
                .frame(width: size, height: size)
                .shadow(color: .black.opacity(0.45), radius: size * 0.18, x: 0, y: size * 0.08)
            if let url = Bundle.main.url(forResource: "logo", withExtension: "png"),
               let logo = NSImage(contentsOf: url) {
                Image(nsImage: logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size * 0.58)
            }
        }
    }
}

/// Cabecera compartida: tile del logo + título dos-tonos "DICTA.SECCIÓN"
/// (la marca en gris, la sección donde estás en blanco puro).
struct BrandHeader: View {
    let section: String

    var body: some View {
        VStack(spacing: 20) {
            LogoTileView()
            (Text("DICTA.")
                .foregroundColor(Theme.secondary)
             + Text(section)
                .foregroundColor(Theme.primary))
                .font(Theme.mono(24, .medium))
                .tracking(1)
        }
    }
}

/// Nombre de la app + versión, esquina superior derecha de cada ventana.
struct VersionTag: View {
    var body: some View {
        Text("DICTA \(Self.version)")
            .font(Theme.mono(10, .medium))
            .tracking(1.5)
            .foregroundStyle(Theme.tertiary)
    }

    private static var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}

/// Chip de opción: seleccionado = contorno blanco; no seleccionado = texto tenue.
struct ChipButton: View {
    let label: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.mono(12, .medium))
                .tracking(1.5)
                .foregroundStyle(selected ? Theme.primary : Theme.tertiary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(selected ? Color.white.opacity(0.6) : .clear, lineWidth: 1.2)
                )
                .contentShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// Chip que abre un menú de opciones (para KEY y DICTATE IN).
struct MenuChip<Option: Hashable>: View {
    let options: [(value: Option, label: String)]
    @Binding var selection: Option

    var body: some View {
        Menu {
            ForEach(options, id: \.value) { option in
                Button(option.label) { selection = option.value }
            }
        } label: {
            HStack(spacing: 7) {
                Text(currentLabel)
                    .font(Theme.mono(12, .medium))
                    .tracking(1.5)
                    .foregroundStyle(Theme.primary)
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.tertiary)
            }
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        // Padding FUERA del Menu (si va en el label, Menu lo trunca) pero
        // dentro del borde: mismas métricas que ChipButton.
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.6), lineWidth: 1.2)
        )
    }

    private var currentLabel: String {
        options.first { $0.value == selection }?.label ?? ""
    }
}

/// Toggle custom de la marca: perilla verde cuando está activo.
struct BrandToggle: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) { isOn.toggle() }
        } label: {
            ZStack(alignment: isOn ? .trailing : .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))
                    .overlay(Capsule().strokeBorder(Theme.cardBorder, lineWidth: 1))
                    .frame(width: 46, height: 26)
                Circle()
                    .fill(isOn ? Theme.accent : Color.white.opacity(0.28))
                    .frame(width: 20, height: 20)
                    .padding(3)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Etiqueta de sección fuera de la card.
struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.mono(12, .medium))
            .tracking(2.5)
            .foregroundStyle(Theme.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Contenedor de card grande redondeada.
struct BrandCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) { content() }
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(Theme.cardBorder, lineWidth: 1)
            )
    }
}

struct BrandDivider: View {
    var body: some View {
        Rectangle()
            .fill(Theme.divider)
            .frame(height: 1)
            .padding(.horizontal, 20)
    }
}

/// Círculo de estado de permiso: verde al concederse.
struct StatusCircle: View {
    let granted: Bool
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            Circle()
                .fill(granted ? Theme.accent : Color.white.opacity(0.04))
                .overlay(Circle().strokeBorder(granted ? .clear : Color.white.opacity(0.16), lineWidth: 1.2))
                .frame(width: size, height: size)
            Image(systemName: "checkmark")
                .font(.system(size: size * 0.38, weight: .bold))
                .foregroundStyle(granted ? Color.black : Theme.tertiary)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: granted)
    }
}

/// Botón principal: blanco al habilitarse; deshabilitado = contorno tenue.
struct PrimaryButton: View {
    let label: String
    let enabled: Bool
    var fullWidth = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.mono(13, .semibold))
                .tracking(2.5)
                .foregroundStyle(enabled ? Color.black : Theme.tertiary)
                .padding(.horizontal, 30)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .frame(height: 48)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(enabled ? Color.white : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(enabled ? Color.clear : Color.white.opacity(0.14), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .animation(.easeInOut(duration: 0.2), value: enabled)
    }
}

/// Footer unificado: tagline + crédito. El nombre lleva subrayado y abre
/// aaronxmarquez.com — mismo color que el resto del texto, solo subrayado.
struct BrandFooter: View {
    var body: some View {
        VStack(spacing: 3) {
            Text("Just speak and the text will be written wherever your cursor is.")
            HStack(spacing: 4) {
                Text("An app created by")
                Text("Aaron Márquez")
                    .underline()
                    .onHover { hovering in
                        if hovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }
                    .onTapGesture {
                        if let url = URL(string: "https://www.aaronxmarquez.com/") {
                            NSWorkspace.shared.open(url)
                        }
                    }
            }
        }
        .font(Theme.sans(11))
        .foregroundStyle(Theme.tertiary)
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
    }
}

enum BrandWindow {
    static let backgroundColor = NSColor(srgbRed: 0.102, green: 0.102, blue: 0.110, alpha: 1)
    /// Alto único de todas las ventanas (referencia: la pantalla de permisos).
    static let height: CGFloat = 762

    /// Chrome de marca: solo el botón rojo de cerrar, como en el diseño.
    static func applyChrome(to window: NSWindow) {
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true
        window.standardWindowButton(.zoomButton)?.isHidden = true
    }
}

/// Esqueleto compartido de ventana: versión arriba a la derecha, header
/// (logo + título dos-tonos) y footer fijos; el contenido hace scroll si no cabe.
struct BrandScreen<Content: View>: View {
    let section: String
    var width: CGFloat = 560 // referencia: la ventana de permisos
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                BrandHeader(section: section)
                    .padding(.top, 56)
                    .padding(.bottom, 8)
                ScrollView(showsIndicators: false) {
                    content()
                }
                // Si el contenido cabe (como en permisos), no hay scroll;
                // si no cabe, el usuario puede scrollear.
                .scrollBounceBehavior(.basedOnSize, axes: .vertical)
                BrandFooter()
                    .padding(.top, 16)
                    .padding(.bottom, 16)
            }
            VersionTag()
                .padding(.top, 14)
                .padding(.trailing, 20)
        }
        .frame(width: width, height: BrandWindow.height)
        .background(Theme.background)
        .preferredColorScheme(.dark)
        // El titlebar mete un safe area de ~28pt que empuja todo hacia abajo:
        // el diseño es full-bleed, así que lo ignoramos y el tag de versión
        // queda a la altura real del botón de cerrar.
        .ignoresSafeArea()
    }
}
