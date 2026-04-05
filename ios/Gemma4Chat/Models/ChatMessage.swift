import Foundation

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: Role
    var content: String
    let timestamp: Date

    var isUser: Bool { role == .user }

    enum Role: String, Codable {
        case user
        case assistant
        case system
    }

    init(role: Role, content: String, timestamp: Date = Date()) {
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}
