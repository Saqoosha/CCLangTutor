import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let dontAskHookSetupKey = "dontAskHookSetup"

    func applicationDidFinishLaunching(_ notification: Notification) {
        checkHookSetup()
    }

    private func checkHookSetup() {
        guard HookManager.isClaudeCodeInstalled() else { return }

        // Check if hook needs update (exists but wrong path)
        if HookManager.needsHookUpdate() {
            promptHookUpdate()
            return
        }

        // Already correctly configured
        guard !HookManager.isHookConfigured() else { return }

        // Check for initial setup
        guard !UserDefaults.standard.bool(forKey: Self.dontAskHookSetupKey) else { return }

        // Initial setup uses 3-button alert (Install/Later/Don't Ask Again)
        let alert = NSAlert()
        alert.messageText = "Setup Claude Code Hooks?"
        alert.informativeText =
            "CCLangTutor can automatically check your English grammar when you submit prompts to Claude Code. Would you like to install the hook?"
        alert.addButton(withTitle: "Install")
        alert.addButton(withTitle: "Later")
        alert.addButton(withTitle: "Don't Ask Again")

        switch alert.runModal() {
        case .alertFirstButtonReturn:  // Install
            do {
                try HookManager.installHook()
                NotificationCenter.default.post(name: .hookConfigurationChanged, object: nil)
                HookManager.showInstallSuccess()
            } catch {
                HookManager.showError(error)
            }
        case .alertThirdButtonReturn:  // Don't Ask Again
            UserDefaults.standard.set(true, forKey: Self.dontAskHookSetupKey)
        default:
            break
        }
    }

    private func promptHookUpdate() {
        let alert = NSAlert()
        alert.messageText = "Update Claude Code Hook?"
        alert.informativeText =
            "The CCLangTutor hook path has changed. Would you like to update it to use the current app location?"
        alert.addButton(withTitle: "Update")
        alert.addButton(withTitle: "Later")

        if alert.runModal() == .alertFirstButtonReturn {
            do {
                try HookManager.cleanupAndInstallHook()
                NotificationCenter.default.post(name: .hookConfigurationChanged, object: nil)
                let successAlert = NSAlert()
                successAlert.messageText = "Hook Updated"
                successAlert.informativeText = "Claude Code hook has been updated to use the current app location."
                successAlert.alertStyle = .informational
                successAlert.addButton(withTitle: "OK")
                successAlert.runModal()
            } catch {
                HookManager.showError(error)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
