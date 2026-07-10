import SwiftUI
import AppKit

// Componentes compartidos del branding de Dicta.

/// Patrón de puntos tipo halftone, animado: una onda lenta de brillo que
/// emana del centro (donde vive el logo) con un titileo orgánico por punto.
struct DotPatternView: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, size in
                let spacing: CGFloat = 14
                let dotRadius: CGFloat = 1.1
                let center = CGPoint(x: size.width / 2, y: size.height * 0.48)

                let columns = Int(size.width / spacing) + 1
                let rows = Int(size.height / spacing) + 1
                for row in 0...rows {
                    for column in 0...columns {
                        let x = CGFloat(column) * spacing + spacing / 2
                        let y = CGFloat(row) * spacing + spacing / 2

                        // El brillo cae solo hacia los costados: las filas de
                        // arriba llegan nítidas al borde superior de la ventana
                        // (el degradado inferior lo pone la máscara del header).
                        let dxNorm = abs(x - center.x) / (size.width * 0.62)
                        let falloff = max(0, 1 - dxNorm * dxNorm)

                        // titileo determinista por punto + onda radial lenta
                        let distance = hypot(x - center.x, y - center.y)
                        let seed = Double(column) * 12.9898 + Double(row) * 78.233
                        let phase = (sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1)
                        let wave = sin(time * 1.6 - Double(distance) * 0.045 + phase * .pi * 2)
                        let twinkle = 0.55 + 0.45 * wave

                        let opacity = Double(falloff * sqrt(falloff)) * twinkle * 0.5 + 0.03
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
    var size: CGFloat = 72

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

/// Cabecera compartida: puntos animados + tile del logo + título mono.
struct BrandHeader: View {
    let title: String

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                DotPatternView()
                    .frame(height: 168)
                    .mask(
                        LinearGradient(colors: [.black, .black, .clear],
                                       startPoint: .top, endPoint: .bottom)
                    )
                LogoTileView()
                    .offset(y: 14)
            }
            Text(title)
                .font(Theme.mono(24, .medium))
                .tracking(7)
                .foregroundStyle(Theme.primary)
        }
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
            Text(currentLabel)
                .font(Theme.mono(12, .medium))
                .tracking(1.5)
                .foregroundStyle(Theme.primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        // El borde va sobre el Menu (no sobre el label): Menu re-envuelve su
        // label y descarta los fondos que éste traiga.
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

    var body: some View {
        ZStack {
            Circle()
                .fill(granted ? Theme.accent : Color.white.opacity(0.04))
                .overlay(Circle().strokeBorder(granted ? .clear : Color.white.opacity(0.16), lineWidth: 1.2))
                .frame(width: 34, height: 34)
            Image(systemName: "checkmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(granted ? Color.black : Theme.tertiary)
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: granted)
    }
}

/// Botón principal: blanco cuando está habilitado.
struct PrimaryButton: View {
    let label: String
    let enabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(Theme.mono(13, .semibold))
                .tracking(2.5)
                .foregroundStyle(enabled ? Color.black : Theme.tertiary)
                .padding(.horizontal, 30)
                .frame(height: 54)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(enabled ? Color.white : Color.white.opacity(0.06))
                )
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .animation(.easeInOut(duration: 0.2), value: enabled)
    }
}

struct BrandFooter: View {
    let text: String

    var body: some View {
        Text(text)
            .font(Theme.sans(11))
            .foregroundStyle(Theme.tertiary)
            .frame(maxWidth: .infinity)
    }
}

enum BrandWindow {
    static let backgroundColor = NSColor(srgbRed: 0.102, green: 0.102, blue: 0.110, alpha: 1)
}
