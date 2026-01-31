import AppKit
import CCHookInstaller

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        HookSetupUI.checkOnLaunch(
            hookManager: HookManager.shared,
            messages: HookManager.messages,
            dontAskAgainKey: HookManager.dontAskAgainKey,
            onConfigurationChanged: {
                NotificationCenter.default.post(name: .hookConfigurationChanged, object: nil)
            }
        )
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
