import SwiftUI

@main
struct CopyCatApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("CopyCat", systemImage: "doc.on.clipboard") {
            Button("Open CopyCat") { appState.panelController?.toggle() }
            SettingsLink {
                Text("Settings…")
            }
            .keyboardShortcut(",")
            Divider()
            Button("Quit CopyCat") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }

        Settings {
            SettingsView(appState: appState)
        }
    }
}
