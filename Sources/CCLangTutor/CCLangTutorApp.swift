import AppKit
import CCHookInstaller
import SwiftUI

@main
struct CCLangTutorApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate
    @StateObject private var viewModel = CorrectionViewModel()
    @State private var isHookConfigured = HookManager.isHookConfigured()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .background(WindowAccessor())
        }
        .defaultSize(width: 800, height: 600)
        .commands {
            CommandGroup(after: .appInfo) {
                Button {
                    if isHookConfigured {
                        removeHook()
                    } else {
                        installHook()
                    }
                } label: {
                    if isHookConfigured {
                        Text("\u{2713} Claude Code Hooks Installed")
                    } else {
                        Text("Setup Claude Code Hooks...")
                    }
                }
                .disabled(!HookManager.isClaudeCodeInstalled())
                .onReceive(NotificationCenter.default.publisher(for: .hookConfigurationChanged)) { _ in
                    isHookConfigured = HookManager.isHookConfigured()
                }
            }
        }

        Settings {
            SettingsView()
        }
    }

    private func installHook() {
        let confirmed = HookSetupUI.showInstallPrompt(
            title: HookManager.messages.installPromptTitle,
            message: HookManager.messages.installPromptMessage
        )
        guard confirmed == .install else { return }

        do {
            try HookManager.installHook()
            isHookConfigured = true
            HookSetupUI.showSuccess(
                title: HookManager.messages.successTitle,
                message: HookManager.messages.successMessage
            )
        } catch {
            HookSetupUI.showError(error)
        }
    }

    private func removeHook() {
        let confirmed = HookSetupUI.showRemovePrompt(
            title: "Remove Claude Code Hooks?",
            message: "CCLangTutor will no longer check your English grammar automatically."
        )
        guard confirmed else { return }

        do {
            try HookManager.removeHook()
            isHookConfigured = false
        } catch {
            HookSetupUI.showError(error)
        }
    }
}

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.setFrameAutosaveName("MainWindow")
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}
