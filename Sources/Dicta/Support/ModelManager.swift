import Foundation
import Combine

/// Descarga y localiza el modelo Whisper (ggml large-v3-turbo cuantizado).
@MainActor
final class ModelManager: NSObject, ObservableObject {
    static let shared = ModelManager()

    static let modelFileName = "ggml-large-v3-turbo-q5_0.bin"
    static let modelSizeMB = 574
    static let downloadSource = URL(string:
        "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3-turbo-q5_0.bin")!

    nonisolated static var modelURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Dicta/models/\(modelFileName)")
    }

    @Published var modelReady = FileManager.default.fileExists(atPath: ModelManager.modelURL.path)
    @Published var isDownloading = false
    @Published var progress: Double = 0
    @Published var errorMessage: String?

    private var task: URLSessionDownloadTask?
    private lazy var session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)

    func refresh() {
        modelReady = FileManager.default.fileExists(atPath: ModelManager.modelURL.path)
    }

    func download() {
        guard !isDownloading, !modelReady else { return }
        isDownloading = true
        progress = 0
        errorMessage = nil
        let task = session.downloadTask(with: ModelManager.downloadSource)
        self.task = task
        task.resume()
    }

    func cancelDownload() {
        task?.cancel()
        task = nil
        isDownloading = false
    }
}

extension ModelManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                                didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                                totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let value = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in self.progress = value }
    }

    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                                didFinishDownloadingTo location: URL) {
        // Mover aquí mismo: el archivo temporal deja de existir al retornar.
        let destination = ModelManager.modelURL
        var moved = false
        do {
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            moved = true
        } catch {}
        let success = moved
        Task { @MainActor in
            self.isDownloading = false
            self.modelReady = success
            self.errorMessage = success ? nil : "No se pudo guardar el modelo"
        }
    }

    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask,
                                didCompleteWithError error: Error?) {
        guard let error, (error as NSError).code != NSURLErrorCancelled else { return }
        let message = error.localizedDescription
        Task { @MainActor in
            self.isDownloading = false
            self.errorMessage = message
        }
    }
}
