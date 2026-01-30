import Foundation

struct IgnoredRule: Codable, Identifiable, Hashable {
    let id: UUID
    let rule: String
    let originalExplanation: String
    let example: String
    let addedAt: Date

    init(id: UUID = UUID(), rule: String, originalExplanation: String, example: String, addedAt: Date = Date()) {
        self.id = id
        self.rule = rule
        self.originalExplanation = originalExplanation
        self.example = example
        self.addedAt = addedAt
    }
}

struct IgnoredRulesStore: Codable {
    var rules: [IgnoredRule]

    init(rules: [IgnoredRule] = []) {
        self.rules = rules
    }
}
