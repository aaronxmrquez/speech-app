import AppKit
import SwiftUI

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }

    private(set) var prefs = Preferences()
    private(set) var permissions = Permissions()
    private(set) var history = HistoryStore()
    private(set) lazy var appState = AppState(prefs: prefs, permissions: permissions, history: history)

    private var menuBar: MenuBarController?
    private var hud: HUDController?
    private var settingsWindow: SettingsWindowController?
    private var onboardingWindow: OnboardingWindowController?
    private var historyWindow: HistoryWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        if PreviewRenderer.runIfRequested(prefs: prefs, permissions: permissions) {
            NSApp.terminate(nil)
            return
        }

        // Modo debug: transcribir un archivo con Whisper e imprimir el resultado.
        if let flagIndex = CommandLine.arguments.firstIndex(of: "--transcribe-file"),
           CommandLine.arguments.count > flagIndex + 1 {
            let path = CommandLine.arguments[flagIndex + 1]
            let language = CommandLine.arguments.count > flagIndex + 2
                ? CommandLine.arguments[flagIndex + 2] : "auto"
            Task { @MainActor in
                let text = await DebugTranscriber.transcribe(path: path, language: language)
                print("TRANSCRIPT[\(language)]: \(text)")
                exit(0)
            }
            return
        }

        NSApp.setActivationPolicy(.accessory)
        permissions.refresh()

        hud = HUDController(state: appState)
        menuBar = MenuBarController(state: appState, delegate: self)
        appState.start()

        if !(permissions.allGranted && prefs.hasCompletedOnboarding) {
            showOnboarding()
        }
    }

    // Doble clic sobre la app en Finder/Launchpad cuando ya está corriendo:
    // mostrar siempre una ventana (es una app de barra de menús, sin Dock).
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if permissions.allGranted && prefs.hasCompletedOnboarding {
            showSettings()
        } else {
            showOnboarding()
        }
        return true
    }

    // Solo una ventana de Dicta a la vez: abrir una cierra las demás.
    private func closeOtherWindows(keeping keep: AnyObject?) {
        if settingsWindow !== keep { settingsWindow?.close() }
        if historyWindow !== keep { historyWindow?.close() }
        if onboardingWindow !== keep { onboardingWindow?.close() }
    }

    func showOnboarding() {
        if onboardingWindow == nil {
            onboardingWindow = OnboardingWindowController(permissions: permissions, prefs: prefs) { [weak self] in
                // reintenta el event tap ahora que Accesibilidad puede estar concedida
                self?.appState.start()
                // Instalación nueva: si el motor Whisper no tiene modelo aún,
                // abrir Ajustes para que la descarga quede a un clic.
                if self?.prefs.engine == .whisper && ModelManager.shared.modelReady == false {
                    self?.showSettings()
                }
            }
        }
        closeOtherWindows(keeping: onboardingWindow)
        onboardingWindow?.show()
    }

    func showSettings() {
        if settingsWindow == nil {
            settingsWindow = SettingsWindowController(prefs: prefs)
        }
        closeOtherWindows(keeping: settingsWindow)
        settingsWindow?.show()
    }

    func showHistory() {
        if historyWindow == nil {
            historyWindow = HistoryWindowController(history: appState.history)
        }
        closeOtherWindows(keeping: historyWindow)
        historyWindow?.show()
    }

    /// Relanza la app (útil cuando macOS no aplica un permiso recién concedido
    /// hasta reiniciar el proceso).
    func relaunch() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-n", Bundle.main.bundlePath]
        try? task.run()
        NSApp.terminate(nil)
    }
}
