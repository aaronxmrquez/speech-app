import SwiftUI
import AppKit

/// Splash de bienvenida: se muestra una sola vez, en la primera instalación,
/// antes de la pantalla de permisos.
@MainActor
final class SplashWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let onBegin: () -> Void

    init(onBegin: @escaping () -> Void) {
        self.onBegin = onBegin
    }

    func show() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: BrandWindow.height),
                             styleMask: [.titled, .closable, .fullSizeContentView],
                             backing: .buffered,
                             defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.backgroundColor = BrandWindow.backgroundColor
            w.appearance = NSAppearance(named: .darkAqua)
            w.isReleasedWhenClosed = false
            w.collectionBehavior = [.moveToActiveSpace]
            w.delegate = self
            BrandWindow.applyChrome(to: w)
            w.contentView = NSHostingView(rootView: SplashView { [weak self] in
                self?.onBegin()
            })
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
    }
}

struct SplashView: View {
    var onBegin: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                Spacer(minLength: 40)

                // Halo de puntos animado con el logo al centro.
                ZStack {
                    DotPatternView()
                        .frame(width: 423, height: 158)
                    LogoTileView()
                }

                // El statement vive aquí ahora (ya no en permisos).
                VStack(spacing: -6) {
                    Text("BECAUSE WE KNOW")
                        .foregroundStyle(Theme.tertiary)
                    Text("YOU HATE TYPING...")
                        .foregroundStyle(Theme.tertiary)
                    Text("USE DICTA.")
                        .foregroundStyle(Theme.primary)
                }
                .font(Theme.mono(30, .regular))
                .tracking(0.3)
                .multilineTextAlignment(.center)
                .padding(.top, 35)

                Text("Just speak and the text will be written\nwherever your cursor is.")
                    .font(Theme.sans(15))
                    .foregroundStyle(Theme.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.top, 20)

                PrimaryButton(label: "LET'S BEGIN", enabled: true, fullWidth: true, action: onBegin)
                    .frame(width: 348)
                    .padding(.top, 20)

                Spacer(minLength: 40)

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
                .font(Theme.sans(11.5))
                .foregroundStyle(Theme.tertiary)
                .padding(.bottom, 30)
            }
            .frame(maxWidth: .infinity)

            VersionTag()
                .padding(.top, 14)
                .padding(.trailing, 20)
        }
        .frame(width: 560, height: BrandWindow.height)
        .background(Theme.background)
        .preferredColorScheme(.dark)
        .ignoresSafeArea()
    }
}
