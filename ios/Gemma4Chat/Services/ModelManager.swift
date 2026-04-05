import Foundation

@MainActor
class ModelManager: NSObject, ObservableObject {
    @Published var downloadProgress: Double = 0
    @Published var isDownloaded = false
    @Published var isDownloading = false
    @Published var error: String?
    @Published var statusText = ""

    static let modelFilename = "gemma-3-1b-it-Q4_K_M.gguf"
    static let modelURL = URL(string: "https://huggingface.co/bartowski/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf")!

    var modelPath: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Self.modelFilename)
    }

    private var downloadTask: URLSessionDownloadTask?
    private var continuation: CheckedContinuation<Void, Error>?
    private lazy var session: URLSession = {
        URLSession(configuration: .default, delegate: self, delegateQueue: .main)
    }()

    func checkModel() {
        isDownloaded = FileManager.default.fileExists(atPath: modelPath.path)
    }

    func downloadModel() async {
        guard !isDownloading else { return }
        isDownloading = true
        error = nil
        downloadProgress = 0
        statusText = "Starting download..."

        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                self.continuation = cont
                let task = self.session.downloadTask(with: Self.modelURL)
                self.downloadTask = task
                task.resume()
            }
            isDownloaded = true
            statusText = "Ready!"
        } catch {
            self.error = error.localizedDescription
            statusText = "Download failed"
        }

        isDownloading = false
    }

    func cancelDownload() {
        downloadTask?.cancel()
    }

    func deleteModel() {
        try? FileManager.default.removeItem(at: modelPath)
        isDownloaded = false
        statusText = ""
    }
}

extension ModelManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Move file synchronously before the temp file is deleted
        let dest = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(Self.modelFilename)
        do {
            if FileManager.default.fileExists(atPath: dest.path) {
                try FileManager.default.removeItem(at: dest)
            }
            try FileManager.default.moveItem(at: location, to: dest)
            Task { @MainActor in
                self.continuation?.resume()
                self.continuation = nil
            }
        } catch {
            Task { @MainActor in
                self.continuation?.resume(throwing: error)
                self.continuation = nil
            }
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        let progress = Double(totalBytesWritten) / Double(max(totalBytesExpectedToWrite, 1))
        let mb = Double(totalBytesWritten) / 1_000_000
        let totalMB = Double(totalBytesExpectedToWrite) / 1_000_000
        Task { @MainActor in
            self.downloadProgress = progress
            self.statusText = String(format: "Downloading: %.0f / %.0f MB", mb, totalMB)
        }
    }

    nonisolated func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            Task { @MainActor in
                self.continuation?.resume(throwing: error)
                self.continuation = nil
            }
        }
    }
}
