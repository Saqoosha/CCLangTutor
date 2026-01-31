import AppKit
import CCHookInstaller
import Foundation

/// Singleton hook manager for CCLangTutor using the shared CCHookInstaller library
enum HookManager {
    /// Shared hook manager instance
    static let shared = CCHookInstaller.HookManager(
        configuration: .userPromptSubmit(
            appName: "CCLangTutor",
            hookIdentifiers: [
                "/CCLangTutor.app/Contents/MacOS/notifier",  // Standard app bundle path
                "/CCLangTutor.app/Contents/MacOS/english-teacher",  // Legacy path (for migration)
                "CCLangTutor.app/",  // Fallback: any CCLangTutor.app bundle
            ]
        )
    )

    /// Check if Claude Code is installed (.claude directory exists)
    static func isClaudeCodeInstalled() -> Bool {
        shared.isClaudeCodeInstalled()
    }

    /// Validate settings.json and return any error
    static func validateSettings() -> HookManagerError? {
        shared.validateSettings()
    }

    /// Check if CCLangTutor hook is configured
    static func isHookConfigured() -> Bool {
        shared.isHookConfigured()
    }

    /// Check if hook needs update (cleanup required)
    static func needsHookUpdate() -> Bool {
        shared.needsHookUpdate()
    }

    /// Clean up and reinstall hook
    static func cleanupAndInstallHook() throws {
        try shared.cleanupAndInstallHook()
    }

    /// Install the CCLangTutor hook into settings.json
    static func installHook() throws {
        try shared.installHook()
    }

    /// Remove the CCLangTutor hook from settings.json
    static func removeHook() throws {
        try shared.removeHook()
    }

    // MARK: - UI Helpers

    /// Show confirmation alert for hook installation
    /// Returns true if user confirmed
    @MainActor
    static func showInstallConfirmation() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Setup Claude Code Hooks?"
        alert.informativeText =
            "CCLangTutor will automatically check your English grammar when you submit prompts to Claude Code."
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Show confirmation alert for hook removal
    /// Returns true if user confirmed
    @MainActor
    static func showRemoveConfirmation() -> Bool {
        let alert = NSAlert()
        alert.messageText = "Remove Claude Code Hooks?"
        alert.informativeText = "CCLangTutor will no longer check your English grammar automatically."
        alert.addButton(withTitle: "Remove")
        alert.addButton(withTitle: "Cancel")
        return alert.runModal() == .alertFirstButtonReturn
    }

    /// Show success alert after hook installation
    @MainActor
    static func showInstallSuccess() {
        let alert = NSAlert()
        alert.messageText = "Hooks Installed"
        alert.informativeText =
            "Claude Code hooks have been configured. CCLangTutor will check your English grammar when you submit prompts."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    /// Show error alert for hook operations
    @MainActor
    static func showError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "Failed to Configure Hooks"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .critical
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
