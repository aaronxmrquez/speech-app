import AppKit
import Combine

/// Coordina todo el flujo de dictado: hotkey → audio → transcripción → inserción.
@MainActor
final class AppState: ObservableObject {

    enum Phase: Equatable {
        case idle
        case recording
        case transcribing
        case inserting
        case done
        case notice(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var partialText = ""
    @Published private(set) var audioLevel: Float = 0
    /// true cuando el detector global de teclado está escuchando.
    @Published private(set) var hotkeyActive = false

    let prefs: Preferences
    let permissions: Permissions

    private let recorder = AudioRecorder()
    private let engine: TranscriptionEngine = AppleSpeechEngine()
    private let inserter = TextInserter()
    private let hotkey = HotkeyMonitor()

    private var recordingStartedAt: Date?
    private var dismissTask: Task<Void, Never>?
    private var healTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(prefs: Preferences, permissions: Permissions) {
        self.prefs = prefs
        self.permissions = permissions

        hotkey.onHoldBegan = { [weak self] in
            Task { @MainActor in self?.holdBegan() }
        }
        hotkey.onHoldEnded = { [weak self] in
            Task { @MainActor in self?.holdEnded() }
        }
        hotkey.onToggle = { [weak self] in
            Task { @MainActor in self?.toggleTapped() }
        }
        hotkey.onCancel = { [weak self] in
            Task { @MainActor in self?.cancelDictation() }
        }

        // objectWillChange dispara antes del cambio; el Task lee los valores ya actualizados.
        prefs.objectWillChange
            .sink { [weak self] _ in
                Task { @MainActor in self?.syncHotkeyConfig() }
            }
            .store(in: &cancellables)
    }

    /// Arranca (o re-arranca) el monitor global de teclado. Idempotente;
    /// seguro de llamar de nuevo cuando se conceda Accesibilidad.
    func start() {
        permissions.refresh()
        syncHotkeyConfig()
        if permissions.accessibility {
            hotkey.start()
        }
        hotkeyActive = hotkey.isRunning

        // Auto-recuperación: el permiso de Accesibilidad puede concederse (o
        // revocarse) en cualquier momento desde Ajustes del Sistema, sin que
        // la app reciba aviso alguno. Verificar periódicamente.
        if healTimer == nil {
            healTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
                Task { @MainActor in self?.heal() }
            }
        }
    }

    private func heal() {
        permissions.refresh()
        if permissions.accessibility {
            if !hotkey.isRunning { hotkey.start() }
        } else if hotkey.isRunning {
            hotkey.stop()
        }
        hotkeyActive = hotkey.isRunning
    }

    private func syncHotkeyConfig() {
        hotkey.holdEnabled = prefs.activationMode == .hold
        hotkey.toggleEnabled = prefs.activationMode == .toggle
        switch prefs.holdKey {
        case .rightCommand: hotkey.holdKey = .rightCommand
        case .rightOption: hotkey.holdKey = .rightOption
        case .fn: hotkey.holdKey = .fn
        }
    }

    // MARK: activación

    private func holdBegan() {
        guard prefs.activationMode == .hold else { return }
        beginDictation()
    }

    private func holdEnded() {
        guard prefs.activationMode == .hold, phase == .recording else { return }
        endDictation()
    }

    private func toggleTapped() {
        guard prefs.activationMode == .toggle else { return }
        if phase == .recording {
            endDictation()
        } else if canBegin {
            beginDictation()
        }
    }

    /// Para el ítem "Dictar ahora" del menú.
    func toggleFromMenu() {
        if phase == .recording {
            endDictation()
        } else if canBegin {
            beginDictation()
        }
    }

    private var canBegin: Bool {
        switch phase {
        case .idle, .done, .notice: return true
        default: return false
        }
    }

    // MARK: flujo de dictado

    func beginDictation() {
        guard canBegin else { return }
        guard permissions.allGranted else {
            (NSApp.delegate as? AppDelegate)?.showOnboarding()
            return
        }

        dismissTask?.cancel()
        partialText = ""
        audioLevel = 0

        do {
            try engine.begin(localeId: prefs.languageId) { [weak self] text in
                Task { @MainActor in self?.partialText = text }
            }
            recorder.onBuffer = { [engine] buffer in engine.append(buffer) }
            recorder.onLevel = { [weak self] level in
                Task { @MainActor in self?.audioLevel = level }
            }
            try recorder.start()
        } catch {
            engine.cancel()
            recorder.stop()
            showNotice(error.localizedDescription)
            return
        }

        recordingStartedAt = Date()
        phase = .recording
        hotkey.isCapturing = true
        playSound("Tink")
    }

    func endDictation() {
        guard phase == .recording else { return }
        hotkey.isCapturing = false
        recorder.stop()

        // Toque accidental: demasiado corto para ser un dictado real.
        if let started = recordingStartedAt, Date().timeIntervalSince(started) < 0.35 {
            engine.cancel()
            showNotice("Mantén la tecla mientras hablas")
            return
        }

        phase = .transcribing
        Task { [weak self] in
            guard let self else { return }
            let text = await self.engine.finish()
            guard self.phase == .transcribing else { return } // cancelado mientras tanto
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                self.showNotice("No escuché nada")
            } else {
                self.insert(trimmed)
            }
        }
    }

    private func insert(_ text: String) {
        phase = .inserting
        partialText = text
        inserter.insert(text) { [weak self] in
            guard let self else { return }
            self.playSound("Pop")
            self.phase = .done
            self.scheduleDismiss(after: 0.7) { $0 == .done }
        }
    }

    func cancelDictation() {
        guard phase == .recording || phase == .transcribing else { return }
        hotkey.isCapturing = false
        recorder.stop()
        engine.cancel()
        partialText = ""
        phase = .idle
    }

    private func showNotice(_ message: String) {
        phase = .notice(message)
        scheduleDismiss(after: 1.4) { if case .notice = $0 { return true }; return false }
    }

    private func scheduleDismiss(after seconds: Double, ifStill matches: @escaping (Phase) -> Bool) {
        dismissTask?.cancel()
        dismissTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            guard let self, !Task.isCancelled else { return }
            if matches(self.phase) { self.phase = .idle }
        }
    }

    private func playSound(_ name: String) {
        guard prefs.playSounds else { return }
        guard let sound = NSSound(named: name) else { return }
        sound.volume = 0.25
        sound.play()
    }

    /// Solo para el modo --render-previews (PreviewRenderer).
    func applyPreview(phase: Phase, partialText: String, audioLevel: Float) {
        self.phase = phase
        self.partialText = partialText
        self.audioLevel = audioLevel
    }
}
