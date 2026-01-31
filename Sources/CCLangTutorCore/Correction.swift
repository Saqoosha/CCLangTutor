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
    let score: Int
    let advice: String?
    var chatMessages: [ChatMessage]
    let skipped: Bool

    init(
        id: UUID = UUID(),
        timestamp: Date = Date(),
        sessionId: String,
        original: String,
        corrected: String,
        errors: [CorrectionError],
        isPerfect: Bool,
        score: Int = 100,
        advice: String? = nil,
        chatMessages: [ChatMessage] = [],
        skipped: Bool = false
    ) {
        self.id = id
        self.timestamp = timestamp
        self.sessionId = sessionId
        self.original = original
        self.corrected = corrected
        self.errors = errors
        self.isPerfect = isPerfect
        self.score = score
        self.advice = advice
        self.chatMessages = chatMessages
        self.skipped = skipped
    }

    /// Create from a pending prompt after correction
    /// - Parameter originalText: Override for the original text (e.g., filtered version). Defaults to pending.prompt.
    init(from pending: PendingPrompt, originalText: String? = nil, corrected: String, errors: [CorrectionError], score: Int, advice: String?, skipped: Bool = false) {
        self.id = pending.id
        self.timestamp = pending.timestamp
        self.sessionId = pending.sessionId
        self.original = originalText ?? pending.prompt
        self.corrected = corrected
        self.errors = errors
        self.isPerfect = errors.isEmpty
        self.score = score
        self.advice = advice
        self.chatMessages = []
        self.skipped = skipped
    }

    // MARK: - Codable (backward compatibility)

    enum CodingKeys: String, CodingKey {
        case id, timestamp, sessionId, original, corrected, errors, isPerfect, score, advice, chatMessages, skipped
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
        score = try container.decodeIfPresent(Int.self, forKey: .score) ?? (isPerfect ? 100 : 70)
        advice = try container.decodeIfPresent(String.self, forKey: .advice)
        chatMessages = try container.decodeIfPresent([ChatMessage].self, forKey: .chatMessages) ?? []
        skipped = try container.decodeIfPresent(Bool.self, forKey: .skipped) ?? false
    }
}

struct CorrectionStore: Codable {
    var corrections: [Correction]

    init(corrections: [Correction] = []) {
        self.corrections = corrections
    }
}
