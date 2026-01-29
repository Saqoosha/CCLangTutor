import Foundation

struct PendingPrompt: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let sessionId: String
    let prompt: String

    init(id: UUID = UUID(), timestamp: Date = Date(), sessionId: String, prompt: String) {
        self.id = id
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.prompt = prompt
    }
}

struct PendingPromptStore: Codable {
    var pending: [PendingPrompt]

    init(pending: [PendingPrompt] = []) {
        self.pending = pending
    }
}
