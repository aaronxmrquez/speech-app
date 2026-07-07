import AppKit
import Combine

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let state: AppState
    private weak var appDelegate: AppDelegate?
    private var cancellables = Set<AnyCancellable>()

    init(state: AppState, delegate: AppDelegate) {
        self.state = state
        self.appDelegate = delegate
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        updateIcon()
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        state.$phase.sink { [weak self] _ in
            Task { @MainActor in self?.updateIcon() }
        }.store(in: &cancellables)
        state.$hotkeyActive.sink { [weak self] _ in
            Task { @MainActor in self?.updateIcon() }
        }.store(in: &cancellables)
    }

    private func updateIcon() {
        let name: String
        if !state.hotkeyActive {
            name = "mic.slash" // el detector de teclado no está escuchando
        } else {
            switch state.phase {
            case .recording, .transcribing, .inserting: name = "waveform"
            default: name = "mic"
            }
        }
        let config = NSImage.SymbolConfiguration(pointSize: 13.5, weight: .medium)
        let image = NSImage(systemSymbolName: name, accessibilityDescription: "Dicta")?
            .withSymbolConfiguration(config)
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    // Reconstruye el menú en cada apertura: los checkmarks siempre reflejan el estado.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if state.hotkeyActive {
            let hint = state.prefs.activationMode == .hold
                ? "Mantén \(state.prefs.holdKey.label) y habla"
                : "⌥ Espacio para dictar"
            menu.addItem(disabledItem(hint))
        } else {
            menu.addItem(disabledItem("⚠︎ Hotkey inactivo — falta Accesibilidad"))
            let grant = NSMenuItem(title: "Conceder Accesibilidad…",
                                   action: #selector(grantAccessibility), keyEquivalent: "")
            grant.target = self
            menu.addItem(grant)
        }
        menu.addItem(.separator())

        let dictate = NSMenuItem(
            title: state.phase == .recording ? "Detener dictado" : "Dictar ahora",
            action: #selector(dictateNow), keyEquivalent: "")
        dictate.target = self
        menu.addItem(dictate)
        menu.addItem(.separator())

        let languageRoot = NSMenuItem(title: "Idioma", action: nil, keyEquivalent: "")
        let languageMenu = NSMenu()
        for language in DictationLanguage.all {
            let item = NSMenuItem(title: language.label, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = language.id
            item.state = state.prefs.languageId == language.id ? .on : .off
            languageMenu.addItem(item)
        }
        languageRoot.submenu = languageMenu
        menu.addItem(languageRoot)

        let historyItem = NSMenuItem(title: "Historial…", action: #selector(openHistory), keyEquivalent: "")
        historyItem.target = self
        menu.addItem(historyItem)

        let settings = NSMenuItem(title: "Ajustes…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)

        let permissions = NSMenuItem(title: "Permisos…", action: #selector(openOnboarding), keyEquivalent: "")
        permissions.target = self
        menu.addItem(permissions)

        let relaunch = NSMenuItem(title: "Reiniciar Dicta", action: #selector(relaunchApp), keyEquivalent: "")
        relaunch.target = self
        menu.addItem(relaunch)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Salir de Dicta",
                                action: #selector(NSApplication.terminate(_:)),
                                keyEquivalent: "q"))
    }

    private func disabledItem(_ title: String) -> NSMenuItem {
        // sin action → NSMenu lo deshabilita automáticamente (autoenablesItems)
        NSMenuItem(title: title, action: nil, keyEquivalent: "")
    }

    @objc private func dictateNow() { state.toggleFromMenu() }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        if let id = sender.representedObject as? String {
            state.prefs.languageId = id
        }
    }

    @objc private func openSettings() { appDelegate?.showSettings() }
    @objc private func openOnboarding() { appDelegate?.showOnboarding() }
    @objc private func openHistory() { appDelegate?.showHistory() }
    @objc private func relaunchApp() { appDelegate?.relaunch() }

    @objc private func grantAccessibility() {
        state.permissions.requestAccessibility()
        state.permissions.openAccessibilitySettings()
    }
}
