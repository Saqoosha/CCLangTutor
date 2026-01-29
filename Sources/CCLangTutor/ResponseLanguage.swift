import Foundation

enum ResponseLanguage: String, CaseIterable {
    case english = "en"
    case japanese = "ja"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case chinese = "zh"
    case korean = "ko"

    static let userDefaultsKey = "responseLanguage"

    /// Get current language setting from UserDefaults (must be called from main thread)
    @MainActor
    static var current: ResponseLanguage {
        let code = UserDefaults.standard.string(forKey: userDefaultsKey) ?? english.rawValue
        return ResponseLanguage(rawValue: code) ?? .english
    }

    /// Display name for UI (localized format)
    var displayName: String {
        switch self {
        case .english: return "English"
        case .japanese: return "日本語"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        case .chinese: return "中文"
        case .korean: return "한국어"
        }
    }

    /// Language name for prompts (English)
    var languageName: String {
        switch self {
        case .english: return "English"
        case .japanese: return "Japanese"
        case .spanish: return "Spanish"
        case .french: return "French"
        case .german: return "German"
        case .chinese: return "Chinese"
        case .korean: return "Korean"
        }
    }
}
