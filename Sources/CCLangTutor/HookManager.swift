import AppKit
import Foundation

enum HookManagerError: LocalizedError, Equatable {
    case settingsCorrupted
    case settingsUnreadable
    case unexpectedStructure
    case appBundleNotFound

    var errorDescription: String? {
        switch self {
        case .settingsCorrupted:
            return "Claude Code settings.json is corrupted or not valid JSON."
        case .settingsUnreadable:
            return "Could not read Claude Code settings.json. Check file permissions."
        case .unexpectedStructure:
            return "Claude Code settings.json has unexpected structure."
        case .appBundleNotFound:
            return "Could not find CCLangTutor app bundle."
        }
    }
}

enum HookManager {
    /// Claude Code settings directory (can be overridden for testing)
    nonisolated(unsafe) static var claudeDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude")
    static var settingsPath: URL { claudeDir.appendingPathComponent("settings.json") }

    /// Unique identifiers for CCLangTutor hook command (used for detection and removal)
    /// Uses multiple patterns to avoid false positives while catching various install locations
    private static let hookIdentifiers = [
        "/CCLangTutor.app/Contents/MacOS/notifier",  // Standard app bundle path
        "/CCLangTutor.app/Contents/MacOS/english-teacher",  // Legacy path (for migration)
        "CCLangTutor.app/",  // Fallback: any CCLangTutor.app bundle
    ]

    /// Get the path to the notifier CLI in the app bundle
    private static func getNotifierPath() -> String? {
        guard let bundlePath = Bundle.main.bundlePath as String? else { return nil }
        let cliPath = "\(bundlePath)/Contents/MacOS/notifier"
        return FileManager.default.fileExists(atPath: cliPath) ? cliPath : nil
    }

    /// Check if Claude Code is installed (.claude directory exists)
    static func isClaudeCodeInstalled() -> Bool {
        FileManager.default.fileExists(atPath: claudeDir.path)
    }

    /// Check if CCLangTutor hook is configured
    /// Returns false if settings can't be read (file doesn't exist or errors)
    static func isHookConfigured() -> Bool {
        guard let settings = try? readSettings() else { return false }
        return findCCLangTutorHookIndex(in: settings) != nil
    }

    /// Install the CCLangTutor hook into settings.json
    /// Uses merge strategy to preserve existing settings
    /// Thread-safe via file coordination
    static func installHook() throws {
        try withFileCoordination(writing: true) {
            // Skip if already installed
            if isHookConfigured() { return }

            guard let cliPath = getNotifierPath() else {
                throw HookManagerError.appBundleNotFound
            }

            var settings = try readSettingsOrEmpty()

            // Validate and get hooks object
            if let existing = settings["hooks"], !(existing is [String: Any]) {
                throw HookManagerError.unexpectedStructure
            }
            var hooks = settings["hooks"] as? [String: Any] ?? [:]

            // Get UserPromptSubmit array - support mixed arrays by working with [Any]
            // Only reject if UserPromptSubmit exists but is not an array at all
            if let existing = hooks["UserPromptSubmit"], !(existing is [Any]) {
                throw HookManagerError.unexpectedStructure
            }
            var userPromptSubmit = hooks["UserPromptSubmit"] as? [Any] ?? []

            // Create the CCLangTutor hook entry (new format with nested hooks array)
            let cclangtutorHook: [String: Any] = [
                "hooks": [
                    [
                        "command": cliPath,
                        "type": "command",
                    ]
                ]
            ]

            // Add to UserPromptSubmit array
            userPromptSubmit.append(cclangtutorHook)
            hooks["UserPromptSubmit"] = userPromptSubmit
            settings["hooks"] = hooks

            // Write settings back
            try writeSettings(settings)
        }
    }

