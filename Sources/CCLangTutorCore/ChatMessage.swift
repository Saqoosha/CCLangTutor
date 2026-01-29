import Foundation

struct ChatMessage: Codable, Identifiable, Equatable {
    let id: UUID
    let timestamp: Date
    let role: ChatRole
    let content: String

    enum ChatRole: String, Codable {
        case user
        case assistant
    }

    init(id: UUID = UUID(), timestamp: Date = Date(), role: ChatRole, content: String) {
        self.id = id
        self.timestamp = timestamp
        self.role = role
        self.content = content
    }
}
