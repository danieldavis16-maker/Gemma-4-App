import Foundation
import SwiftUI

struct DocumentInfo: Identifiable {
    var id: String { filename }
    let filename: String
    let chunkCount: Int
}

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isStreaming = false
    @Published var webSearchEnabled = false
    @Published var ragEnabled = false
    @Published var currentInput = ""
    @Published var loadedDocuments: [DocumentInfo] = []
    @Published var showDocumentsSheet = false
    @Published var isModelLoaded = false
    @Published var modelLoadError: String?

    private var currentResponse = ""
    private let llmService = LocalLLMService()
    private let ragService = OnDeviceRAGService()
    private let searchService = WebSearchService()
    private var generationTask: Task<Void, Never>?

    func loadModel(path: String) async {
        do {
            try llmService.load(path: path)
            isModelLoaded = true
        } catch {
            modelLoadError = error.localizedDescription
        }
    }

    func sendMessage() {
        let text = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isStreaming, isModelLoaded else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        currentInput = ""

        isStreaming = true
        currentResponse = ""
        messages.append(ChatMessage(role: .assistant, content: ""))

        generationTask = Task {
            var systemPrompt: String?

            // Web search context
            if webSearchEnabled {
                let searchContext = await searchService.search(query: text)
                if !searchContext.isEmpty {
                    systemPrompt = searchContext
                }
            }

            // RAG context
            if ragEnabled {
                let chunks = ragService.search(query: text)
                let ragContext = ragService.formatContext(chunks: chunks)
                if !ragContext.isEmpty {
                    systemPrompt = (systemPrompt ?? "") + "\n\n" + ragContext
                }
            }

            // Build chat prompt (exclude the empty assistant placeholder)
            let history = messages.dropLast().map { (role: $0.role.rawValue, content: $0.content) }
            let prompt = LocalLLMService.formatChat(messages: history, systemPrompt: systemPrompt)

            for await token in llmService.generate(prompt: prompt) {
                appendToCurrentResponse(token)
            }

            isStreaming = false
            currentResponse = ""
        }
    }

    func stopGeneration() {
        generationTask?.cancel()
        isStreaming = false
        currentResponse = ""
    }

    func refreshDocuments() {
        loadedDocuments = ragService.listDocuments().map {
            DocumentInfo(filename: $0.filename, chunkCount: $0.chunkCount)
        }
    }

    func uploadDocument(data: Data, filename: String) {
        do {
            _ = try ragService.ingestDocument(data: data, filename: filename)
            refreshDocuments()
        } catch {
            messages.append(ChatMessage(role: .system, content: "Upload failed: \(error.localizedDescription)"))
        }
    }

    func deleteDocument(filename: String) {
        ragService.deleteDocument(filename: filename)
        refreshDocuments()
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
