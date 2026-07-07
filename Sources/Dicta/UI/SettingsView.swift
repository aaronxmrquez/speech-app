import SwiftUI
import AppKit
import ServiceManagement

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let prefs: Preferences

    init(prefs: Preferences) {
        self.prefs = prefs
    }

    func show() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 400, height: 480),
                             styleMask: [.titled, .closable, .fullSizeContentView],
                             backing: .buffered,
                             defer: false)
            w.titlebarAppearsTransparent = true
            w.titleVisibility = .hidden
            w.isMovableByWindowBackground = true
            w.backgroundColor = NSColor(calibratedWhite: 0.04, alpha: 1)
            w.appearance = NSAppearance(named: .darkAqua)
            w.isReleasedWhenClosed = false
            w.collectionBehavior = [.moveToActiveSpace]
            w.contentView = NSHostingView(rootView: SettingsView(prefs: prefs))
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject var prefs: Preferences
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Ajustes")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.primary)
                .padding(.top, 8)

            section("ACTIVACIÓN") {
                row("Modo") {
                    Picker("", selection: $prefs.activationMode) {
                        Text("Mantener tecla").tag(ActivationMode.hold)
                        Text("Alternar ⌥␣").tag(ActivationMode.toggle)
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 210)
                }
                if prefs.activationMode == .hold {
                    divider
                    row("Tecla") {
                        Picker("", selection: $prefs.holdKey) {
                            ForEach(HoldKey.allCases) { key in
                                Text(key.label).tag(key)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                }
            }

            section("IDIOMA") {
                row("Dictar en") {
                    Picker("", selection: $prefs.languageId) {
                        ForEach(DictationLanguage.all) { language in
                            Text(language.label).tag(language.id)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 200)
                }
            }

            section("GENERAL") {
                row("Abrir al iniciar sesión") {
                    Toggle("", isOn: $launchAtLogin)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .onChange(of: launchAtLogin) { _, enabled in
                            setLaunchAtLogin(enabled)
                        }
                }
                divider
                row("Sonidos de dictado") {
                    Toggle("", isOn: $prefs.playSounds)
                        .labelsHidden()
                        .toggleStyle(.switch)
                }
            }

            if let launchAtLoginError {
                Text(launchAtLoginError)
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.secondary)
            }

            Spacer()

            Text("Dicta 1.0 — habla y el texto se escribe donde esté tu cursor.")
                .font(.system(size: 11))
                .foregroundStyle(Theme.tertiary)
        }
        .padding(28)
        .frame(width: 400, height: 480, alignment: .topLeading)
        .background(Theme.background)
        .tint(Color.white.opacity(0.35))
        .preferredColorScheme(.dark)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLogin = SMAppService.mainApp.status == .enabled
            launchAtLoginError = "Para abrir al iniciar sesión, Dicta debe estar en /Applications."
        }
    }

    // MARK: componentes

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundStyle(Theme.tertiary)
            VStack(spacing: 0) { content() }
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.card))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1))
        }
    }

    private func row(_ label: String, @ViewBuilder control: () -> some View) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(Theme.primary)
            Spacer()
            control()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var divider: some View {
        Rectangle()
            .fill(Theme.border)
            .frame(height: 1)
            .padding(.leading, 14)
    }
}
