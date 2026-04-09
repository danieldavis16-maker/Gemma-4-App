import Foundation
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
    @Published var showProjectsSheet = false
    @Published var showTemplatesSheet = false
    @Published var showSearchSheet = false
    @Published var showBookmarksSheet = false

    // Conversation history
    @Published var conversations: [Conversation] = []
    @Published var currentConversationId: UUID?

    // Function calling
    @Published var toolsEnabled = true

    // Projects
    @Published var projects: [Project] = []
    @Published var currentProject: Project?

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
    private let projectStore = ProjectStore()
    private let haptic = UIImpactFeedbackGenerator(style: .medium)
    private let lightHaptic = UIImpactFeedbackGenerator(style: .light)
    private var generationTask: Task<Void, Never>?
    private var generationStartTime: Date?

    init() {
        conversations = store.loadAll()
        settings = store.loadSettings()
        projects = projectStore.loadAll()
        haptic.prepare()
    }

    func checkSiriQuestion() {
        if let question = UserDefaults.standard.string(forKey: "siriQuestion"), !question.isEmpty {
            UserDefaults.standard.removeObject(forKey: "siriQuestion")
            currentInput = question
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
        UserDefaults.standard.set(true, forKey: "modelLoadInProgress")
        do {
            try llmService.load(path: path)
            isModelLoaded = true
        } catch {
            modelLoadError = error.localizedDescription
        }
        UserDefaults.standard.set(false, forKey: "modelLoadInProgress")
    }

    // MARK: - Messaging

    func sendMessage() {
        let text = currentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let hasImage = pendingImage != nil
        guard (!text.isEmpty || hasImage), !isStreaming, isModelLoaded else { return }

        haptic.impactOccurred()

        let title = text.isEmpty ? "Image chat" : String(text.prefix(40))
        if currentConversationId == nil {
            let conv = Conversation(title: title)
            conversations.insert(conv, at: 0)
            currentConversationId = conv.id
            // Associate with current project
            if var project = currentProject {
                project.conversationIds.append(conv.id)
                project.updatedAt = Date()
                if let idx = projects.firstIndex(where: { $0.id == project.id }) {
                    projects[idx] = project
                    currentProject = project
                    projectStore.saveAll(projects)
                }
            }
        }

        var userContent = text
        if pendingImage != nil {
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
        lightHaptic.impactOccurred()
        saveCurrentConversation()
    }

    private func startGeneration() {
        isStreaming = true
        currentResponse = ""
        tokenCount = 0
        tokensPerSecond = 0
        generationStartTime = Date()
        messages.append(ChatMessage(role: .assistant, content: ""))

        // Check clipboard for image
        if let clipImage = UIPasteboard.general.image, pendingImage == nil {
            pendingImage = clipImage
        }

        generationTask = Task {
            // Use project system prompt if available, otherwise use settings
            var systemPrompt: String?
            if let projectPrompt = currentProject?.systemPrompt, !projectPrompt.isEmpty {
                systemPrompt = projectPrompt
            } else if !settings.systemPrompt.isEmpty {
                systemPrompt = settings.systemPrompt
            }

            // Add tool instructions if enabled
            if toolsEnabled {
                systemPrompt = (systemPrompt ?? "") + "\n\n" + ToolService.toolInstructions
            }

            if webSearchEnabled {
                if let lastUser = messages.last(where: { $0.role == .user }) {
                    let searchContext = await searchService.search(query: lastUser.content)
                    if !searchContext.isEmpty {
                        systemPrompt = (systemPrompt ?? "") + "\n\n" + searchContext
                    }
                }
            }

            lastRAGSources = []
            if ragEnabled {
                if let lastUser = messages.last(where: { $0.role == .user }) {
                    let chunks = ragService.search(query: lastUser.content)
                    let ragContext = ragService.formatContext(chunks: chunks)
                    if !ragContext.isEmpty {
                        systemPrompt = (systemPrompt ?? "") + "\n\n" + ragContext
                        lastRAGSources = chunks.map {
                            RAGSource(filename: $0.filename, excerpt: String($0.content.prefix(120)))
                        }
                    }
                }
            }

            let history = messages.dropLast().map { (role: $0.role.rawValue, content: $0.content) }
            let prompt = LocalLLMService.formatChat(messages: history, systemPrompt: systemPrompt)

            var lastUIUpdate = Date()
            for await token in llmService.generate(prompt: prompt, settings: settings) {
                currentResponse += token
                tokenCount += 1

                let now = Date()
                if now.timeIntervalSince(lastUIUpdate) > 0.05 {
                    if !messages.isEmpty {
                        messages[messages.count - 1] = ChatMessage(
                            id: messages[messages.count - 1].id,
                            role: .assistant,
                            content: currentResponse
                        )
                    }
                    if let start = generationStartTime {
                        let elapsed = now.timeIntervalSince(start)
                        if elapsed > 0.5 {
                            tokensPerSecond = Double(tokenCount) / elapsed
                        }
                    }
                    lastUIUpdate = now
                }
            }

            // Process tool calls in the response
            if toolsEnabled, let toolResult = ToolService.processToolCalls(in: currentResponse) {
                currentResponse = toolResult.cleanText
            }

            if !messages.isEmpty {
                messages[messages.count - 1] = ChatMessage(
                    id: messages[messages.count - 1].id,
                    role: .assistant,
                    content: currentResponse
                )
            }

            isStreaming = false
            currentResponse = ""
            tokensPerSecond = 0
            lightHaptic.impactOccurred()

            // Auto-title: use first response to generate a better title
            autoTitleConversation()
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
        // Remove from project
        for i in projects.indices {
            projects[i].conversationIds.removeAll { $0 == conversation.id }
        }
        projectStore.saveAll(projects)
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

    // MARK: - Projects

    func createProject(name: String) {
        let project = Project(name: name)
        projects.insert(project, at: 0)
        projectStore.saveAll(projects)
        switchToProject(project)
    }

    func switchToProject(_ project: Project) {
        saveCurrentConversation()
        currentProject = project
        currentConversationId = nil
        messages = []
    }

    func deleteProject(_ project: Project) {
        projects.removeAll { $0.id == project.id }
        if currentProject?.id == project.id {
            currentProject = nil
        }
        projectStore.saveAll(projects)
    }

    func updateProjectPrompt(_ prompt: String) {
        guard var project = currentProject,
              let idx = projects.firstIndex(where: { $0.id == project.id }) else { return }
        project.systemPrompt = prompt
        project.updatedAt = Date()
        projects[idx] = project
        currentProject = project
        projectStore.saveAll(projects)
    }

    // MARK: - Export

    func exportCurrentConversation(format: ExportFormat) {
        guard let id = currentConversationId,
              let conversation = conversations.first(where: { $0.id == id }) else { return }

        switch format {
        case .text:
            let text = ChatExporter.exportAsText(conversation: conversation)
            ChatExporter.share(items: [text])
        case .pdf:
            let pdfData = ChatExporter.exportAsPDF(conversation: conversation)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(conversation.title).pdf")
            try? pdfData.write(to: tempURL)
            ChatExporter.share(items: [tempURL])
        }
    }

    func exportConversation(_ conversation: Conversation, format: ExportFormat) {
        switch format {
        case .text:
            let text = ChatExporter.exportAsText(conversation: conversation)
            ChatExporter.share(items: [text])
        case .pdf:
            let pdfData = ChatExporter.exportAsPDF(conversation: conversation)
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("\(conversation.title).pdf")
            try? pdfData.write(to: tempURL)
            ChatExporter.share(items: [tempURL])
        }
    }

    enum ExportFormat {
        case text, pdf
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

    // MARK: - Templates

    func applyTemplate(_ template: PromptTemplate) {
        newConversation()
        settings.systemPrompt = template.systemPrompt
        store.saveSettings(settings)
        if !template.starterMessage.isEmpty {
            currentInput = template.starterMessage
        }
    }

    // MARK: - Auto-title

    private func autoTitleConversation() {
        guard let id = currentConversationId,
              let idx = conversations.firstIndex(where: { $0.id == id }),
              conversations[idx].messages.count <= 3 else { return }
        // Use first user message + first assistant response to make a smarter title
        let userMsg = conversations[idx].messages.first(where: { $0.role == .user })?.content ?? ""
        let assistantMsg = conversations[idx].messages.first(where: { $0.role == .assistant })?.content ?? ""
        // Extract a meaningful title from the exchange
        let combined = userMsg.prefix(100)
        let words = combined.split(separator: " ")
        if words.count > 3 {
            conversations[idx].title = words.prefix(6).joined(separator: " ")
        }
    }

    // MARK: - Bookmarks

    func toggleBookmark(messageId: UUID) {
        if let idx = messages.firstIndex(where: { $0.id == messageId }) {
            messages[idx].isBookmarked.toggle()
            saveCurrentConversation()
        }
    }

    // MARK: - Tags & Pins

    func togglePin() {
        guard let id = currentConversationId,
              let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[idx].isPinned.toggle()
        store.saveAll(conversations)
    }

    func addTag(_ tag: String) {
        guard let id = currentConversationId,
              let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        if !conversations[idx].tags.contains(tag) {
            conversations[idx].tags.append(tag)
            store.saveAll(conversations)
        }
    }

    func removeTag(_ tag: String) {
        guard let id = currentConversationId,
              let idx = conversations.firstIndex(where: { $0.id == id }) else { return }
        conversations[idx].tags.removeAll { $0 == tag }
        store.saveAll(conversations)
    }

    // MARK: - Share as Screenshot

    func shareMessageAsScreenshot(_ message: ChatMessage) {
        let image = ScreenshotService.renderMessage(message)
        ScreenshotService.share(image: image)
    }

    func shareConversationAsScreenshot() {
        guard let id = currentConversationId,
              let conv = conversations.first(where: { $0.id == id }) else { return }
        let image = ScreenshotService.renderConversation(conv.messages, title: conv.title)
        ScreenshotService.share(image: image)
    }

    // MARK: - Web Archive

    func archiveWebPage(url: String) {
        Task {
            do {
                let chunks = try await WebArchiveService.fetchAndIngest(url: url, ragService: ragService)
                refreshDocuments()
                messages.append(ChatMessage(role: .system, content: "Archived \(url) (\(chunks) chunks)"))
            } catch {
                messages.append(ChatMessage(role: .system, content: "Archive failed: \(error.localizedDescription)"))
            }
        }
    }

    // MARK: - Sorted Conversations

    var sortedConversations: [Conversation] {
        conversations.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.updatedAt > b.updatedAt
        }
    }
}
