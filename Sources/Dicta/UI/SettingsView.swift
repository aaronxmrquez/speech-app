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
            w.contentView = NSHostingView(rootView: SettingsView(prefs: prefs))
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

struct SettingsView: View {
    @ObservedObject var prefs: Preferences
    @ObservedObject private var models = ModelManager.shared
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?

    var body: some View {
        BrandScreen(title: "SETTINGS") {
            VStack(alignment: .leading, spacing: 14) {
                section("ACTIVATION") {
                    row("MODE") {
                        HStack(spacing: 4) {
                            ChipButton(label: "HOLD KEY", selected: prefs.activationMode == .hold) {
                                prefs.activationMode = .hold
                            }
                            ChipButton(label: "TOGGLE", selected: prefs.activationMode == .toggle) {
                                prefs.activationMode = .toggle
                            }
                        }
                    }
                    BrandDivider()
                    row("KEY") {
                        MenuChip(
                            options: HoldKey.allCases.map { ($0, $0.chipLabel) },
                            selection: $prefs.holdKey
                        )
                    }
                }

                section("ENGINE") {
                    row("VOICE ENGINE") {
                        HStack(spacing: 4) {
                            ChipButton(label: "APPLE", selected: prefs.engine == .apple) {
                                prefs.engine = .apple
                            }
                            ChipButton(label: "WHISPER", selected: prefs.engine == .whisper) {
                                prefs.engine = .whisper
                                if !models.modelReady && !models.isDownloading {
                                    models.download()
                                }
                            }
                        }
                    }
                    if prefs.engine == .whisper {
                        BrandDivider()
                        row("LARGE-V3-TURBO MODEL") {
                            modelStatus
                        }
                        .frame(minHeight: 50)
                    }
                }

                section("LANGUAGE") {
                    row("DICTATE IN") {
                        MenuChip(
                            options: DictationLanguage.all.map { ($0.id, $0.label.uppercased()) },
                            selection: $prefs.languageId
                        )
                    }
                }

                section("GENERAL") {
                    row("OPEN AT LOGIN") {
                        BrandToggle(isOn: launchAtLoginBinding)
                    }
                    if let launchAtLoginError {
                        Text(launchAtLoginError)
                            .font(Theme.sans(11))
                            .foregroundStyle(Theme.secondary)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    BrandDivider()
                    row("DICTATION SOUNDS") {
                        BrandToggle(isOn: $prefs.playSounds)
                    }
                    BrandDivider()
                    row("SAVE HISTORY") {
                        BrandToggle(isOn: $prefs.saveHistory)
                    }
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 16)
            .padding(.bottom, 8)
        }
    }

    // MARK: filas y estados

    @ViewBuilder
    private var modelStatus: some View {
        if models.modelReady {
            StatusCircle(granted: true, size: 28)
        } else if models.isDownloading {
            HStack(spacing: 10) {
                ProgressView(value: models.progress)
                    .progressViewStyle(.linear)
                    .frame(width: 90)
                    .tint(Theme.accent)
                Text("\(Int(models.progress * 100))%")
                    .font(Theme.mono(12, .medium))
                    .foregroundStyle(Theme.secondary)
            }
        } else {
            ChipButton(label: "DOWNLOAD · 574 MB", selected: true) {
                models.download()
            }
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { launchAtLogin },
            set: { enabled in
                launchAtLogin = enabled
                do {
                    if enabled {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                    launchAtLoginError = nil
                } catch {
                    launchAtLogin = SMAppService.mainApp.status == .enabled
                    launchAtLoginError = "To open at login, Dicta must be installed in /Applications."
                }
            }
        )
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: @escaping () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionLabel(text: title)
            BrandCard { content() }
        }
    }

    private func row(_ label: String, @ViewBuilder control: () -> some View) -> some View {
        HStack {
            Text(label)
                .font(Theme.mono(13, .medium))
                .tracking(2)
                .foregroundStyle(Theme.primary)
            Spacer()
            control()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
    }
}
