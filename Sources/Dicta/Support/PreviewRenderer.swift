import SwiftUI
import AppKit

/// Modo oculto de desarrollo: `Dicta --render-previews <dir>` renderiza las
/// vistas principales a PNG y termina. Permite verificar el diseño sin
/// permisos de grabación de pantalla.
@MainActor
enum PreviewRenderer {
    static func runIfRequested(prefs: Preferences, permissions: Permissions) -> Bool {
        guard let flagIndex = CommandLine.arguments.firstIndex(of: "--render-previews"),
              CommandLine.arguments.count > flagIndex + 1 else { return false }
        let dir = URL(fileURLWithPath: CommandLine.arguments[flagIndex + 1], isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        render(SplashView(onBegin: {}),
               size: CGSize(width: 560, height: 792),
               to: dir.appendingPathComponent("splash.png"))

        // Onboarding con permisos mixtos, para ver ambos estados de fila.
        // renderInWindow: ImageRenderer no dibuja el contenido de ScrollView.
        permissions.microphone = true
        renderInWindow(OnboardingView(permissions: permissions, onReady: {}),
                       size: CGSize(width: 560, height: 792),
                       to: dir.appendingPathComponent("onboarding.png"))

        // Estado "activo": todos los permisos concedidos.
        let grantedPermissions = Permissions()
        grantedPermissions.microphone = true
        grantedPermissions.speechRecognition = true
        grantedPermissions.accessibility = true
        renderInWindow(OnboardingView(permissions: grantedPermissions, onReady: {}),
                       size: CGSize(width: 560, height: 792),
                       to: dir.appendingPathComponent("onboarding-active.png"))

        let state = AppState(prefs: prefs, permissions: permissions, history: HistoryStore.preview())
        state.applyPreview(phase: .recording,
                           partialText: "hola, esto es una prueba del dictado por voz",
                           audioLevel: 0.7)
        render(HUDView(state: state, prefs: prefs),
               size: CGSize(width: 480, height: 130),
               to: dir.appendingPathComponent("hud-recording.png"))

        let doneState = AppState(prefs: prefs, permissions: permissions, history: HistoryStore.preview())
        doneState.applyPreview(phase: .done, partialText: "", audioLevel: 0)
        render(HUDView(state: doneState, prefs: prefs),
               size: CGSize(width: 480, height: 130),
               to: dir.appendingPathComponent("hud-done.png"))

        // Ajustes usa controles AppKit (pickers, switches) que ImageRenderer no
        // sabe dibujar: renderizar la ventana real con cacheDisplay.
        renderInWindow(SettingsView(prefs: prefs),
                       size: CGSize(width: 560, height: 792),
                       to: dir.appendingPathComponent("settings.png"))

        renderInWindow(HistoryView(history: HistoryStore.preview()),
                       size: CGSize(width: 560, height: 792),
                       to: dir.appendingPathComponent("history.png"))

        return true
    }

    private static func renderInWindow(_ view: some View, size: CGSize, to url: URL) {
        // Ventana con titlebar real (como en la app): así el render refleja
        // el safe area y la posición verdadera del contenido.
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size),
                              styleMask: [.titled, .closable, .fullSizeContentView],
                              backing: .buffered,
                              defer: false)
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(calibratedWhite: 0.04, alpha: 1)
        let hosting = NSHostingView(rootView: view)
        hosting.sizingOptions = []
        hosting.frame = NSRect(origin: .zero, size: size)
        window.contentView = hosting
        BrandWindow.applyChrome(to: window)
        hosting.layoutSubtreeIfNeeded()
        window.displayIfNeeded()

        guard let rep = hosting.bitmapImageRepForCachingDisplay(in: hosting.bounds) else { return }
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        guard let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }

    private static func render(_ view: some View, size: CGSize, to url: URL) {
        let content = view
            .frame(width: size.width, height: size.height)
            .preferredColorScheme(.dark)
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        guard let image = renderer.nsImage,
              let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        try? png.write(to: url)
    }
}
