import AVFoundation

/// Modo oculto de desarrollo: `Dicta --transcribe-file <audio> [es|en|auto]`
/// transcribe un archivo con Whisper y lo imprime. Permite verificar el motor
/// sin micrófono ni permisos.
enum DebugTranscriber {
    static func transcribe(path: String, language: String) async -> String {
        guard let file = try? AVAudioFile(forReading: URL(fileURLWithPath: path)) else {
            return "(no se pudo abrir \(path))"
        }
        let format = file.processingFormat
        let resampler = Resampler(inputFormat: format)
        var samples: [Float] = []
        while file.framePosition < file.length {
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 8192),
                  (try? file.read(into: buffer)) != nil,
                  buffer.frameLength > 0 else { break }
            samples += resampler.convert(buffer)
        }
        guard !samples.isEmpty else { return "(audio vacío)" }

        guard let context = try? WhisperContext(modelPath: ModelManager.modelURL.path) else {
            return "(no se pudo cargar el modelo en \(ModelManager.modelURL.path))"
        }
        let audio = samples
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: context.transcribe(samples: audio, language: language))
            }
        }
    }
}
