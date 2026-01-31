import CCHookInstaller
import Foundation

/// Hook manager configuration for CCLangTutor
enum HookManager {
    /// Shared hook manager instance
    static let shared = CCHookInstaller.HookManager(
        configuration: .userPromptSubmit(
            appName: "CCLangTutor",
            hookIdentifiers: [
                "CCLangTutor.app/Contents/MacOS/notifier",
            ]
        )
    )

    /// Messages for hook setup dialogs
    static let messages = HookSetupMessages(
        installPromptMessage:
            "CCLangTutor can automatically check your English grammar when you submit prompts to Claude Code. Would you like to install the hook?",
        updatePromptMessage:
            "The CCLangTutor hook path has changed. Would you like to update it to use the current app location?",
        successMessage:
            "Claude Code hooks have been configured. CCLangTutor will check your English grammar when you submit prompts.",
        updateSuccessMessage:
            "Claude Code hook has been updated to use the current app location."
    )

    /// UserDefaults key for "Don't Ask Again" preference
    static let dontAskAgainKey = "dontAskHookSetup"

    // MARK: - Pass-through methods for Settings UI

    static func isClaudeCodeInstalled() -> Bool {
        shared.isClaudeCodeInstalled()
    }

    static func isHookConfigured() -> Bool {
        shared.isHookConfigured()
    }

    static func installHook() throws {
        try shared.installHook()
    }

    static func removeHook() throws {
        try shared.removeHook()
    }
}
