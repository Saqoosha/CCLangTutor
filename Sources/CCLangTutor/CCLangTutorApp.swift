import SwiftUI

@main
struct CCLangTutorApp: App {
    @StateObject private var viewModel = CorrectionViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .background(WindowAccessor())
        }
        .defaultSize(width: 800, height: 600)

        Settings {
            SettingsView()
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
