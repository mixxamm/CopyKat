import AppKit

enum SettingsOpener {
    // Views outside the app's scenes (like the floating panel) have no
    // openSettings environment action, so fall back to the responder chain.
    @MainActor
    static func open() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }
}
