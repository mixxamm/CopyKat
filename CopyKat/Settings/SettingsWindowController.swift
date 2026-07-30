import AppKit
import SwiftUI

// A window we own, rather than SwiftUI's Settings scene. The floating panel
// lives outside the scene graph and cannot reach `openSettings`, and the usual
// workaround calls an undocumented AppKit selector that App Review rejects.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?

    func show(appState: AppState, tab: SettingsTab? = nil) {
        if let tab {
            AppSettings.selectedSettingsTab = tab.rawValue
        }

        if let window {
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(rootView: SettingsView(appState: appState))
        let window = NSWindow(contentViewController: hosting)
        window.title = String(localized: "CopyKat Settings")
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window

        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
