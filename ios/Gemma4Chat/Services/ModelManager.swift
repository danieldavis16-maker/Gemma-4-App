import Foundation

struct ModelOption: Identifiable {
    let id: String
    let name: String
    let filename: String
    let url: URL
    let sizeLabel: String
    let description: String
    let supportsImages: Bool
}

let availableModels: [ModelOption] = [
    ModelOption(
        id: "gemma-1b",
        name: "Gemma 3 1B",
        filename: "google_gemma-3-1b-it-Q4_K_M.gguf",
        url: URL(string: "https://huggingface.co/bartowski/google_gemma-3-1b-it-GGUF/resolve/main/google_gemma-3-1b-it-Q4_K_M.gguf")!,
        sizeLabel: "~800 MB",
        description: "Fast, lightweight text model. Works on all iPhones.",
        supportsImages: false
    ),
    ModelOption(
        id: "gemma-4b",
        name: "Gemma 3 4B",
        filename: "google_gemma-3-4b-it-Q4_K_M.gguf",
        url: URL(string: "https://huggingface.co/bartowski/google_gemma-3-4b-it-GGUF/resolve/main/google_gemma-3-4b-it-Q4_K_M.gguf")!,
        sizeLabel: "~2.5 GB",
        description: "Multimodal — understands images. Needs 6GB+ RAM (iPhone 13 Pro+).",
        supportsImages: true
    ),
]

@MainActor
class ModelManager: NSObject, ObservableObject {
    @Published var downloadProgress: Double = 0
    @Published var isDownloaded = false
    @Published var isDownloading = false
    @Published var error: String?
    @Published var statusText = ""
    @Published var selectedModelId: String = ""
    @Published var downloadedModels: Set<String> = []

    private var downloadTask: URLSessionDownloadTask?
    private var continuation: CheckedContinuation<Void, Error>?
    private var downloadingFilename: String = ""
    private lazy var session: URLSession = {
        let config = URLSessionConfiguration.background(withIdentifier: "com.gemma4chat.modeldownload")
        config.isDiscretionary = false
        config.sessionSendsLaunchEvents = true
        return URLSession(configuration: config, delegate: self, delegateQueue: .main)
    }()

    var selectedModel: ModelOption? {
        availableModels.first { $0.id == selectedModelId }
    }

    var modelPath: URL {
        let filename = selectedModel?.filename ?? availableModels[0].filename
        return FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }

    func checkModel() {
        // Check for previous crash during model load
        if UserDefaults.standard.bool(forKey: "modelLoadInProgress") {
            UserDefaults.standard.set(false, forKey: "modelLoadInProgress")
            UserDefaults.standard.set("", forKey: "selectedModelId")
            selectedModelId = ""
            isDownloaded = false
            return
        }

        // Load saved selection
        let saved = UserDefaults.standard.string(forKey: "selectedModelId") ?? ""
        selectedModelId = saved

        // Check which models are downloaded
        downloadedModels = []
        for model in availableModels {
            let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(model.filename)
            if let attrs = try? FileManager.default.attributesOfItem(atPath: path.path),
               let size = attrs[.size] as? Int64, size > 100_000_000 {
                downloadedModels.insert(model.id)
            }
        }

        // If selected model is downloaded, we're ready
        if !selectedModelId.isEmpty && downloadedModels.contains(selectedModelId) {
            isDownloaded = true
        } else {
            isDownloaded = false
        }
    }

    func selectModel(_ modelId: String) {
        selectedModelId = modelId
        UserDefaults.standard.set(modelId, forKey: "selectedModelId")
        if downloadedModels.contains(modelId) {
            isDownloaded = true
        }
    }

    func downloadModel(_ model: ModelOption) async {
        guard !isDownloading else { return }
        isDownloading = true
        error = nil
        downloadProgress = 0
        statusText = "Starting download..."
        downloadingFilename = model.filename

        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                self.continuation = cont
                let task = self.session.downloadTask(with: model.url)
                self.downloadTask = task
                task.resume()
            }
            downloadedModels.insert(model.id)
            selectModel(model.id)
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

    func deleteModel(_ model: ModelOption) {
        let path = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(model.filename)
        try? FileManager.default.removeItem(at: path)
        downloadedModels.remove(model.id)
        if selectedModelId == model.id {
            isDownloaded = false
            selectedModelId = ""
            UserDefaults.standard.set("", forKey: "selectedModelId")
        }
    }
}

extension ModelManager: URLSessionDownloadDelegate {
    nonisolated func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        // Read filename from the response URL or fallback to last path component
        let filename = downloadTask.originalRequest?.url?.lastPathComponent ?? "model.gguf"
        let dest = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
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