    /// Remove the CCLangTutor hook from settings.json
    /// Removes ALL matching entries to handle duplicate installations
    /// Thread-safe via file coordination
    /// Handles mixed arrays (containing both dictionaries and other types)
    static func removeHook() throws {
        try withFileCoordination(writing: true) {
            guard var settings = try readSettings() else { return }

            guard var hooks = settings["hooks"] as? [String: Any],
                  var userPromptSubmit = hooks["UserPromptSubmit"] as? [Any]
            else {
                return
            }

            // Find and remove ALL CCLangTutor hook entries (in reverse order to preserve indices)
            let indicesToRemove = findAllCCLangTutorHookIndices(userPromptSubmit: userPromptSubmit)
            guard !indicesToRemove.isEmpty else { return }

            for index in indicesToRemove.reversed() {
                userPromptSubmit.remove(at: index)
            }
            hooks["UserPromptSubmit"] = userPromptSubmit
            settings["hooks"] = hooks
            try writeSettings(settings)
        }
    }

    // MARK: - Private

    /// Check if a command string matches any of our hook identifiers
    private static func isOurHookCommand(_ command: String) -> Bool {
        let lowercasedCommand = command.lowercased()
        return hookIdentifiers.contains { identifier in
            lowercasedCommand.contains(identifier.lowercased())
        }
    }

    /// Find first CCLangTutor hook index checking the command contains our identifier
    /// Handles mixed arrays where some elements may not be dictionaries
    private static func findCCLangTutorHookIndex(in settings: [String: Any]) -> Int? {
        guard let hooks = settings["hooks"] as? [String: Any],
              let userPromptSubmit = hooks["UserPromptSubmit"] as? [Any]
        else {
            return nil
        }
        return findAllCCLangTutorHookIndices(userPromptSubmit: userPromptSubmit).first
    }

    /// Find ALL CCLangTutor hook indices in potentially mixed UserPromptSubmit array
    /// Skips non-dictionary entries and searches only valid hook entries
    /// Handles both flat format (command at top level) and nested format (command inside hooks array)
    private static func findAllCCLangTutorHookIndices(userPromptSubmit: [Any]) -> [Int] {
        var indices: [Int] = []
        for (index, item) in userPromptSubmit.enumerated() {
            // Skip non-dictionary entries
            guard let hookEntry = item as? [String: Any] else { continue }

            // Check flat format: command directly on the entry
            if let command = hookEntry["command"] as? String, isOurHookCommand(command) {
                indices.append(index)
                continue
            }

            // Check nested format: command inside hooks array
            if let nestedHooks = hookEntry["hooks"] as? [[String: Any]] {
                for nestedHook in nestedHooks {
                    if let command = nestedHook["command"] as? String, isOurHookCommand(command) {
                        indices.append(index)
                        break
                    }
                }
            }
        }
        return indices
    }

    /// Read settings, returning nil only if file doesn't exist
    /// Throws error if file exists but can't be read or parsed
    private static func readSettings() throws -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: settingsPath.path) else {
            return nil
        }

        let data: Data
        do {
            data = try Data(contentsOf: settingsPath)
        } catch {
            throw HookManagerError.settingsUnreadable
        }

        guard let json = try? JSONSerialization.jsonObject(with: data),
              let settings = json as? [String: Any]
        else {
            throw HookManagerError.settingsCorrupted
        }

        return settings
    }

    /// Read settings, returning empty dict if file doesn't exist
    /// Throws error if file exists but can't be read or parsed
    private static func readSettingsOrEmpty() throws -> [String: Any] {
        try readSettings() ?? [:]
    }

    private static func writeSettings(_ settings: [String: Any]) throws {
        // Create .claude directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: claudeDir.path) {
            try FileManager.default.createDirectory(at: claudeDir, withIntermediateDirectories: true)
        }

        let data = try JSONSerialization.data(
            withJSONObject: settings,
            options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        )

        try data.write(to: settingsPath, options: .atomic)
    }

    /// Execute a block with file coordination for thread safety
    /// This prevents concurrent read-modify-write issues
    private static func withFileCoordination(writing: Bool, block: () throws -> Void) throws {
        let coordinator = NSFileCoordinator(filePresenter: nil)
        var coordinatorError: NSError?
        var blockError: Error?

        let intent: NSFileCoordinator.WritingOptions = writing ? .forMerging : []

        coordinator.coordinate(
            writingItemAt: settingsPath,
            options: intent,
            error: &coordinatorError
        ) { _ in
            do {
                try block()
            } catch {
                blockError = error
            }
        }

        if let error = coordinatorError {
            throw error
        }
        if let error = blockError {
            throw error
        }
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
