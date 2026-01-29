import AppKit
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
        guard HookManager.showInstallConfirmation() else { return }

        do {
            try HookManager.installHook()
            isHookConfigured = true
            HookManager.showInstallSuccess()
        } catch {
            HookManager.showError(error)
        }
    }

    private func removeHook() {
        guard HookManager.showRemoveConfirmation() else { return }

        do {
            try HookManager.removeHook()
            isHookConfigured = false
        } catch {
            HookManager.showError(error)
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
