import SwiftUI

@main
struct KopyKatApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("KopyKat", systemImage: "doc.on.clipboard") {
            MenuContent(appState: appState)
        }

        Settings {
            SettingsView(appState: appState)
        }
    }
}

// Without a Dock presence (LSUIElement) the app is not active when a menu item
// is clicked, so SettingsLink would create the settings window behind other
// apps. Activating first makes openSettings() bring it to the front.
private struct MenuContent: View {
    let appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Button("Open KopyKat") { appState.panelController?.toggle() }
        Button("Settings…") {
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",")
        Divider()
        Button("Quit KopyKat") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
