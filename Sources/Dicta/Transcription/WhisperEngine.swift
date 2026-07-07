import AVFoundation

/// Motor híbrido: mientras grabas ves parciales en vivo (motor de Apple) y al
/// terminar se transcribe todo el audio con Whisper local (Metal) para máxima
/// precisión — especialmente en inglés y con acento. Si Whisper no puede,
/// se usa el resultado de Apple como respaldo.
final class WhisperEngine: TranscriptionEngine {
    private let modelURL: URL
    private let partials = AppleSpeechEngine()

    private let contextLock = NSLock()
    private var context: WhisperContext?
    private var contextLoading = false

    private let samplesLock = NSLock()
    private var samples: [Float] = []

    private var resampler: Resampler?
    private var language = "auto"

    init(modelURL: URL) {
        self.modelURL = modelURL
        preloadContext()
    }

    /// Carga el modelo en segundo plano para que el primer dictado no espere.
    private func preloadContext() {
        contextLock.lock()
        let needsLoad = context == nil && !contextLoading
            && FileManager.default.fileExists(atPath: modelURL.path)
        if needsLoad { contextLoading = true }
        contextLock.unlock()
        guard needsLoad else { return }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let loaded = try? WhisperContext(modelPath: self.modelURL.path)
            self.contextLock.lock()
            self.context = loaded
            self.contextLoading = false
            self.contextLock.unlock()
        }
    }

    func begin(localeId: String, onPartial: @escaping (String) -> Void) throws {
        guard FileManager.default.fileExists(atPath: modelURL.path) else {
            throw NSError(domain: "Dicta", code: 4,
                          userInfo: [NSLocalizedDescriptionKey: "Falta el modelo Whisper — descárgalo en Ajustes"])
        }
        preloadContext()

        language = Self.whisperLanguage(from: localeId)
        samplesLock.lock()
        samples.removeAll(keepingCapacity: true)
        samplesLock.unlock()
        resampler = nil

        // Parciales en vivo con Apple (solo para mostrar; Whisper decide el texto
        // final). Apple no autodetecta idioma: con "auto" usa español. Si Apple
        // falla (p. ej. sin conexión), seguimos sin parciales.
        try? partials.begin(localeId: localeId == "auto" ? "es-MX" : localeId, onPartial: onPartial)
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        partials.append(buffer)
        if resampler == nil { resampler = Resampler(inputFormat: buffer.format) }
        guard let converted = resampler?.convert(buffer), !converted.isEmpty else { return }
        samplesLock.lock()
        samples.append(contentsOf: converted)
        samplesLock.unlock()
    }

    func finish() async -> String {
        let appleText = await partials.finish()

        samplesLock.lock()
        var audio = samples
        samples = []
        samplesLock.unlock()

        // whisper.cpp necesita al menos ~1 s de audio: rellenar con silencio.
        let minimum = Int(Resampler.whisperSampleRate * 1.1)
        if audio.count < minimum {
            audio.append(contentsOf: [Float](repeating: 0, count: minimum - audio.count))
        }

        guard let context = await waitForContext() else { return appleText }
        let language = self.language
        let text = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: context.transcribe(samples: audio, language: language))
            }
        }
        return text.isEmpty ? appleText : text
    }

    func cancel() {
        partials.cancel()
        samplesLock.lock()
        samples.removeAll()
        samplesLock.unlock()
    }

    /// Espera (máx. 15 s) a que termine la carga del modelo si sigue en curso.
    private func waitForContext() async -> WhisperContext? {
        for _ in 0..<150 {
            contextLock.lock()
            let loaded = context
            let loading = contextLoading
            contextLock.unlock()
            if let loaded { return loaded }
            if !loading { return nil }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        return nil
    }

    /// "es-MX" → "es", "en-US" → "en", "auto" → "auto"
    private static func whisperLanguage(from localeId: String) -> String {
        if localeId == "auto" { return "auto" }
        return String(localeId.prefix(2)).lowercased()
    }
}
