import Foundation

/// Available AI providers for English correction
enum AIProvider: String, CaseIterable {
    case claudeAPI = "claudeAPI"
    case gemini = "gemini"
    case openAI = "openAI"

    var displayName: String {
        switch self {
        case .claudeAPI:
            return "Claude API"
        case .gemini:
            return "Gemini"
        case .openAI:
            return "OpenAI"
        }
    }

    var keychainService: String {
        switch self {
        case .claudeAPI:
            return KeychainHelper.claudeAPIService
        case .gemini:
            return KeychainHelper.geminiAPIService
        case .openAI:
            return KeychainHelper.openAIAPIService
        }
    }

    var defaultModel: String {
        switch self {
        case .claudeAPI:
            return "claude-3-5-haiku-20241022"
        case .gemini:
            return "gemini-2.0-flash"
        case .openAI:
            return "gpt-4o-mini"
        }
    }

    var apiKeyPlaceholder: String {
        switch self {
        case .claudeAPI:
            return "sk-ant-..."
        case .gemini:
            return "AIza..."
        case .openAI:
            return "sk-..."
        }
    }

    var apiKeyHelpURL: String {
        switch self {
        case .claudeAPI:
            return "console.anthropic.com"
        case .gemini:
            return "aistudio.google.com"
        case .openAI:
            return "platform.openai.com"
        }
    }
}
