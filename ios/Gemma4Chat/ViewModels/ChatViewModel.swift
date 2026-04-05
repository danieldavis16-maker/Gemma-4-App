import Foundation
import SwiftUI

struct DocumentInfo: Codable, Identifiable {
    var id: String { filename }
    let filename: String
    let chunk_count: Int
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isStreaming = false
    @Published var webSearchEnabled = false
    @Published var ragEnabled = false
    @Published var isConnected = false
    @Published var currentInput = ""
    @Published var loadedDocuments: [DocumentInfo] = []
    @Published var showDocumentsSheet = false

    private let host: String
    private let port: Int

    private var currentResponse = ""
    private let webSocketService: WebSocketService

    init(host: String = "localhost", port: Int = 8000) {
        self.host = host
        self.port = port
        self.webSocketService = WebSocketService(host: host, port: port)
        self.webSocketService.delegate = self
        self.webSocketService.connect()
    }

    func sendMessage() {
        let text = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming else { return }

        // Add user message
        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        currentInput = ""

        // Prepare message history for the backend
        let history = messages.map { (role: $0.role.rawValue, content: $0.content) }

        // Start streaming
        isStreaming = true
        currentResponse = ""

        // Add placeholder for assistant response
        let assistantMessage = ChatMessage(role: .assistant, content: "")
        messages.append(assistantMessage)

        webSocketService.sendChatRequest(messages: history, webSearch: webSearchEnabled, rag: ragEnabled)
    }

    func reconnect() {
        webSocketService.connect()
    }

    func fetchDocuments() async {
        guard let url = URL(string: "http://\(host):\(port)/api/documents/") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let docs = try JSONDecoder().decode([DocumentInfo].self, from: data)
            loadedDocuments = docs
        } catch {
            // Silently handle — documents list is non-critical
        }
    }

    func uploadDocument(data: Data, filename: String) async {
        guard let url = URL(string: "http://\(host):\(port)/api/documents/upload") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: application/octet-stream\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        request.httpBody = body

        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            await fetchDocuments()
        } catch {
            messages.append(ChatMessage(role: .system, content: "Upload failed: \(error.localizedDescription)"))
        }
    }

    func deleteDocument(filename: String) async {
        guard let url = URL(string: "http://\(host):\(port)/api/documents/\(filename)") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
        do {
            let (_, _) = try await URLSession.shared.data(for: request)
            await fetchDocuments()
        } catch {
            // Silently handle
        }
    }

    private func appendToCurrentResponse(_ token: String) {
        currentResponse += token
        if !messages.isEmpty {
            messages[messages.count - 1] = ChatMessage(
                role: .assistant,
                content: currentResponse
            )
        }
    }
}

extension ChatViewModel: WebSocketServiceDelegate {
    nonisolated func didReceiveToken(_ token: String) {
        Task { @MainActor in
            appendToCurrentResponse(token)
        }
    }

    nonisolated func didReceiveSearchResults(_ results: String) {
        // Search results are used by the backend as context
    }

    nonisolated func didReceiveRAGContext(_ context: String) {
        // RAG context is used by the backend; no client-side action needed
    }

    nonisolated func didFinishResponse() {
        Task { @MainActor in
            isStreaming = false
            currentResponse = ""
        }
    }

    nonisolated func didReceiveError(_ error: String) {
        Task { @MainActor in
            isStreaming = false
            if !messages.isEmpty && messages.last?.role == .assistant && messages.last?.content.isEmpty == true {
                messages.removeLast()
            }
            messages.append(ChatMessage(role: .system, content: "Error: \(error)"))
        }
    }

    nonisolated func didConnect() {
        Task { @MainActor in
            isConnected = true
        }
    }

    nonisolated func didDisconnect() {
        Task { @MainActor in
            isConnected = false
        }
    }
}
