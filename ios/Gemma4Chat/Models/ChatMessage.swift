import Foundation

struct ChatMessage: Identifiable, Equatable, Codable {
    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date
    var isBookmarked: Bool
    var toolCall: ToolCall?

    var isUser: Bool { role == .user }

    enum Role: String, Codable {
        case user
        case assistant
        case system
        case tool
    }

    init(id: UUID = UUID(), role: Role, content: String, timestamp: Date = Date(), isBookmarked: Bool = false, toolCall: ToolCall? = nil) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isBookmarked = isBookmarked
        self.toolCall = toolCall
    }
}

struct ToolCall: Codable, Equatable {
    let name: String
    let arguments: String
    var result: String?
}

struct Conversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var tags: [String]

    init(id: UUID = UUID(), title: String = "New Chat", messages: [ChatMessage] = [], createdAt: Date = Date(), isPinned: Bool = false, tags: [String] = []) {
        self.id = id
        self.title = title
        self.messages = messages
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.isPinned = isPinned
        self.tags = tags
    }
}

struct Project: Identifiable, Codable {
    let id: UUID
    var name: String
    var systemPrompt: String
    var conversationIds: [UUID]
    let createdAt: Date
    var updatedAt: Date

    init(id: UUID = UUID(), name: String, systemPrompt: String = "", conversationIds: [UUID] = [], createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.systemPrompt = systemPrompt
        self.conversationIds = conversationIds
        self.createdAt = createdAt
        self.updatedAt = createdAt
    }
}

struct LLMSettings: Codable {
    var temperature: Float = 0.7
    var topK: Int32 = 40
    var topP: Float = 0.9
    var maxTokens: Int = 2048
    var systemPrompt: String = ""

    static let `default` = LLMSettings()
}

// MARK: - Templates

struct PromptTemplate: Identifiable, Codable {
    let id: UUID
    let name: String
    let icon: String
    let systemPrompt: String
    let starterMessage: String
    let isBuiltIn: Bool

    init(id: UUID = UUID(), name: String, icon: String, systemPrompt: String, starterMessage: String = "", isBuiltIn: Bool = false) {
        self.id = id
        self.name = name
        self.icon = icon
        self.systemPrompt = systemPrompt
        self.starterMessage = starterMessage
        self.isBuiltIn = isBuiltIn
    }
}

let builtInTemplates: [PromptTemplate] = [
    PromptTemplate(name: "Coding Assistant", icon: "chevron.left.forwardslash.chevron.right", systemPrompt: "You are an expert programmer. Write clean, efficient code with explanations. Use code blocks with language tags.", starterMessage: "Help me write some code", isBuiltIn: true),
    PromptTemplate(name: "Creative Writer", icon: "pencil.line", systemPrompt: "You are a creative writing assistant. Help with stories, poetry, scripts, and other creative text. Be imaginative and expressive.", starterMessage: "Help me write something creative", isBuiltIn: true),
    PromptTemplate(name: "Tutor", icon: "graduationcap", systemPrompt: "You are a patient tutor. Explain concepts clearly using analogies and examples. Ask follow-up questions to check understanding. Adapt explanations to the student's level.", starterMessage: "Teach me something", isBuiltIn: true),
    PromptTemplate(name: "Translator", icon: "globe", systemPrompt: "You are a professional translator. When given text, detect the language and translate it to English. If already in English, ask which language to translate to. Preserve tone and nuance.", starterMessage: "Translate this for me", isBuiltIn: true),
    PromptTemplate(name: "Summarizer", icon: "doc.text.magnifyingglass", systemPrompt: "You summarize text concisely. Extract key points and present them as bullet points. Be accurate and complete while being brief.", starterMessage: "Summarize this text", isBuiltIn: true),
    PromptTemplate(name: "Brainstorm Partner", icon: "lightbulb", systemPrompt: "You are a brainstorming partner. Generate creative ideas, ask provocative questions, build on suggestions, and help explore possibilities. Be enthusiastic and open-minded.", starterMessage: "Let's brainstorm", isBuiltIn: true),
    PromptTemplate(name: "Email Writer", icon: "envelope", systemPrompt: "You write professional emails. Ask for context (recipient, purpose, tone) then draft clear, well-structured emails. Offer formal and casual variants.", starterMessage: "Help me write an email", isBuiltIn: true),
    PromptTemplate(name: "Debate Partner", icon: "bubble.left.and.bubble.right", systemPrompt: "You are a thoughtful debate partner. Present counterarguments to any position. Be respectful but challenging. Cite reasoning and consider multiple perspectives.", starterMessage: "Let's debate a topic", isBuiltIn: true),
]

// MARK: - Tool Definitions

struct ToolDefinition {
    let name: String
    let description: String
    let execute: (String) -> String
}

let availableTools: [ToolDefinition] = [
    ToolDefinition(name: "calculate", description: "Evaluate a math expression") { expr in
        let cleaned = expr.replacingOccurrences(of: "[^0-9+\\-*/().% ]", with: "", options: .regularExpression)
        let mathExpr = NSExpression(format: cleaned)
        if let result = mathExpr.expressionValue(with: nil, context: nil) as? NSNumber {
            return String(describing: result)
        }
        return "Error: Could not evaluate expression"
    },
    ToolDefinition(name: "date", description: "Get the current date and time") { _ in
        let fmt = DateFormatter()
        fmt.dateStyle = .full
        fmt.timeStyle = .medium
        return fmt.string(from: Date())
    },
    ToolDefinition(name: "timer", description: "Set a timer (returns confirmation)") { duration in
        return "Timer set for \(duration). (Note: Background timers require notification permission.)"
    },
    ToolDefinition(name: "weather", description: "Get weather info (requires internet)") { location in
        return "Weather lookup for '\(location)' is not yet connected to a weather API. This is a placeholder."
    },
]
