import Foundation

@MainActor
class CloudSyncService: ObservableObject {
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?

    private let store = NSUbiquitousKeyValueStore.default

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleExternalChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: store
        )
        store.synchronize()
    }

    func uploadConversations(_ conversations: [Conversation]) {
        guard let data = try? JSONEncoder().encode(conversations) else { return }
        // NSUbiquitousKeyValueStore has a 1MB limit per key
        // For larger data, chunk it or use iCloud Documents
        if data.count < 900_000 {
            store.set(data, forKey: "conversations")
            store.synchronize()
            lastSyncDate = Date()
        } else {
            // Fall back to iCloud Documents for larger data
            saveToiCloudDocuments(data)
        }
    }

    func downloadConversations() -> [Conversation]? {
        // Try NSUbiquitousKeyValueStore first
        if let data = store.data(forKey: "conversations"),
           let conversations = try? JSONDecoder().decode([Conversation].self, from: data) {
            return conversations
        }
        // Try iCloud Documents
        return loadFromiCloudDocuments()
    }

    func mergeConversations(local: [Conversation], remote: [Conversation]) -> [Conversation] {
        var merged = Dictionary(uniqueKeysWithValues: local.map { ($0.id, $0) })

        for remoteConv in remote {
            if let existing = merged[remoteConv.id] {
                // Latest-write-wins per conversation
                if remoteConv.updatedAt > existing.updatedAt {
                    merged[remoteConv.id] = remoteConv
                }
            } else {
                merged[remoteConv.id] = remoteConv
            }
        }

        return merged.values.sorted { $0.updatedAt > $1.updatedAt }
    }

    @objc nonisolated private func handleExternalChange(_ notification: Notification) {
        Task { @MainActor in
            self.isSyncing = true
            // Notify the app to refresh
            NotificationCenter.default.post(name: .iCloudDataChanged, object: nil)
            self.isSyncing = false
            self.lastSyncDate = Date()
        }
    }

    private func saveToiCloudDocuments(_ data: Data) {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return }
        let documentsURL = containerURL.appendingPathComponent("Documents")
        try? FileManager.default.createDirectory(at: documentsURL, withIntermediateDirectories: true)
        let fileURL = documentsURL.appendingPathComponent("conversations.json")
        try? data.write(to: fileURL)
    }

    private func loadFromiCloudDocuments() -> [Conversation]? {
        guard let containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) else { return nil }
        let fileURL = containerURL.appendingPathComponent("Documents/conversations.json")
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode([Conversation].self, from: data)
    }
}

extension Notification.Name {
    static let iCloudDataChanged = Notification.Name("iCloudDataChanged")
}
