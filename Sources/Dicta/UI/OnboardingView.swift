import SwiftUI
import AppKit

@MainActor
final class OnboardingWindowController: NSObject, NSWindowDelegate {
    private var window: NSWindow?
    private let permissions: Permissions
    private let prefs: Preferences
    private let onReady: () -> Void

    init(permissions: Permissions, prefs: Preferences, onReady: @escaping () -> Void) {
        self.permissions = permissions
        self.prefs = prefs
        self.onReady = onReady
    }

    func show() {
        if window == nil {
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 560, height: 762),
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
            w.contentView = NSHostingView(rootView: OnboardingView(permissions: permissions) { [weak self] in
                self?.finish()
            })
            w.center()
            window = w
        }
        permissions.refresh()
        permissions.startPolling()
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    private func finish() {
        prefs.hasCompletedOnboarding = true
        window?.close() // windowWillClose detiene el sondeo y notifica
    }

    func close() {
        window?.close()
    }

    func windowWillClose(_ notification: Notification) {
        permissions.stopPolling()
        if permissions.allGranted {
            prefs.hasCompletedOnboarding = true
        }
        onReady()
    }
}

struct OnboardingView: View {
    @ObservedObject var permissions: Permissions
    var onReady: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            BrandHeader(title: "SET UP")

            VStack(spacing: 14) {
                PermissionCard(
                    icon: "mic",
                    title: "MICROPHONE",
                    detail: "To listen to your voice while you speak.",
                    granted: permissions.microphone
                ) {
                    permissions.requestMicrophone()
                }
                PermissionCard(
                    icon: "waveform",
                    title: "SPEECH RECOGNITION",
                    detail: "To convert your voice into text.",
                    granted: permissions.speechRecognition
                ) {
                    permissions.requestSpeechRecognition()
                }
                PermissionCard(
                    icon: "accessibility",
                    title: "ACCESSIBILITY",
                    detail: "To detect your hotkey and type the text.",
                    granted: permissions.accessibility
                ) {
                    permissions.requestAccessibility()
                    permissions.openAccessibilitySettings()
                }
            }
            .padding(.horizontal, 30)
            .padding(.top, 24)

            HStack(alignment: .bottom, spacing: 16) {
                // Space Mono trae mucho aire interno: el spacing negativo
                // compensa para el leading apretado de la referencia.
                VStack(alignment: .leading, spacing: -6) {
                    Text("BECAUSE WE KNOW")
                        .foregroundStyle(Theme.tertiary)
                    Text("YOU HATE TYPING.")
                        .foregroundStyle(Theme.tertiary)
                    Text("USE DICTA.")
                        .foregroundStyle(Theme.primary)
                }
                .font(Theme.mono(24, .medium))
                .tracking(2)

                Spacer()

                PrimaryButton(label: "LET'S START", enabled: permissions.allGranted, action: onReady)
            }
            .padding(.horizontal, 30)
            .padding(.top, 60) // gap fijo entre las cards y el bloque final

            BrandFooter()
                .padding(.top, 24)
                .padding(.bottom, 16)
        }
        .frame(width: 560, height: 762)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }
}

struct PermissionCard: View {
    let icon: String
    let title: String
    let detail: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        Button {
            if !granted { action() }
        } label: {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.04))
                        .overlay(Circle().strokeBorder(Theme.cardBorder, lineWidth: 1))
                        .frame(width: 46, height: 46)
                    Image(systemName: icon)
                        .font(.system(size: 17, weight: .light))
                        .foregroundStyle(Theme.secondary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(Theme.mono(15, .medium))
                        .tracking(2.5)
                        .foregroundStyle(Theme.primary)
                    Text(detail)
                        .font(Theme.sans(12.5))
                        .foregroundStyle(Theme.secondary)
                }

                Spacer()

                StatusCircle(granted: granted)
            }
            .padding(22)
            .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .buttonStyle(.plain)
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
