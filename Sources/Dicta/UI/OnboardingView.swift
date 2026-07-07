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
            let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 560),
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
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Theme.card)
                        .frame(width: 64, height: 64)
                        .overlay(Circle().strokeBorder(Theme.border, lineWidth: 1))
                    Image(systemName: "waveform")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(Theme.primary)
                }
                Text("Dicta")
                    .font(.system(size: 26, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                Text("Habla y escribe en cualquier app.\nPara funcionar necesita tres permisos de macOS.")
                    .font(.system(size: 12.5))
                    .foregroundStyle(Theme.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.top, 36)
            .padding(.bottom, 28)

            VStack(spacing: 10) {
                PermissionRow(
                    icon: "mic",
                    title: "Micrófono",
                    detail: "Para escuchar tu voz mientras dictas.",
                    granted: permissions.microphone
                ) {
                    permissions.requestMicrophone()
                }
                PermissionRow(
                    icon: "waveform",
                    title: "Reconocimiento de voz",
                    detail: "Para convertir tu voz en texto.",
                    granted: permissions.speechRecognition
                ) {
                    permissions.requestSpeechRecognition()
                }
                PermissionRow(
                    icon: "accessibility",
                    title: "Accesibilidad",
                    detail: "Para detectar la tecla de dictado y escribir el texto.",
                    granted: permissions.accessibility
                ) {
                    permissions.requestAccessibility()
                    permissions.openAccessibilitySettings()
                }
            }
            .padding(.horizontal, 28)

            Spacer()

            VStack(spacing: 12) {
                Button(action: onReady) {
                    Text("Empezar a dictar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(permissions.allGranted ? Color.black : Theme.tertiary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Capsule().fill(permissions.allGranted ? Color.white : Theme.card))
                }
                .buttonStyle(.plain)
                .disabled(!permissions.allGranted)

                Text("Mantén ⌘ derecha y habla — al soltarla, el texto se escribe solo.")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.tertiary)
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .frame(width: 440, height: 560)
        .background(Theme.background)
        .preferredColorScheme(.dark)
    }
}

struct PermissionRow: View {
    let icon: String
    let title: String
    let detail: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Theme.primary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Theme.card))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.primary)
                Text(detail)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Theme.secondary)
            }

            Spacer()

            if granted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.primary)
                    .transition(.scale.combined(with: .opacity))
            } else {
                Button(action: action) {
                    Text("Permitir")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Capsule().fill(Color.white))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.card))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .strokeBorder(Theme.border, lineWidth: 1))
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: granted)
    }
}
