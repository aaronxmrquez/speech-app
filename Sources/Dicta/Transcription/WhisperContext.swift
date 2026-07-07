import Foundation
import CWhisper

/// Envuelve el contexto C de whisper.cpp. Cargar el modelo tarda ~1-2 s y usa
/// ~800 MB de RAM, así que se carga una vez y se mantiene vivo.
/// `transcribe` no es reentrante: el llamador debe serializar las llamadas
/// (la máquina de estados de AppState ya garantiza un dictado a la vez).
final class WhisperContext {
    private let ctx: OpaquePointer

    init(modelPath: String) throws {
        var params = whisper_context_default_params()
        params.use_gpu = true
        params.flash_attn = true
        guard let ctx = whisper_init_from_file_with_params(modelPath, params) else {
            throw NSError(domain: "Dicta", code: 3,
                          userInfo: [NSLocalizedDescriptionKey: "No se pudo cargar el modelo Whisper"])
        }
        self.ctx = ctx
    }

    deinit {
        whisper_free(ctx)
    }

    /// Transcribe audio 16 kHz mono Float32. `language`: "es", "en" o "auto".
    func transcribe(samples: [Float], language: String) -> String {
        guard !samples.isEmpty else { return "" }

        var params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY)
        params.print_progress = false
        params.print_realtime = false
        params.print_special = false
        params.print_timestamps = false
        params.no_timestamps = true
        params.translate = false // transcribir siempre, nunca traducir
        params.no_context = true // cada dictado es independiente
        params.suppress_blank = true
        params.n_threads = Int32(max(4, ProcessInfo.processInfo.activeProcessorCount - 2))

        let status: Int32 = language.withCString { lang in
            params.language = lang
            return samples.withUnsafeBufferPointer { buffer in
                whisper_full(ctx, params, buffer.baseAddress, Int32(buffer.count))
            }
        }
        guard status == 0 else { return "" }

        var text = ""
        for i in 0..<whisper_full_n_segments(ctx) {
            if let segment = whisper_full_get_segment_text(ctx, i) {
                text += String(cString: segment)
            }
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
