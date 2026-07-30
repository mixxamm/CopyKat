import SwiftUI

@main
struct CopyKatApp: App {
    @State private var appState = AppState()
    @AppStorage(AppSettings.menuBarIconKey) private var menuBarIcon = AppSettings.defaultMenuBarIcon

    var body: some Scene {
        MenuBarExtra("CopyKat", systemImage: menuBarIcon) {
            MenuContent(appState: appState)
        }
    }
}

private struct MenuContent: View {
    let appState: AppState

    var body: some View {
        Button("Open CopyKat") { appState.panelController?.toggle() }
        Button("Settings…") { appState.settingsWindowController.show(appState: appState) }
            .keyboardShortcut(",")
        #if !MAS
        Button("Check for Updates…") { appState.updaterController.checkForUpdates(nil) }
        #endif
        Divider()
        Button("Quit CopyKat") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
