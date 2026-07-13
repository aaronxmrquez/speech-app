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
        BrandScreen(section: "PERMISSIONS") {
            VStack(spacing: 8) {
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

            // El statement se mudó al splash: aquí va el botón de cierre
            // del set up, con el ancho fijo del diseño.
            PrimaryButton(label: "ALL SET! START SPEAKING",
                          enabled: permissions.allGranted,
                          fullWidth: true,
                          action: onReady)
                .frame(width: 290)
                .frame(maxWidth: .infinity)
                .padding(.top, 46)
        }
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
            HStack(spacing: 33) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.04))
                        .overlay(Circle().strokeBorder(Theme.cardBorder, lineWidth: 1))
                        .frame(width: 38, height: 38)
                    Image(systemName: icon)
                        .font(.system(size: 19, weight: .light))
                        .foregroundStyle(Theme.secondary)
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text(title)
                        .font(Theme.mono(15, .regular))
                        .tracking(0.15)
                        .foregroundStyle(Theme.primary)
                    Text(detail)
                        .font(Theme.sans(11.5))
                        .foregroundStyle(Theme.secondary)
                }

                Spacer()

                StatusCircle(granted: granted)
            }
            .padding(.horizontal, 30)
            .frame(height: 121)
            .contentShape(RoundedRectangle(cornerRadius: 38, style: .continuous))
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .fill(Theme.card)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 38, style: .continuous)
                .strokeBorder(Theme.cardBorder, lineWidth: 1)
        )
    }
}
