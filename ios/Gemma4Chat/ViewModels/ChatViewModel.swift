import Foundation
import os
import SwiftUI
import UIKit

struct DocumentInfo: Identifiable {
    var id: String { filename }
    let filename: String
    let chunkCount: Int
}

struct RAGSource: Identifiable {
    let id = UUID()
    let filename: String
    let excerpt: String
}

@MainActor
class ChatViewModel: ObservableObject {
    // Chat state
    @Published var messages: [ChatMessage] = []
    @Published var isStreaming = false
    @Published var currentInput = ""
    @Published var isModelLoaded = false
    @Published var modelLoadError: String?

    // Features
    @Published var webSearchEnabled = false
    @Published var ragEnabled = false

    // Sheets
    @Published var showDocumentsSheet = false
    @Published var showSettingsSheet = false
    @Published var showHistorySheet = false

    // Conversation history
    @Published var conversations: [Conversation] = []
    @Published var currentConversationId: UUID?

    // Settings
    @Published var settings: LLMSettings = .default

    // Token speed
    @Published var tokensPerSecond: Double = 0
    @Published var tokenCount: Int = 0

    // RAG sources for last response
    @Published var lastRAGSources: [RAGSource] = []

    // Image input
    @Published var pendingImage: UIImage?

    // Voice chat
    let voiceService = VoiceChatService()

    // RAG documents
    @Published var loadedDocuments: [DocumentInfo] = []

    private var currentResponse = ""
    private let llmService = LocalLLMService()
    private let ragService = OnDeviceRAGService()
    private let searchService = WebSearchService()
    private let store = ConversationStore()
    private var generationTask: Task<Void, Never>?
    private var generationStartTime: Date?

    init() {
        conversations = store.loadAll()
        settings = store.loadSettings()
    }

    func checkSiriQuestion() {
        if let question = UserDefaults.standard.string(forKey: "siriQuestion"), !question.isEmpty {
            UserDefaults.standard.removeObject(forKey: "siriQuestion")
            currentInput = question
            // Auto-send after model loads
            Task {
                while !isModelLoaded { try? await Task.sleep(nanoseconds: 200_000_000) }
                sendMessage()
            }
        }
    }

    func speakLastResponse() {
        guard let lastAssistant = messages.last(where: { $0.role == .assistant }),
              !lastAssistant.content.isEmpty else { return }
        voiceService.speak(text: lastAssistant.content)
    }

    func loadModel(path: String) async {
        // Check available memory before loading
        let fileSize = (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? Int64 ?? 0
        let availableMemory = os_proc_available_memory()
        let neededMemory = Int(Double(fileSize) * 1.5) // Model needs ~1.5x file size in RAM

        if neededMemory > availableMemory {
            let fileMB = fileSize / 1_000_000
            let availMB = availableMemory / 1_000_000
            modelLoadError = "Not enough memory. Model needs ~\(fileMB * 3 / 2) MB but only \(availMB) MB available. Try the smaller 1B model."
            return
        }

        do {
            try llmService.load(path: path)
            isModelLoaded = true
        } catch {
            modelLoadError = error.localizedDescription
        }
    }

    // MARK: - Messaging

    func sendMessage() {
        let text = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasImage = pendingImage != nil
        guard (!text.isEmpty || hasImage), !isStreaming, isModelLoaded else { return }

        // Create conversation if needed
        let title = text.isEmpty ? "Image chat" : String(text.prefix(40))
        if currentConversationId == nil {
            let conv = Conversation(title: title)
            conversations.insert(conv, at: 0)
            currentConversationId = conv.id
        }

        // Build user message content
        var userContent = text
        if pendingImage != nil {
            // Note: True multimodal vision requires llava clip encoder integration.
            // For now, note the image attachment in the message.
            let imageNote = "[User attached an image]"
            userContent = userContent.isEmpty ? imageNote : "\(userContent)\n\(imageNote)"
            pendingImage = nil
        }

        messages.append(ChatMessage(role: .user, content: userContent))
        currentInput = ""

        startGeneration()
    }

    func regenerateLastResponse() {
        guard !isStreaming, isModelLoaded else { return }
        // Remove last assistant message
        if let last = messages.last, last.role == .assistant {
            messages.removeLast()
        }
        startGeneration()
    }

    func stopGeneration() {
        generationTask?.cancel()
        isStreaming = false
        currentResponse = ""
        tokensPerSecond = 0
        saveCurrentConversation()
    }

    private func startGeneration() {
        isStreaming = true
        currentResponse = ""
        tokenCount = 0
        tokensPerSecond = 0
        generationStartTime = Date()
        messages.append(ChatMessage(role: .assistant, content: ""))

        generationTask = Task {
            var systemPrompt: String? = settings.systemPrompt.isEmpty ? nil : settings.systemPrompt

            // Web search context
            if webSearchEnabled {
                if let lastUser = messages.last(where: { $0.role == .user }) {
                    let searchContext = await searchService.search(query: lastUser.content)
                    if !searchContext.isEmpty {
                        systemPrompt = (systemPrompt ?? "") + "\n\n" + searchContext
                    }
                }
            }

            // RAG context
            lastRAGSources = []
            if ragEnabled {
                if let lastUser = messages.last(where: { $0.role == .user }) {
                    let chunks = ragService.search(query: lastUser.content)
                    let ragContext = ragService.formatContext(chunks: chunks)
                    if !ragContext.isEmpty {
                        systemPrompt = (systemPrompt ?? "") + "\n\n" + ragContext
                        lastRAGSources = chunks.map {
                            RAGSource(
                                filename: $0.filename,
                                excerpt: String($0.content.prefix(120))
                            )
                        }
                    }
                }
            }

            let history = messages.dropLast().map { (role: $0.role.rawValue, content: $0.content) }
            let prompt = LocalLLMService.formatChat(messages: history, systemPrompt: systemPrompt)

            for await token in llmService.generate(prompt: prompt, settings: settings) {
                appendToCurrentResponse(token)
                tokenCount += 1
                if let start = generationStartTime {
                    let elapsed = Date().timeIntervalSince(start)
                    if elapsed > 0.5 {
                        tokensPerSecond = Double(tokenCount) / elapsed
                    }
                }
            }

            isStreaming = false
            currentResponse = ""
            tokensPerSecond = 0
            saveCurrentConversation()
        }
    }

    // MARK: - Conversation History

    func newConversation() {
        saveCurrentConversation()
        currentConversationId = nil
        messages = []
    }

    func loadConversation(_ conversation: Conversation) {
        saveCurrentConversation()
        currentConversationId = conversation.id
        messages = conversation.messages
    }

    func deleteConversation(_ conversation: Conversation) {
        conversations.removeAll { $0.id == conversation.id }
        if currentConversationId == conversation.id {
            currentConversationId = nil
            messages = []
        }
        store.saveAll(conversations)
    }

    func saveCurrentConversation() {
        guard let id = currentConversationId,
              let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[idx].messages = messages
        conversations[idx].updatedAt = Date()
        if let firstUser = messages.first(where: { $0.role == .user }) {
            conversations[idx].title = String(firstUser.content.prefix(40))
        }
        store.saveAll(conversations)
    }

    // MARK: - Settings

    func saveSettings() {
        store.saveSettings(settings)
    }

    // MARK: - Documents

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

    // MARK: - Private

    private func appendToCurrentResponse(_ token: String) {
        currentResponse += token
        if !messages.isEmpty {
            messages[messages.count - 1] = ChatMessage(
                id: messages[messages.count - 1].id,
                role: .assistant,
                content: currentResponse
            )
        }
    }
}
