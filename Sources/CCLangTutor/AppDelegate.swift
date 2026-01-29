import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private static let dontAskHookSetupKey = "dontAskHookSetup"

    func applicationDidFinishLaunching(_ notification: Notification) {
        checkHookSetup()
    }

    private func checkHookSetup() {
        guard !UserDefaults.standard.bool(forKey: Self.dontAskHookSetupKey) else { return }
        guard HookManager.isClaudeCodeInstalled() else { return }
        guard !HookManager.isHookConfigured() else { return }

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

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
