import AVFoundation

final class AudioRecorder {
    private var engine = AVAudioEngine()
    private(set) var isRunning = false

    /// Llega en el hilo de audio.
    var onBuffer: ((AVAudioPCMBuffer) -> Void)?
    /// Nivel normalizado 0…1. Llega en el hilo de audio.
    var onLevel: ((Float) -> Void)?

    func start() throws {
        guard !isRunning else { return }
        // Instancia fresca por sesión: evita formatos obsoletos si cambió el
        // dispositivo de entrada entre dictados.
        engine = AVAudioEngine()
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            throw NSError(domain: "Dicta", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No microphone available"])
        }
        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            guard let self else { return }
            self.onBuffer?(buffer)
            self.onLevel?(Self.normalizedLevel(of: buffer))
        }
        engine.prepare()
        try engine.start()
        isRunning = true
    }

    func stop() {
        guard isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isRunning = false
    }

    private static func normalizedLevel(of buffer: AVAudioPCMBuffer) -> Float {
        guard let data = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sum: Float = 0
        for i in 0..<count { sum += data[i] * data[i] }
        let rms = sqrt(sum / Float(count))
        let db = 20 * log10(max(rms, .leastNonzeroMagnitude))
        // −50 dB (silencio) … −6 dB (voz fuerte) → 0…1
        return min(1, max(0, (db + 50) / 44))
    }
}
