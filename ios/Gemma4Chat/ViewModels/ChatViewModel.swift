import Foundation
import SwiftUI

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isStreaming = false
    @Published var webSearchEnabled = false
    @Published var isConnected = false
    @Published var currentInput = ""

    private var currentResponse = ""
    private let webSocketService: WebSocketService

    init(host: String = "localhost", port: Int = 8000) {
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

        webSocketService.sendChatRequest(messages: history, webSearch: webSearchEnabled)
    }

    func reconnect() {
        webSocketService.connect()
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
        // Search results are used by the backend as context; optionally display them
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
