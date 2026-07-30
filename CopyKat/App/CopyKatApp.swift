import KeyboardShortcuts
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
        openPanelButton
        Button("Settings…") { appState.settingsWindowController.show(appState: appState) }
            .keyboardShortcut(",")
        #if !MAS
        Button("Check for Updates…") { appState.updaterController.checkForUpdates(nil) }
        #endif
        Divider()
        Button("Quit CopyKat") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }

    // Show the panel's own hotkey next to the menu item, whatever the user
    // configured it to be.
    @ViewBuilder
    private var openPanelButton: some View {
        let button = Button("Open CopyKat") { appState.panelController?.toggle() }
        if let shortcut = KeyboardShortcuts.getShortcut(for: .togglePanel),
           let key = shortcut.nsMenuItemKeyEquivalent?.first {
            button.keyboardShortcut(KeyEquivalent(key), modifiers: EventModifiers(shortcut.modifiers))
        } else {
            button
        }
    }
}

private extension EventModifiers {
    init(_ flags: NSEvent.ModifierFlags) {
        self.init()
        if flags.contains(.command) { insert(.command) }
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.option) { insert(.option) }
        if flags.contains(.control) { insert(.control) }
    }
}
