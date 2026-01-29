import Foundation

struct CorrectionError: Codable, Identifiable {
    let id: UUID
    let original: String
    let corrected: String
    let explanation: String

    init(id: UUID = UUID(), original: String, corrected: String, explanation: String) {
        self.id = id
        self.original = original
        self.corrected = corrected
        self.explanation = explanation
    }
}

struct Correction: Codable, Identifiable {
    let id: UUID
    let timestamp: Date
    let sessionId: String
    let original: String
    let corrected: String
    let errors: [CorrectionError]
    let isPerfect: Bool
    var chatMessages: [ChatMessage]

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sessionId: String,
        original: String,
        corrected: String,
        errors: [CorrectionError],
        isPerfect: Bool,
        chatMessages: [ChatMessage] = []
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.original = original
        self.corrected = corrected
        self.errors = errors
        self.isPerfect = isPerfect
        self.chatMessages = chatMessages
    }

    /// Create from a pending prompt after correction
    init(from pending: PendingPrompt, corrected: String, errors: [CorrectionError]) {
        self.id = pending.id
        self.timestamp = pending.timestamp
        self.sessionId = pending.sessionId
        self.original = pending.prompt
        self.corrected = corrected
        self.errors = errors
        self.isPerfect = errors.isEmpty
        self.chatMessages = []
    }

    // MARK: - Codable (backward compatibility)

    enum CodingKeys: String, CodingKey {
        case id, timestamp, sessionId, original, corrected, errors, isPerfect, chatMessages
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        sessionId = try container.decode(String.self, forKey: .sessionId)
        original = try container.decode(String.self, forKey: .original)
        corrected = try container.decode(String.self, forKey: .corrected)
        errors = try container.decode([CorrectionError].self, forKey: .errors)
        isPerfect = try container.decode(Bool.self, forKey: .isPerfect)
        chatMessages = try container.decodeIfPresent([ChatMessage].self, forKey: .chatMessages) ?? []
    }
}

struct CorrectionStore: Codable {
    var corrections: [Correction]

    init(corrections: [Correction] = []) {
        self.corrections = corrections
    }
}
