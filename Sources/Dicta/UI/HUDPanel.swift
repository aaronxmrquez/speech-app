import AppKit
import SwiftUI
import Combine

/// Panel flotante que muestra el estado del dictado sin robar nunca el foco
/// de la app donde el usuario está escribiendo.
final class HUDPanel: NSPanel {
    init() {
        super.init(contentRect: .zero,
                   styleMask: [.borderless, .nonactivatingPanel],
                   backing: .buffered,
                   defer: false)
        isFloatingPanel = true
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        backgroundColor = .clear
        isOpaque = false
        hasShadow = false // la sombra la dibuja SwiftUI dentro del margen del panel
        ignoresMouseEvents = true
        hidesOnDeactivate = false
        isReleasedWhenClosed = false
        animationBehavior = .none
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class HUDController {
    private let panel = HUDPanel()
    private var cancellable: AnyCancellable?
    // Margen extra alrededor de la píldora para que la sombra no se recorte.
    private let panelSize = NSSize(width: 480, height: 130)
    private var wantsVisible = false

    init(state: AppState) {
        let hosting = NSHostingView(rootView: HUDView(state: state, prefs: state.prefs))
        hosting.frame = NSRect(origin: .zero, size: panelSize)
        panel.contentView = hosting
        panel.setContentSize(panelSize)

        cancellable = state.$phase.sink { [weak self] phase in
            Task { @MainActor in
                phase == .idle ? self?.hide() : self?.show()
            }
        }
    }

    private func show() {
        wantsVisible = true
        guard !panel.isVisible || panel.alphaValue < 1 else { return }
        position()
        if !panel.isVisible { panel.alphaValue = 0 }
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.18
            panel.animator().alphaValue = 1
        }
    }

    private func hide() {
        wantsVisible = false
        guard panel.isVisible else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.22
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, !self.wantsVisible else { return }
            self.panel.orderOut(nil)
        })
    }

    /// Abajo-centro de la pantalla donde está el puntero (la más probable
    /// de contener el campo de texto activo).
    private func position() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let screen else { return }
        let visible = screen.visibleFrame
        panel.setFrameOrigin(NSPoint(x: visible.midX - panelSize.width / 2,
                                     y: visible.minY + 12))
    }
}
