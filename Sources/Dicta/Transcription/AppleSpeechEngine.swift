import Speech
import AVFoundation

final class AppleSpeechEngine: TranscriptionEngine {
    private var recognizer: SFSpeechRecognizer?
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?

    private let lock = NSLock()
    private var latest = ""
    private var continuation: CheckedContinuation<String, Never>?
    private var finishedEarly = false

    func begin(localeId: String, onPartial: @escaping (String) -> Void) throws {
        cancel()

        // Este motor no autodetecta idioma: "auto" cae a español.
        let effectiveLocale = localeId == "auto" ? "es-MX" : localeId
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: effectiveLocale)),
              recognizer.isAvailable else {
            throw NSError(domain: "Dicta", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Reconocimiento de voz no disponible"])
        }
        self.recognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.addsPunctuation = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        self.request = request

        lock.lock()
        latest = ""
        finishedEarly = false
        lock.unlock()

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            if let result {
                let text = result.bestTranscription.formattedString
                self.lock.lock()
                self.latest = text
                self.lock.unlock()
                onPartial(text)
                if result.isFinal { self.resolve() }
            }
            if error != nil { self.resolve() }
        }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        request?.append(buffer)
    }

    func finish() async -> String {
        request?.endAudio()

        lock.lock()
        if finishedEarly {
            finishedEarly = false
            let text = latest
            lock.unlock()
            cleanup()
            return text
        }
        lock.unlock()

        return await withCheckedContinuation { cont in
            lock.lock()
            continuation = cont
            lock.unlock()
            // Red de seguridad: si el resultado final nunca llega, devolver el último parcial.
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.5) { [weak self] in
                self?.resolve()
            }
        }
    }

    func cancel() {
        task?.cancel()
        resolve()
        cleanup()
        lock.lock()
        finishedEarly = false
        lock.unlock()
    }

    private func resolve() {
        lock.lock()
        if let cont = continuation {
            continuation = nil
            let text = latest
            lock.unlock()
            cont.resume(returning: text)
            cleanup()
        } else {
            finishedEarly = true
            lock.unlock()
        }
    }

    private func cleanup() {
        task = nil
        request = nil
    }
}
