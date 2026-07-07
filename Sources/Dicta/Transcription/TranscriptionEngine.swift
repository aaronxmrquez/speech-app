import AVFoundation

/// Abstracción del motor de voz→texto. v1 usa el motor nativo de Apple;
/// motores futuros (Whisper local, API) solo implementan este protocolo.
protocol TranscriptionEngine: AnyObject {
    /// Inicia una sesión de reconocimiento. `onPartial` puede llegar en cualquier hilo.
    func begin(localeId: String, onPartial: @escaping (String) -> Void) throws
    /// Alimenta audio a la sesión activa. Seguro desde el hilo de audio.
    func append(_ buffer: AVAudioPCMBuffer)
    /// Cierra la sesión y devuelve el texto final.
    func finish() async -> String
    /// Descarta la sesión activa.
    func cancel()
}
