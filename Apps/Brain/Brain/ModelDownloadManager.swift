import Foundation
import Observation
import BrainCore

@Observable
@MainActor
final class ModelDownloadManager {
    static let shared = ModelDownloadManager()

    var isDownloading = false
    var progress: Double = 0.0
    var errorMessage: String?
    var isDownloaded = false

    @ObservationIgnored private var downloadTask: Task<Void, Never>?

    private var readyMarkerURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Brain", isDirectory: true)
            .appendingPathComponent(".lfm2.5-2.6b-mlx-4bit.ready")
    }

    func checkModelExists() -> Bool {
        guard let readyMarkerURL else {
            isDownloaded = false
            return false
        }
        let exists = FileManager.default.fileExists(atPath: readyMarkerURL.path)
        self.isDownloaded = exists
        return exists
    }

    func startDownload() {
        guard !isDownloading else { return }
        errorMessage = nil
        isDownloading = true
        progress = 0.0

        downloadTask = Task { [weak self] in
            do {
                try await LLMManager.shared.initialize { [weak self] fraction in
                    Task { @MainActor in
                        self?.progress = fraction
                    }
                }

                guard !Task.isCancelled else { return }
                try self?.markModelReady()
                self?.isDownloading = false
                self?.isDownloaded = true
                self?.downloadTask = nil
                NotificationCenter.default.post(name: NSNotification.Name("ModelDownloaded"), object: nil)
            } catch {
                guard !Task.isCancelled else { return }
                self?.isDownloading = false
                self?.downloadTask = nil
                self?.errorMessage = "Failed to download the MLX model: \(error.localizedDescription)"
            }
        }
    }

    func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        isDownloading = false
        progress = 0.0
    }

    private func markModelReady() throws {
        guard let readyMarkerURL else {
            throw LLMError.modelCacheUnavailable
        }
        try FileManager.default.createDirectory(
            at: readyMarkerURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("MLX model ready".utf8).write(to: readyMarkerURL, options: .atomic)
    }
}
