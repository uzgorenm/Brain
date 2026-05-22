import Foundation
import Observation

@Observable
final class ModelDownloadManager: NSObject, URLSessionDownloadDelegate {
    static let shared = ModelDownloadManager()
    
    var isDownloading = false
    var progress: Double = 0.0
    var errorMessage: String?
    var isDownloaded = false
    
    @ObservationIgnored private var downloadTask: URLSessionDownloadTask?
    @ObservationIgnored private var internalUrlSession: URLSession?
    
    private var urlSession: URLSession {
        if let session = internalUrlSession { return session }
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        internalUrlSession = session
        return session
    }
    
    private let modelURL = URL(string: "https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm")!
    
    var localModelURL: URL? {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return documentsURL?.appendingPathComponent("gemma-4-E2B-it.litertlm")
    }
    
    func checkModelExists() -> Bool {
        guard let localModelURL else { return false }
        let exists = FileManager.default.fileExists(atPath: localModelURL.path)
        self.isDownloaded = exists
        return exists
    }
    
    func startDownload() {
        guard !isDownloading else { return }
        errorMessage = nil
        isDownloading = true
        progress = 0.0
        
        // Before downloading, if a partial or old file exists, we could remove it, but downloadTask handles tmp files
        downloadTask = urlSession.downloadTask(with: modelURL)
        downloadTask?.resume()
    }
    
    func cancelDownload() {
        downloadTask?.cancel()
        isDownloading = false
        progress = 0.0
    }
    
    // MARK: - URLSessionDownloadDelegate
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        let currentProgress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        Task { @MainActor in
            self.progress = currentProgress
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // Must move the file synchronously before the delegate method returns,
        // otherwise URLSession automatically deletes the temporary file.
        guard let localModelURL = self.localModelURL else {
            Task { @MainActor in
                self.isDownloading = false
                self.errorMessage = "Could not find local documents directory."
            }
            return
        }
        
        do {
            if FileManager.default.fileExists(atPath: localModelURL.path) {
                try FileManager.default.removeItem(at: localModelURL)
            }
            try FileManager.default.moveItem(at: location, to: localModelURL)
            
            Task { @MainActor in
                self.isDownloading = false
                self.isDownloaded = true
                NotificationCenter.default.post(name: NSNotification.Name("ModelDownloaded"), object: nil)
            }
        } catch {
            Task { @MainActor in
                self.isDownloading = false
                self.errorMessage = "Failed to save model: \(error.localizedDescription)"
            }
        }
    }
    
    nonisolated func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            Task { @MainActor in
                self.isDownloading = false
                // Ignore cancellation errors
                if (error as NSError).code != NSURLErrorCancelled {
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
}
