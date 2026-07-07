import AVFoundation
import Speech
import ApplicationServices
import AppKit
import Combine

@MainActor
final class Permissions: ObservableObject {
    @Published var microphone = false
    @Published var speechRecognition = false
    @Published var accessibility = false

    private var pollTimer: Timer?

    var allGranted: Bool { microphone && speechRecognition && accessibility }

    func refresh() {
        microphone = AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        speechRecognition = SFSpeechRecognizer.authorizationStatus() == .authorized
        accessibility = AXIsProcessTrusted()
    }

    func requestMicrophone() {
        AVCaptureDevice.requestAccess(for: .audio) { _ in
            Task { @MainActor in self.refresh() }
        }
    }

    func requestSpeechRecognition() {
        SFSpeechRecognizer.requestAuthorization { _ in
            Task { @MainActor in self.refresh() }
        }
    }

    func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // El permiso de Accesibilidad se concede fuera de la app: sondear mientras
    // el onboarding está visible para reflejarlo en vivo.
    func startPolling() {
        stopPolling()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            Task { @MainActor in self.refresh() }
        }
    }

    func stopPolling() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
}
